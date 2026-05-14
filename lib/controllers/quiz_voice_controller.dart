import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/voice_assistant_settings_service.dart';

enum QuizVoiceScreen {
  none,
  quizSettings,
  examSession,
  examLoading,
  mcq,
  examReview,
}

enum QuizVoicePhase {
  disabled,
  idle,
  speaking,
  listening,
  processing,
  navigating,
  submitting,
}

enum VoiceState {
  disabled,
  idle,
  speaking,
  listening,
  processing,
  paused,
  error,
}

typedef QuizVoiceAsyncCallback = Future<void> Function();

class QuizVoiceController extends GetxController with WidgetsBindingObserver {
  static const Duration _idleRecoveryThreshold = Duration(seconds: 1);
  static const Duration _processingRecoveryThreshold = Duration(seconds: 5);
  static const Duration _speakingRecoveryThreshold = Duration(seconds: 28);
  static const Duration _listeningRecoveryThreshold = Duration(seconds: 15);
  static const Duration _activationRecoveryDelay = Duration(milliseconds: 450);
  static const Duration _speechStatusRecoveryDelay = Duration(
    milliseconds: 650,
  );
  static const Duration _speakingRetryDelay = Duration(milliseconds: 700);
  static const Duration _healthCheckInterval = Duration(seconds: 4);
  static const Duration _healthRecoveryCooldown = Duration(seconds: 2);

  final RxBool isEnabled = false.obs;
  final RxBool isDebugPanelExpanded = false.obs;
  final Rx<QuizVoiceScreen> activeScreen = QuizVoiceScreen.none.obs;
  final Rx<QuizVoicePhase> phase = QuizVoicePhase.disabled.obs;
  final Rx<VoiceState> voiceState = VoiceState.disabled.obs;
  final RxString heardText = ''.obs;
  final RxString recognizedCommand = ''.obs;
  final RxDouble commandConfidence = 0.0.obs;
  final RxString retryMessage = ''.obs;
  final Rx<VoiceAssistantSettings> assistantSettings =
      VoiceAssistantSettings.defaults().obs;
  final RxList<String> recentLogs = <String>[].obs;

  final VoiceAssistantSettingsService _settingsService =
      VoiceAssistantSettingsService();

  Timer? _watchdogTimer;
  Timer? _activationRecoveryTimer;
  QuizVoiceAsyncCallback? _recoveryCallback;
  QuizVoiceAsyncCallback? _entryCallback;
  QuizVoiceAsyncCallback? _activeDeactivateCallback;
  QuizVoiceScreen? _boundScreen;
  QuizVoiceScreen? _activeScreen;
  String? _activeScreenToken;
  bool _entryActionPending = false;
  bool _recoveryInFlight = false;
  bool _recoveryRunning = false;
  String? _activeScreenName;
  DateTime _lastPhaseChangeAt = DateTime.now();
  DateTime _lastRecoveryAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHealthRecoveryAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Set<String> _spokenKeys = <String>{};

  bool get isEnabledValue => isEnabled.value;
  VoiceState get currentStateValue => voiceState.value;
  bool get autoListenOnScreenOpenValue =>
      assistantSettings.value.autoListenOnScreenOpen;
  bool get _shouldDeferReactiveMutation =>
      SchedulerBinding.instance.schedulerPhase ==
      SchedulerPhase.persistentCallbacks;

  void _runReactiveMutation(VoidCallback action) {
    if (_shouldDeferReactiveMutation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isClosed) return;
        action();
      });
      return;
    }
    action();
  }

  bool get hasActiveScreen => _activeScreenToken != null;

  bool isCurrentScreenToken(String token) => _activeScreenToken == token;

  bool shouldOpenReviewForVoiceNext({
    required int currentIndex,
    required int questionCount,
  }) {
    return questionCount <= 0 || currentIndex >= questionCount - 1;
  }

  bool isCurrentScreen(QuizVoiceScreen screen, String token) {
    final isCurrent = _activeScreen == screen && _activeScreenToken == token;
    if (!isCurrent) {
      logEvent('[Voice][${screen.name}][IGNORED old token]', screen: screen);
    }
    return isCurrent;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    logEvent('controller initialized');
    unawaited(loadAssistantSettings());
    _watchdogTimer = Timer.periodic(
      _healthCheckInterval,
      (_) => _onWatchdogTick(),
    );
  }

  @override
  void onClose() {
    logEvent('controller closing');
    WidgetsBinding.instance.removeObserver(this);
    _watchdogTimer?.cancel();
    _activationRecoveryTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    logEvent('app lifecycle: $state');
    if (state == AppLifecycleState.resumed) {
      _scheduleActivationRecovery(reason: 'app resumed');
    }
  }

  void bindScreen({
    required QuizVoiceScreen screen,
    String? screenToken,
    QuizVoiceAsyncCallback? onRecoverListening,
    QuizVoiceAsyncCallback? onEntryAction,
    bool requestEntryAction = false,
  }) {
    if (screenToken != null && !isCurrentScreen(screen, screenToken)) return;
    _boundScreen = screen;
    _recoveryCallback = onRecoverListening;
    _entryCallback = onEntryAction;
    _runReactiveMutation(() {
      activeScreen.value = screen;
      logEvent(
        'bind screen, requestEntryAction=$requestEntryAction',
        screen: screen,
      );
      if (requestEntryAction) {
        _entryActionPending = true;
      }
      if (isEnabled.value) {
        if (phase.value == QuizVoicePhase.disabled) {
          phase.value = QuizVoicePhase.idle;
        }
        requestRecovery(
          force: true,
          preferEntryAction: requestEntryAction,
          screenToken: screenToken,
        );
      }
    });
  }

  void unbindScreen(QuizVoiceScreen screen, {String? screenToken}) {
    if (screenToken != null && !isCurrentScreen(screen, screenToken)) return;
    if (_boundScreen != screen) return;
    if (screenToken != null) {
      deactivateScreen(screenToken);
    } else {
      onScreenDeactivated(screen.name);
    }
    _boundScreen = null;
    _recoveryCallback = null;
    _entryCallback = null;
    _runReactiveMutation(() {
      logEvent('unbind screen', screen: screen);
    });
  }

  void activateScreen(
    QuizVoiceScreen screen,
    String token, {
    QuizVoiceAsyncCallback? onDeactivate,
  }) {
    if (_activeScreen == screen && _activeScreenToken == token) return;

    final previousDeactivate = _activeDeactivateCallback;
    final previousScreen = _activeScreen;
    final previousToken = _activeScreenToken;
    if (previousToken != null && previousToken != token) {
      logEvent(
        '[Voice][${previousScreen?.name ?? 'none'}][INACTIVE]',
        screen: previousScreen,
      );
      _activationRecoveryTimer?.cancel();
      _activationRecoveryTimer = null;
      _recoveryCallback = null;
      _entryCallback = null;
      _entryActionPending = false;
      _recoveryRunning = false;
      _recoveryInFlight = false;
      if (previousDeactivate != null) {
        unawaited(previousDeactivate());
      }
    }

    _activeScreen = screen;
    _activeScreenToken = token;
    _activeDeactivateCallback = onDeactivate;
    _activeScreenName = screen.name;
    activeScreen.value = screen;
    logEvent('[Voice][${screen.name}][ACTIVE]', screen: screen);
    _scheduleActivationRecovery(reason: 'screen activated', screenToken: token);
  }

  void deactivateScreen(String token) {
    if (_activeScreenToken != token) {
      logEvent('[Voice][IGNORED old token] deactivate');
      return;
    }

    final screen = _activeScreen;
    logEvent('[Voice][${screen?.name ?? 'none'}][INACTIVE]', screen: screen);
    _activationRecoveryTimer?.cancel();
    _activationRecoveryTimer = null;
    _activeScreen = null;
    _activeScreenToken = null;
    _activeDeactivateCallback = null;
    _activeScreenName = null;
    _boundScreen = null;
    _recoveryCallback = null;
    _entryCallback = null;
    _entryActionPending = false;
    _recoveryRunning = false;
    _recoveryInFlight = false;
  }

  void onScreenActivated(String screenName) {
    _activeScreenName = screenName;
    logEvent('screen activated: $screenName');
    _scheduleActivationRecovery(reason: 'screen activated');
  }

  void onScreenDeactivated(String screenName) {
    if (_activeScreenName != screenName) return;
    logEvent('screen deactivated: $screenName');
    _activeScreenName = null;
    _activationRecoveryTimer?.cancel();
    _activationRecoveryTimer = null;
  }

  void onSpeechStatus(
    String status, {
    required QuizVoiceScreen screen,
    String? screenToken,
  }) {
    if (screenToken != null && !isCurrentScreen(screen, screenToken)) return;
    if (screen.name != _activeScreenName) return;
    if (status != 'done' && status != 'notListening') return;

    logEvent(
      'speech status recovery scheduled after unexpected $status',
      screen: screen,
    );
    _activationRecoveryTimer?.cancel();
    _activationRecoveryTimer = Timer(_speechStatusRecoveryDelay, () {
      _activationRecoveryTimer = null;
      _requestHealthRecovery('speech status $status', screenToken: screenToken);
    });
  }

  void setVoiceEnabled(
    bool enabled, {
    required QuizVoiceScreen screen,
    bool requestEntryAction = false,
  }) {
    final bool wasEnabled = isEnabled.value;
    _runReactiveMutation(() {
      isEnabled.value = enabled;
      activeScreen.value = screen;

      if (!enabled) {
        logEvent('voice disabled', screen: screen, phaseOverride: phase.value);
        phase.value = QuizVoicePhase.disabled;
        _setVoiceStateLocked(VoiceState.disabled, screen: screen);
        heardText.value = '';
        _entryActionPending = false;
        _spokenKeys.clear();
        _lastPhaseChangeAt = DateTime.now();
        return;
      }

      if (phase.value == QuizVoicePhase.disabled) {
        phase.value = QuizVoicePhase.idle;
        _setVoiceStateLocked(VoiceState.idle, screen: screen);
      }
      _lastPhaseChangeAt = DateTime.now();

      if (requestEntryAction) {
        _entryActionPending = true;
      }

      logEvent(
        'voice enabled, requestEntryAction=$requestEntryAction',
        screen: screen,
      );

      if (!wasEnabled || requestEntryAction) {
        requestRecovery(force: true, preferEntryAction: requestEntryAction);
      }
    });
  }

  void setPhase(QuizVoicePhase next, {QuizVoiceScreen? screen}) {
    _runReactiveMutation(() {
      if (screen != null) {
        activeScreen.value = screen;
      }
      if (!isEnabled.value && next != QuizVoicePhase.disabled) {
        return;
      }
      final previous = phase.value;
      phase.value = next;
      _setVoiceStateLocked(_voiceStateForPhase(next), screen: screen);
      _lastPhaseChangeAt = DateTime.now();
      if (previous != next) {
        logEvent(
          'phase $previous -> $next',
          screen: screen ?? activeScreen.value,
          phaseOverride: next,
        );
      }
    });
  }

  bool setVoiceState(VoiceState next, {QuizVoiceScreen? screen}) {
    var didTransition = false;
    _runReactiveMutation(() {
      didTransition = _setVoiceStateLocked(next, screen: screen);
      if (didTransition) {
        phase.value = _phaseForVoiceState(next);
        _lastPhaseChangeAt = DateTime.now();
      }
    });
    return didTransition;
  }

  void beginNavigation({QuizVoiceScreen? targetScreen}) {
    _runReactiveMutation(() {
      if (targetScreen != null) {
        activeScreen.value = targetScreen;
      }
      if (isEnabled.value) {
        logEvent(
          'begin navigation'
          '${targetScreen != null ? ' -> $targetScreen' : ''}',
          screen: targetScreen ?? activeScreen.value,
          phaseOverride: QuizVoicePhase.navigating,
        );
        phase.value = QuizVoicePhase.navigating;
        _setVoiceStateLocked(VoiceState.paused, screen: targetScreen);
        _lastPhaseChangeAt = DateTime.now();
      }
    });
  }

  void markHeardText(String text) {
    _runReactiveMutation(() {
      heardText.value = text;
    });
  }

  void markCommandResult({
    String? command,
    double confidence = 0,
    String? retry,
  }) {
    _runReactiveMutation(() {
      recognizedCommand.value = command ?? '';
      commandConfidence.value = confidence.clamp(0, 1).toDouble();
      retryMessage.value = retry ?? '';
    });
  }

  bool speakOnce({
    required String key,
    required String text,
    bool force = false,
    QuizVoiceScreen? screen,
  }) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return true;

    if (!force && _spokenKeys.contains(normalizedKey)) {
      final compact = text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final preview = compact.length > 80
          ? '${compact.substring(0, 80)}...'
          : compact;
      logEvent(
        'speak once skipped: $normalizedKey'
        '${preview.isNotEmpty ? ' "$preview"' : ''}',
        screen: screen,
      );
      return false;
    }

    _spokenKeys.add(normalizedKey);
    logEvent(
      'speak once accepted: $normalizedKey${force ? ' (force)' : ''}',
      screen: screen,
    );
    return true;
  }

  void clearSpokenOnceKeys({String? prefix}) {
    if (prefix == null || prefix.isEmpty) {
      _spokenKeys.clear();
      return;
    }
    _spokenKeys.removeWhere((key) => key.startsWith(prefix));
  }

  void clearHeardText() {
    _runReactiveMutation(() {
      heardText.value = '';
      recognizedCommand.value = '';
      commandConfidence.value = 0;
      retryMessage.value = '';
    });
  }

  void toggleDebugPanel() {
    _runReactiveMutation(() {
      isDebugPanelExpanded.value = !isDebugPanelExpanded.value;
      logEvent(
        'debug panel ${isDebugPanelExpanded.value ? 'expanded' : 'collapsed'}',
      );
    });
  }

  Future<void> loadAssistantSettings() async {
    final settings = await _settingsService.loadSettings();
    _runReactiveMutation(() {
      assistantSettings.value = settings;
      logEvent('voice assistant settings loaded');
    });
  }

  Future<void> updateAssistantSettings(VoiceAssistantSettings settings) async {
    await _settingsService.saveSettings(settings);
    _runReactiveMutation(() {
      assistantSettings.value = settings;
      logEvent('voice assistant settings updated');
    });
  }

  // TTS/STT configuration is part of the voice lifecycle. Screens provide the
  // Flutter plugin instances, while the controller owns settings and locale
  // resolution so behavior stays consistent across quiz voice screens.
  Future<void> applyTtsSettings(FlutterTts tts) async {
    final settings = assistantSettings.value;
    await tts.setLanguage(settings.languageCode);
    await tts.setSpeechRate(settings.voiceSpeed);
    await tts.setPitch(settings.voicePitch);
  }

  Future<String?> resolvePreferredSpeechLocaleId(SpeechToText speech) async {
    try {
      final systemLocale = await speech.systemLocale();
      final locales = await speech.locales();
      final localeIds = locales.map((locale) => locale.localeId).toSet();
      final configuredLocaleId = assistantSettings.value.languageCode;
      final configuredSpeechLocaleId = configuredLocaleId.replaceAll('-', '_');

      if (localeIds.contains(configuredLocaleId)) return configuredLocaleId;
      if (localeIds.contains(configuredSpeechLocaleId)) {
        return configuredSpeechLocaleId;
      }

      final systemLocaleId = systemLocale?.localeId;
      if (systemLocaleId != null &&
          systemLocaleId.toLowerCase().startsWith('en')) {
        return systemLocaleId;
      }

      for (final fallback in ['en_IN', 'en_GB', 'en_US']) {
        if (localeIds.contains(fallback)) return fallback;
      }

      return systemLocaleId;
    } catch (_) {
      return null;
    }
  }

  void requestRecovery({
    bool force = false,
    bool preferEntryAction = false,
    String? screenToken,
  }) {
    if (_shouldDeferReactiveMutation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isClosed) return;
        requestRecovery(
          force: force,
          preferEntryAction: preferEntryAction,
          screenToken: screenToken,
        );
      });
      return;
    }
    if (screenToken != null && !isCurrentScreenToken(screenToken)) {
      logEvent('[Voice][RECOVERY skipped] old token');
      return;
    }
    if (!isEnabled.value || _recoveryRunning || _recoveryInFlight) {
      logEvent('[Voice][RECOVERY skipped] busy or disabled');
      return;
    }
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastRecoveryAt) < const Duration(seconds: 2)) {
      logEvent('[Voice][RECOVERY skipped] debounced');
      return;
    }

    final QuizVoiceAsyncCallback? entryAction = _entryActionPending
        ? _entryCallback
        : null;
    final QuizVoiceAsyncCallback? recoveryAction = _recoveryCallback;
    if (entryAction == null && recoveryAction == null) return;

    logEvent(
      'request recovery, force=$force, preferEntryAction=$preferEntryAction',
    );
    _recoveryInFlight = true;
    _recoveryRunning = true;
    _lastRecoveryAt = now;
    Future<void>(() async {
      try {
        if (screenToken != null && !isCurrentScreenToken(screenToken)) return;
        if ((preferEntryAction || _entryActionPending) && entryAction != null) {
          logEvent('running entry action for recovery');
          _entryActionPending = false;
          await entryAction();
          return;
        }
        if (recoveryAction != null) {
          logEvent('running listening recovery action');
          await recoveryAction();
        }
      } finally {
        logEvent('recovery action completed');
        _recoveryInFlight = false;
        _recoveryRunning = false;
      }
    });
  }

  void _scheduleActivationRecovery({
    required String reason,
    String? screenToken,
  }) {
    _activationRecoveryTimer?.cancel();
    if (!isEnabled.value) return;

    _activationRecoveryTimer = Timer(_activationRecoveryDelay, () {
      _activationRecoveryTimer = null;
      if (screenToken != null && !isCurrentScreenToken(screenToken)) return;
      _recoverAfterActivation(reason, screenToken: screenToken);
    });
  }

  void _recoverAfterActivation(String reason, {String? screenToken}) {
    switch (voiceState.value) {
      case VoiceState.speaking:
        _activationRecoveryTimer?.cancel();
        _activationRecoveryTimer = Timer(_speakingRetryDelay, () {
          _activationRecoveryTimer = null;
          if (screenToken != null && !isCurrentScreenToken(screenToken)) return;
          _recoverAfterActivation(reason, screenToken: screenToken);
        });
        return;
      case VoiceState.listening:
      case VoiceState.processing:
        return;
      case VoiceState.idle:
      case VoiceState.disabled:
      case VoiceState.paused:
      case VoiceState.error:
        _requestHealthRecovery('activation: $reason', screenToken: screenToken);
        return;
    }
  }

  void _requestHealthRecovery(String reason, {String? screenToken}) {
    if (screenToken != null && !isCurrentScreenToken(screenToken)) return;
    if (!isEnabled.value || _activeScreenName == null) return;
    if (_recoveryInFlight || _recoveryRunning) {
      logEvent('[Voice][RECOVERY skipped] $reason');
      return;
    }
    if (_recoveryCallback == null && !_entryActionPending) return;
    if (voiceState.value == VoiceState.speaking) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastHealthRecoveryAt) < _healthRecoveryCooldown) {
      logEvent('health recovery throttled: $reason');
      return;
    }

    _lastHealthRecoveryAt = now;
    logEvent('health recovery requested: $reason');
    requestRecovery(
      force: true,
      preferEntryAction: false,
      screenToken: screenToken ?? _activeScreenToken,
    );
  }

  void _onWatchdogTick() {
    if (!isEnabled.value || _recoveryInFlight) return;
    if (_recoveryCallback == null && !_entryActionPending) return;
    if (_activeScreenName == null) return;

    final Duration inactiveFor = DateTime.now().difference(_lastPhaseChangeAt);

    if (phase.value == QuizVoicePhase.disabled ||
        phase.value == QuizVoicePhase.submitting) {
      return;
    }

    switch (voiceState.value) {
      case VoiceState.listening:
        if (inactiveFor < _listeningRecoveryThreshold) return;
        logEvent(
          '[Voice][STALE LISTEN restart] after $inactiveFor',
          phaseOverride: QuizVoicePhase.listening,
        );
        requestRecovery(
          force: true,
          preferEntryAction: false,
          screenToken: _activeScreenToken,
        );
        return;
      case VoiceState.speaking:
        if (inactiveFor < _speakingRecoveryThreshold) return;
        logEvent(
          'watchdog detected stale speaking after $inactiveFor',
          phaseOverride: QuizVoicePhase.speaking,
        );
        requestRecovery(force: true, preferEntryAction: false);
        return;
      case VoiceState.processing:
        if (inactiveFor < _processingRecoveryThreshold) return;
        _requestHealthRecovery('watchdog stale processing after $inactiveFor');
        return;
      case VoiceState.paused:
      case VoiceState.error:
      case VoiceState.disabled:
      case VoiceState.idle:
        break;
    }

    if (inactiveFor < _idleRecoveryThreshold) return;

    _requestHealthRecovery(
      'watchdog ${voiceState.value.name} after $inactiveFor',
    );
  }

  void logEvent(
    String message, {
    QuizVoiceScreen? screen,
    QuizVoicePhase? phaseOverride,
  }) {
    final now = DateTime.now().toIso8601String();
    final stamp = now.length >= 23 ? now.substring(11, 23) : now;
    final entry =
        '[QuizVoice $stamp] '
        '[${_screenLabel(screen ?? activeScreen.value)}] '
        '[${_phaseLabel(phaseOverride ?? phase.value)}] '
        '$message';
    debugPrint(entry);
    _runReactiveMutation(() {
      recentLogs.add(entry);
      if (recentLogs.length > 120) {
        recentLogs.removeRange(0, recentLogs.length - 120);
      }
    });
  }

  void logTranscript(
    String text, {
    required bool isFinal,
    QuizVoiceScreen? screen,
  }) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;
    final compact = cleaned.length > 140
        ? '${cleaned.substring(0, 140)}...'
        : cleaned;
    logEvent(
      '${isFinal ? 'final' : 'partial'} transcript: "$compact"',
      screen: screen,
    );
  }

  bool _setVoiceStateLocked(VoiceState next, {QuizVoiceScreen? screen}) {
    if (!isEnabled.value &&
        next != VoiceState.disabled &&
        next != VoiceState.paused) {
      return false;
    }

    final previous = voiceState.value;
    if (previous == next) return false;

    voiceState.value = next;
    logEvent(
      'voice state $previous -> $next',
      screen: screen ?? activeScreen.value,
    );
    return true;
  }

  VoiceState _voiceStateForPhase(QuizVoicePhase phaseValue) =>
      switch (phaseValue) {
        QuizVoicePhase.disabled => VoiceState.disabled,
        QuizVoicePhase.idle => VoiceState.idle,
        QuizVoicePhase.speaking => VoiceState.speaking,
        QuizVoicePhase.listening => VoiceState.listening,
        QuizVoicePhase.processing => VoiceState.processing,
        QuizVoicePhase.navigating => VoiceState.paused,
        QuizVoicePhase.submitting => VoiceState.processing,
      };

  QuizVoicePhase _phaseForVoiceState(VoiceState state) => switch (state) {
    VoiceState.disabled => QuizVoicePhase.disabled,
    VoiceState.idle => QuizVoicePhase.idle,
    VoiceState.speaking => QuizVoicePhase.speaking,
    VoiceState.listening => QuizVoicePhase.listening,
    VoiceState.processing => QuizVoicePhase.processing,
    VoiceState.paused => QuizVoicePhase.idle,
    VoiceState.error => QuizVoicePhase.idle,
  };

  String _screenLabel(QuizVoiceScreen screen) => switch (screen) {
    QuizVoiceScreen.none => 'none',
    QuizVoiceScreen.quizSettings => 'settings',
    QuizVoiceScreen.examSession => 'session',
    QuizVoiceScreen.examLoading => 'loading',
    QuizVoiceScreen.mcq => 'mcq',
    QuizVoiceScreen.examReview => 'review',
  };

  String _phaseLabel(QuizVoicePhase phaseValue) => switch (phaseValue) {
    QuizVoicePhase.disabled => 'disabled',
    QuizVoicePhase.idle => 'idle',
    QuizVoicePhase.speaking => 'speaking',
    QuizVoicePhase.listening => 'listening',
    QuizVoicePhase.processing => 'processing',
    QuizVoicePhase.navigating => 'navigating',
    QuizVoicePhase.submitting => 'submitting',
  };
}
