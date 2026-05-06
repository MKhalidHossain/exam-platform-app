import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

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

typedef QuizVoiceAsyncCallback = Future<void> Function();

class QuizVoiceController extends GetxController with WidgetsBindingObserver {
  static const Duration _idleRecoveryThreshold = Duration(seconds: 1);
  static const Duration _processingRecoveryThreshold = Duration(seconds: 5);
  static const Duration _speakingRecoveryThreshold = Duration(seconds: 8);
  static const Duration _listeningRecoveryThreshold = Duration(seconds: 55);

  final RxBool isEnabled = false.obs;
  final RxBool isDebugPanelExpanded = false.obs;
  final Rx<QuizVoiceScreen> activeScreen = QuizVoiceScreen.none.obs;
  final Rx<QuizVoicePhase> phase = QuizVoicePhase.disabled.obs;
  final RxString heardText = ''.obs;
  final RxList<String> recentLogs = <String>[].obs;

  Timer? _watchdogTimer;
  QuizVoiceAsyncCallback? _recoveryCallback;
  QuizVoiceAsyncCallback? _entryCallback;
  bool _entryActionPending = false;
  bool _recoveryInFlight = false;
  DateTime _lastPhaseChangeAt = DateTime.now();
  DateTime _lastRecoveryAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isEnabledValue => isEnabled.value;
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

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    logEvent('controller initialized');
    _watchdogTimer = Timer.periodic(
      const Duration(milliseconds: 1200),
      (_) => _onWatchdogTick(),
    );
  }

  @override
  void onClose() {
    logEvent('controller closing');
    WidgetsBinding.instance.removeObserver(this);
    _watchdogTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    logEvent('app lifecycle: $state');
    if (state == AppLifecycleState.resumed && isEnabled.value) {
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        requestRecovery(force: true, preferEntryAction: false);
      });
    }
  }

  void bindScreen({
    required QuizVoiceScreen screen,
    QuizVoiceAsyncCallback? onRecoverListening,
    QuizVoiceAsyncCallback? onEntryAction,
    bool requestEntryAction = false,
  }) {
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
        requestRecovery(force: true, preferEntryAction: requestEntryAction);
      }
    });
  }

  void unbindScreen(QuizVoiceScreen screen) {
    if (activeScreen.value != screen) return;
    _recoveryCallback = null;
    _entryCallback = null;
    _runReactiveMutation(() {
      logEvent('unbind screen', screen: screen);
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
        heardText.value = '';
        _entryActionPending = false;
        _lastPhaseChangeAt = DateTime.now();
        return;
      }

      if (phase.value == QuizVoicePhase.disabled) {
        phase.value = QuizVoicePhase.idle;
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
        _lastPhaseChangeAt = DateTime.now();
      }
    });
  }

  void markHeardText(String text) {
    _runReactiveMutation(() {
      heardText.value = text;
    });
  }

  void clearHeardText() {
    _runReactiveMutation(() {
      heardText.value = '';
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

  void requestRecovery({bool force = false, bool preferEntryAction = false}) {
    if (_shouldDeferReactiveMutation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isClosed) return;
        requestRecovery(force: force, preferEntryAction: preferEntryAction);
      });
      return;
    }
    if (!isEnabled.value || _recoveryInFlight) return;
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastRecoveryAt) < const Duration(milliseconds: 900)) {
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
    _lastRecoveryAt = now;
    Future<void>(() async {
      try {
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
      }
    });
  }

  void _onWatchdogTick() {
    if (!isEnabled.value || _recoveryInFlight) return;
    if (_recoveryCallback == null && !_entryActionPending) return;

    final Duration inactiveFor = DateTime.now().difference(_lastPhaseChangeAt);

    switch (phase.value) {
      case QuizVoicePhase.disabled:
      case QuizVoicePhase.submitting:
        return;
      case QuizVoicePhase.listening:
        if (inactiveFor < _listeningRecoveryThreshold) return;
        logEvent(
          'watchdog detected stale listening after $inactiveFor',
          phaseOverride: QuizVoicePhase.listening,
        );
        requestRecovery(force: true, preferEntryAction: false);
        return;
      case QuizVoicePhase.speaking:
        if (inactiveFor < _speakingRecoveryThreshold) return;
        logEvent(
          'watchdog detected stale speaking after $inactiveFor',
          phaseOverride: QuizVoicePhase.speaking,
        );
        requestRecovery(force: true, preferEntryAction: false);
        return;
      case QuizVoicePhase.processing:
        if (inactiveFor < _processingRecoveryThreshold) return;
        logEvent(
          'watchdog detected stale processing after $inactiveFor',
          phaseOverride: QuizVoicePhase.processing,
        );
        requestRecovery(force: true, preferEntryAction: false);
        return;
      case QuizVoicePhase.idle:
      case QuizVoicePhase.navigating:
        break;
    }

    if (inactiveFor < _idleRecoveryThreshold) return;

    logEvent('watchdog requested recovery after $inactiveFor');
    requestRecovery(preferEntryAction: _entryActionPending);
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
