import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../controllers/quiz_voice_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/plan_tier.dart';
import '../../services/api_service.dart';
import '../../utils/api_endpoints.dart';
import '../../utils/app_constants.dart';
import '../../utils/voice_command_processor.dart';
import '../../utils/quiz_voice_intent_parser.dart';
import '../../utils/voice_listen_start.dart';
import '../../utils/quiz_voice_route_aware.dart';
import '../widgets/api_disclaimer_section.dart';

class QuizSettingsScreen extends StatefulWidget {
  final String courseTitle;
  final String? examId;
  final int? questionCount;
  final int? selectedQuestionCount;
  final String? effectivitySheetContent;
  final String? bodyOfKnowledgeContent;

  const QuizSettingsScreen({
    super.key,
    required this.courseTitle,
    this.examId,
    this.questionCount,
    this.selectedQuestionCount,
    this.effectivitySheetContent,
    this.bodyOfKnowledgeContent,
  });

  @override
  State<QuizSettingsScreen> createState() => _QuizSettingsScreenState();
}

class _QuizSettingsScreenState extends State<QuizSettingsScreen>
    with QuizVoiceRouteAware<QuizSettingsScreen> {
  static final Map<String, int> _savedQuestionCountsByExam = <String, int>{};

  final ApiService _apiService = ApiService();
  final SpeechToText _speech = SpeechToText();
  late final FlutterTts _tts;
  double _questionCount = 2;
  bool _timedMode = true;
  final int _monthlyLimit = 16;
  bool _isStarterUsageLoading = false;
  bool _hasStarterSubmittedThisExam = false;
  bool _voiceModeEnabled = false;
  bool _speechAvailable = false;
  bool _speechInitializing = false;
  bool _isListening = false;
  bool _isPreparingToListen = false;
  bool _isSpeaking = false;
  Timer? _listeningRestartTimer;
  String? _speechLocaleId;
  String _heardText = '';
  final VoiceCommandProcessor _voiceCommandProcessor = VoiceCommandProcessor();
  final String _voiceScreenToken =
      'quizSettings-${DateTime.now().microsecondsSinceEpoch}';

  QuizVoiceController get _voiceController =>
      Get.isRegistered<QuizVoiceController>()
      ? Get.find<QuizVoiceController>()
      : Get.put(QuizVoiceController(), permanent: true);

  String? get _examCacheKey {
    final examId = widget.examId?.trim();
    if (examId == null || examId.isEmpty) return null;
    return examId;
  }

  int _resolveInitialQuestionCount() {
    final cachedCount = _examCacheKey == null
        ? null
        : _savedQuestionCountsByExam[_examCacheKey!];
    final candidates = <int?>[
      widget.questionCount,
      widget.selectedQuestionCount,
      cachedCount,
      2,
    ];
    for (final value in candidates) {
      if (value != null && value > 0) {
        return value;
      }
    }
    return 2;
  }

  void _cacheSelectedQuestionCount(int count) {
    final cacheKey = _examCacheKey;
    if (cacheKey == null || count <= 0) return;
    _savedQuestionCountsByExam[cacheKey] = count;
  }

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _voiceModeEnabled = _voiceController.isEnabledValue;
    final int initialCount = _resolveInitialQuestionCount();
    if (initialCount > 0) {
      _questionCount = initialCount.toDouble();
    }
    _cacheSelectedQuestionCount(initialCount);
    _configureTts();
    unawaited(_primeSpeechAvailability());
    _loadStarterExamUsage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _activateVoiceScreen();
        _bindVoiceSession(requestEntryAction: false);
      }
    });
  }

  @override
  void dispose() {
    _listeningRestartTimer?.cancel();
    unawaited(_tts.stop());
    unawaited(_speech.cancel());
    _voiceController.unbindScreen(
      QuizVoiceScreen.quizSettings,
      screenToken: _voiceScreenToken,
    );
    super.dispose();
  }

  void _activateVoiceScreen() {
    _voiceController.activateScreen(
      QuizVoiceScreen.quizSettings,
      _voiceScreenToken,
      onDeactivate: _hardStopInactiveVoice,
    );
  }

  Future<void> _hardStopInactiveVoice() async {
    _listeningRestartTimer?.cancel();
    await _tts.stop();
    await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _isPreparingToListen = false;
    });
  }

  UserController get _userController => Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  bool get _isProUser =>
      _userController.planTier.value == PlanTier.professional;

  int get _totalQuestions {
    final raw = widget.questionCount ?? _resolveInitialQuestionCount();
    return raw > 0 ? raw : 1;
  }

  int get _maxSelectableQuestionCount {
    final freeLimit = _totalQuestions < 2 ? _totalQuestions : 2;
    return _isProUser ? _totalQuestions : freeLimit;
  }

  double get _effectiveQuestionCount =>
      _questionCount.clamp(1, _maxSelectableQuestionCount).toDouble();

  bool get _effectiveTimedMode => _isProUser ? _timedMode : false;
  bool get _autoListenEnabled =>
      _voiceController.assistantSettings.value.autoListenOnScreenOpen;
  bool get _isCurrentVoiceScreen =>
      _voiceController.isCurrentScreenToken(_voiceScreenToken);

  Future<void> _configureTts() async {
    await _applyVoiceAssistantSettings();
    _tts.setCompletionHandler(() {
      if (!mounted || !_isCurrentVoiceScreen) return;
      setState(() => _isSpeaking = false);
      _syncVoiceSessionState();
      if (_voiceModeEnabled && _autoListenEnabled && !_isListening) {
        _scheduleListeningRestart(const Duration(milliseconds: 450));
      }
    });
    _tts.setCancelHandler(() {
      if (!mounted || !_isCurrentVoiceScreen) return;
      setState(() => _isSpeaking = false);
      _syncVoiceSessionState();
    });
    _tts.setErrorHandler((_) {
      if (!mounted || !_isCurrentVoiceScreen) return;
      setState(() => _isSpeaking = false);
      _syncVoiceSessionState();
    });
  }

  Future<void> _applyVoiceAssistantSettings() async {
    final settings = _voiceController.assistantSettings.value;
    await _tts.setLanguage(settings.languageCode);
    await _tts.setSpeechRate(settings.voiceSpeed);
    await _tts.setPitch(settings.voicePitch);
  }

  void _bindVoiceSession({bool requestEntryAction = false}) {
    _voiceController.bindScreen(
      screen: QuizVoiceScreen.quizSettings,
      screenToken: _voiceScreenToken,
      onRecoverListening: () async {
        await _forceVoiceRecovery();
      },
      onEntryAction: () async {
        if (!mounted || !_voiceModeEnabled || _isStarterUsageLoading) return;
        await _speakSettingsSummary();
      },
      requestEntryAction: requestEntryAction && _autoListenEnabled,
    );
    _syncVoiceSessionState();
  }

  Future<void> _forceVoiceRecovery() async {
    if (!mounted ||
        !_isCurrentVoiceScreen ||
        !_voiceModeEnabled ||
        _isStarterUsageLoading) {
      return;
    }
    _voiceController.logEvent(
      'force voice recovery',
      screen: QuizVoiceScreen.quizSettings,
    );
    _listeningRestartTimer?.cancel();
    await _tts.stop();
    await _speech.cancel();
    if (!mounted ||
        !_isCurrentVoiceScreen ||
        !_voiceModeEnabled ||
        _isStarterUsageLoading) {
      return;
    }
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _isPreparingToListen = false;
      _heardText = '';
    });
    _voiceController.setVoiceState(
      VoiceState.idle,
      screen: QuizVoiceScreen.quizSettings,
    );
    _syncVoiceSessionState();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted ||
        !_isCurrentVoiceScreen ||
        !_voiceModeEnabled ||
        _isStarterUsageLoading ||
        _isSpeaking) {
      return;
    }
    await _startListening();
  }

  @override
  void onVoiceRouteActive() {
    if (!mounted) return;
    _activateVoiceScreen();
    _bindVoiceSession(requestEntryAction: false);
  }

  @override
  void onVoiceRouteInactive() {
    if (_voiceModeEnabled) _voiceController.beginNavigation();
    _voiceController.deactivateScreen(_voiceScreenToken);
  }

  void _syncVoiceSessionState() {
    _voiceController.setVoiceEnabled(
      _voiceModeEnabled,
      screen: QuizVoiceScreen.quizSettings,
    );
    _voiceController.markHeardText(_heardText);
    if (!_voiceModeEnabled) return;
    final phase = _isSpeaking
        ? QuizVoicePhase.speaking
        : _isListening
        ? QuizVoicePhase.listening
        : QuizVoicePhase.idle;
    _voiceController.setPhase(phase, screen: QuizVoiceScreen.quizSettings);
  }

  Future<void> _primeSpeechAvailability() async {
    final hasPermission = await _speech.hasPermission;
    if (!hasPermission) {
      if (!mounted) return;
      setState(() {
        _speechAvailable = false;
        _speechLocaleId = null;
      });
      return;
    }
    await _initSpeech();
  }

  Future<bool> _initSpeech({bool requestPermission = false}) async {
    if (_speechInitializing) return _speechAvailable;
    if (!requestPermission && !_speechAvailable) {
      final hasPermission = await _speech.hasPermission;
      if (!hasPermission) {
        if (!mounted) return false;
        setState(() {
          _speechAvailable = false;
          _speechLocaleId = null;
        });
        return false;
      }
    }

    _speechInitializing = true;
    try {
      final available = await _speech.initialize(
        onError: (error) {
          if (!mounted || !_isCurrentVoiceScreen) return;
          _voiceController.logEvent(
            'speech error: $error',
            screen: QuizVoiceScreen.quizSettings,
          );
          setState(() {
            _isListening = false;
            _isPreparingToListen = false;
          });
          _syncVoiceSessionState();
          _scheduleListeningRestart();
        },
        onStatus: (status) {
          if (!mounted || !_isCurrentVoiceScreen) return;
          _voiceController.logEvent(
            'speech status: $status',
            screen: QuizVoiceScreen.quizSettings,
          );
          _voiceController.onSpeechStatus(
            status,
            screen: QuizVoiceScreen.quizSettings,
            screenToken: _voiceScreenToken,
          );
          if (status == 'listening' &&
              (!_isListening || _isPreparingToListen)) {
            setState(() {
              _isListening = true;
              _isPreparingToListen = false;
            });
            _syncVoiceSessionState();
          }
          if (status == 'done' || status == 'notListening') {
            if (_isListening || _isPreparingToListen) {
              setState(() {
                _isListening = false;
                _isPreparingToListen = false;
              });
              _syncVoiceSessionState();
            }
            _scheduleListeningRestart();
          }
        },
        options: [SpeechToText.androidNoBluetooth],
      );
      String? preferredLocaleId;
      if (available) {
        preferredLocaleId = await _resolvePreferredSpeechLocaleId();
      }
      if (mounted) {
        setState(() {
          _speechAvailable = available;
          _speechLocaleId = preferredLocaleId;
        });
      }
      return available;
    } catch (error, stackTrace) {
      _voiceController.logEvent(
        'speech initialize failed: $error\n$stackTrace',
        screen: QuizVoiceScreen.quizSettings,
      );
      if (mounted) {
        setState(() {
          _speechAvailable = false;
          _speechLocaleId = null;
        });
      }
      return false;
    } finally {
      _speechInitializing = false;
    }
  }

  Future<String?> _resolvePreferredSpeechLocaleId() async {
    try {
      final systemLocale = await _speech.systemLocale();
      final locales = await _speech.locales();
      final localeIds = locales.map((locale) => locale.localeId).toSet();
      final configuredLocaleId =
          _voiceController.assistantSettings.value.languageCode;
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

  Future<void> _showSpeechUnavailableMessage() async {
    final hasPermission = await _speech.hasPermission;
    if (!mounted) return;
    final message = hasPermission
        ? 'Speech recognition is not available on this device right now.'
        : 'Microphone permission is required for voice mode. Enable it in Android settings and try again.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _speakFeedback(String text) async {
    _voiceController.logEvent(
      'speak feedback requested',
      screen: QuizVoiceScreen.quizSettings,
    );
    await _speech.cancel();
    await _tts.stop();
    await _applyVoiceAssistantSettings();
    if (!mounted) return;
    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });
    _syncVoiceSessionState();
    await _tts.speak(text);
  }

  Future<void> _speakSettingsSummary({bool force = false}) async {
    final String timedText = _effectiveTimedMode
        ? 'Timed mode is on.'
        : 'Timed mode is off.';
    final String accessText = _isProUser
        ? 'You can choose up to $_totalQuestions questions.'
        : 'Starter plan allows up to $_maxSelectableQuestionCount questions.';
    final text =
        'Quiz settings. ${_effectiveQuestionCount.toInt()} questions selected. $timedText $accessText '
        'Say set questions to a number, turn timed mode on or off, start quiz, or go back.';
    final examKey = widget.examId?.trim().isNotEmpty == true
        ? widget.examId!.trim()
        : widget.courseTitle;
    final shouldSpeak = _voiceController.speakOnce(
      key: 'settings_$examKey',
      text: text,
      force: force,
      screen: QuizVoiceScreen.quizSettings,
    );
    if (!shouldSpeak) {
      _scheduleListeningRestart();
      return;
    }
    await _speakFeedback(text);
  }

  void _scheduleListeningRestart([
    Duration delay = const Duration(milliseconds: 700),
  ]) {
    _listeningRestartTimer?.cancel();
    if (!_voiceModeEnabled || !_autoListenEnabled) return;
    final retryDelay = enforceMinimumVoiceListenRetryDelay(delay);
    if (mounted &&
        !_isListening &&
        !_isSpeaking &&
        !_isStarterUsageLoading &&
        !_isPreparingToListen) {
      setState(() => _isPreparingToListen = true);
    }
    _listeningRestartTimer = Timer(retryDelay, () {
      if (!mounted ||
          !_isCurrentVoiceScreen ||
          !_voiceModeEnabled ||
          _isListening ||
          _isSpeaking ||
          _isStarterUsageLoading) {
        return;
      }
      unawaited(_startListening());
    });
  }

  Future<void> _startListening() async {
    if (!_isCurrentVoiceScreen) return;
    _voiceController.logEvent(
      'start listening requested',
      screen: QuizVoiceScreen.quizSettings,
    );
    _listeningRestartTimer?.cancel();
    if (_isListening || _isSpeaking) return;
    setState(() {
      _isPreparingToListen = true;
      _heardText = '';
    });
    _voiceController.markHeardText(_heardText);
    await _tts.stop();
    if (!mounted || !_isCurrentVoiceScreen) return;
    if (!_speechAvailable) {
      final speechReady = await _initSpeech();
      if (!speechReady) {
        if (mounted) setState(() => _isPreparingToListen = false);
        return;
      }
    }
    _voiceController.logEvent(
      'speech listen call starting',
      screen: QuizVoiceScreen.quizSettings,
    );
    final started = await startSpeechListeningSafely(
      speech: _speech,
      controller: _voiceController,
      screen: QuizVoiceScreen.quizSettings,
      onResult: _onSpeechResult,
      localeId: _speechLocaleId,
    );
    if (!mounted || !_isCurrentVoiceScreen) return;
    if (!started) {
      setState(() {
        _isListening = false;
        _isPreparingToListen = false;
      });
      _syncVoiceSessionState();
      _voiceController.logEvent(
        'speech listen did not start, retry scheduled',
        screen: QuizVoiceScreen.quizSettings,
      );
      _scheduleListeningRestart();
      return;
    }
    setState(() {
      _isListening = true;
      _isPreparingToListen = false;
    });
    _syncVoiceSessionState();
    _voiceController.logEvent(
      'speech listen active',
      screen: QuizVoiceScreen.quizSettings,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted || !_isCurrentVoiceScreen) return;
    setState(() => _heardText = result.recognizedWords);
    _voiceController.markHeardText(_heardText);
    _voiceController.logTranscript(
      result.recognizedWords,
      isFinal: result.finalResult,
      screen: QuizVoiceScreen.quizSettings,
    );
    if (result.finalResult) {
      setState(() {
        _isListening = false;
        _isPreparingToListen = false;
      });
      _voiceController.setPhase(
        QuizVoicePhase.processing,
        screen: QuizVoiceScreen.quizSettings,
      );
      final text = result.recognizedWords.trim();
      if (text.isNotEmpty) {
        unawaited(_handleVoiceCommand(text));
      }
    }
  }

  Future<void> _handleVoiceCommand(String rawText) async {
    final decision = await _voiceCommandProcessor.process(
      screen: QuizVoiceScreen.quizSettings,
      heardText: rawText,
      sensitivity: _voiceController.assistantSettings.value.commandSensitivity,
    );
    final result = decision.parseResult;
    final requestedQuestionCount = decision.requestedQuestionCount;
    _voiceController.logEvent(
      'parsed intent: ${result.intent?.name ?? 'none'}'
      '${requestedQuestionCount != null ? ' ($requestedQuestionCount)' : ''}'
      ' confidence: ${result.confidence.toStringAsFixed(2)}',
      screen: QuizVoiceScreen.quizSettings,
    );
    _voiceController.markCommandResult(
      command: result.intent == null
          ? null
          : QuizVoiceIntentParser.commandLabelFor(result.intent!),
      confidence: result.confidence,
      retry: decision.feedback,
    );
    if (!decision.shouldExecute && decision.feedback != null) {
      unawaited(_speakFeedback(decision.feedback!));
      return;
    }

    switch (decision.intent) {
      case VoiceIntent.stopVoice:
        unawaited(_speakAndDisableVoiceMode('Voice mode turned off.'));
        return;
      case VoiceIntent.help:
        unawaited(_speakSettingsSummary(force: true));
        return;
      case VoiceIntent.startQuiz:
        _startQuiz();
        return;
      case VoiceIntent.back:
        _goBackHome();
        return;
      case VoiceIntent.timedModeOn:
        _setTimedMode(true);
        return;
      case VoiceIntent.timedModeOff:
        _setTimedMode(false);
        return;
      case VoiceIntent.maxQuestions:
        _setQuestionCount(_maxSelectableQuestionCount);
        return;
      case VoiceIntent.minQuestions:
        _setQuestionCount(1);
        return;
      case VoiceIntent.increaseQuestions:
        _setQuestionCount(
          (_effectiveQuestionCount.toInt() + 1).clamp(
            1,
            _maxSelectableQuestionCount,
          ),
        );
        return;
      case VoiceIntent.decreaseQuestions:
        _setQuestionCount(
          (_effectiveQuestionCount.toInt() - 1).clamp(
            1,
            _maxSelectableQuestionCount,
          ),
        );
        return;
      case VoiceIntent.setQuestionCount:
        if (requestedQuestionCount != null) {
          _setQuestionCount(requestedQuestionCount);
          return;
        }
        break;
      default:
        break;
    }

    final heard = rawText.trim().isNotEmpty ? 'I heard "$rawText". ' : '';
    unawaited(
      _speakFeedback(
        '${heard}Try set questions to a number, timed mode on or off, start quiz, or go back.',
      ),
    );
  }

  void _setQuestionCount(int requested) {
    final clamped = requested.clamp(1, _maxSelectableQuestionCount);
    setState(() {
      _questionCount = clamped.toDouble();
      _cacheSelectedQuestionCount(clamped);
    });
    final String response = clamped == requested
        ? '$clamped questions selected.'
        : 'Using $clamped questions. That is the allowed limit here.';
    unawaited(_speakFeedback(response));
  }

  void _setTimedMode(bool enabled) {
    if (!_isProUser) {
      unawaited(
        _speakFeedback(
          'Timed mode is available on the professional plan only.',
        ),
      );
      return;
    }
    setState(() => _timedMode = enabled);
    unawaited(_speakFeedback(enabled ? 'Timed mode on.' : 'Timed mode off.'));
  }

  Future<void> _startQuiz() async {
    if (!_isProUser && _hasStarterSubmittedThisExam) {
      unawaited(
        _speakFeedback(
          'Starter access is used for this exam. Opening upgrade options.',
        ),
      );
      context.go('/subscribe');
      return;
    }

    final examId = widget.examId?.trim();
    if (examId == null || examId.isEmpty) {
      unawaited(
        _speakFeedback('Exam ID is missing. Please go back and try again.'),
      );
      return;
    }

    _cacheSelectedQuestionCount(_effectiveQuestionCount.toInt());
    unawaited(_tts.stop());
    unawaited(_speech.cancel());
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isListening = false;
      });
    }
    _voiceController.beginNavigation(targetScreen: QuizVoiceScreen.examSession);
    await context.push(
      '/exam-session',
      extra: {
        'courseTitle': widget.courseTitle,
        'examId': examId,
        'questionCount': _effectiveQuestionCount.toInt(),
        'totalQuestionCount': _totalQuestions,
        'selectedQuestionCount': _effectiveQuestionCount.toInt(),
        'effectivitySheetContent': widget.effectivitySheetContent,
        'bodyOfKnowledgeContent': widget.bodyOfKnowledgeContent,
        'timedMode': _effectiveTimedMode,
        'voiceModeEnabled': _voiceModeEnabled,
        'voicePracticeMode': false,
      },
    );
    if (!mounted || !_voiceModeEnabled) return;
    _bindVoiceSession(requestEntryAction: false);
  }

  Future<void> _startManualPractice() async {
    if (_voiceModeEnabled) {
      await _speech.cancel();
      await _tts.stop();
      if (!mounted) return;
      setState(() {
        _voiceModeEnabled = false;
        _isListening = false;
        _isSpeaking = false;
        _heardText = '';
      });
      _syncVoiceSessionState();
    }
    await _startQuiz();
  }

  Future<void> _startVoicePractice() async {
    final speechReady = await _initSpeech(requestPermission: true);
    if (!speechReady) {
      await _showSpeechUnavailableMessage();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadyAccepted =
        prefs.getBool(AppConstants.voicePracticeDisclaimerAcceptedKey) ?? false;

    if (!alreadyAccepted) {
      final accepted = await _showVoicePracticeDisclaimer();
      if (accepted != true) return;
    }

    if (!mounted) return;
    setState(() {
      _voiceModeEnabled = true;
      _heardText = '';
    });
    _voiceController.setVoiceEnabled(
      true,
      screen: QuizVoiceScreen.quizSettings,
    );

    final examId = widget.examId?.trim();
    if (examId == null || examId.isEmpty) {
      unawaited(
        _speakFeedback('Exam ID is missing. Please go back and try again.'),
      );
      return;
    }

    _cacheSelectedQuestionCount(_effectiveQuestionCount.toInt());
    unawaited(_tts.stop());
    unawaited(_speech.cancel());
    _voiceController.beginNavigation(targetScreen: QuizVoiceScreen.examLoading);
    context.push(
      '/exam-loading',
      extra: {
        'courseTitle': widget.courseTitle,
        'examId': examId,
        'questionCount': _effectiveQuestionCount.toInt(),
        'totalQuestionCount': _totalQuestions,
        'timedMode': false,
        'voiceModeEnabled': true,
        'voicePracticeMode': true,
      },
    );
  }

  Future<bool?> _showVoicePracticeDisclaimer() async {
    var dontShowAgain = false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Voice Practice Safety'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Use Voice Practice only when it is safe to do so. Do not interact with the app if you are distracted or driving in unsafe conditions. Your safety comes first.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Voice Practice Mode is provided for educational purposes only. Users must use the feature safely and avoid using it in any situation that may cause distraction or risk.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: dontShowAgain,
                    onChanged: (value) {
                      setDialogState(() => dontShowAgain = value ?? false);
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text("Don't show again"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (dontShowAgain) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(
                        AppConstants.voicePracticeDisclaimerAcceptedKey,
                        true,
                      );
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('I Understand, Start Voice Practice'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _goBackHome() {
    unawaited(_tts.stop());
    unawaited(_speech.cancel());
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isListening = false;
      });
    }
    _voiceController.setVoiceEnabled(
      false,
      screen: QuizVoiceScreen.quizSettings,
    );
    context.go('/home');
  }

  Future<void> _speakAndDisableVoiceMode(String message) async {
    _listeningRestartTimer?.cancel();
    await _speech.cancel();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _voiceModeEnabled = false;
      _isListening = false;
      _isSpeaking = false;
      _heardText = '';
    });
    _syncVoiceSessionState();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadStarterExamUsage() async {
    final UserController userController = Get.isRegistered<UserController>()
        ? Get.find<UserController>()
        : Get.put(UserController());
    final bool isPro = userController.planTier.value == PlanTier.professional;
    final String? examId = widget.examId?.trim();
    if (isPro || examId == null || examId.isEmpty) return;

    setState(() => _isStarterUsageLoading = true);
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.historyAttempts,
      queryParams: {
        'page': '1',
        'limit': '1',
        'examId': examId,
        'status': 'SUBMITTED',
      },
      fromJson: (json) => json is Map<String, dynamic>
          ? json
          : Map<String, dynamic>.from(json as Map),
    );
    if (!mounted) return;

    bool hasSubmitted = false;
    if (response.success && response.data != null) {
      final attemptsRaw = response.data!['attempts'];
      hasSubmitted = attemptsRaw is List && attemptsRaw.isNotEmpty;
    }

    setState(() {
      _hasStarterSubmittedThisExam = hasSubmitted;
      _isStarterUsageLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool isPro = _isProUser;
      final int totalQuestions = _totalQuestions;
      final int maxSelectable = _maxSelectableQuestionCount;
      final int usedForExam = (!isPro && _hasStarterSubmittedThisExam)
          ? maxSelectable
          : 0;
      final double effectiveQuestionCount = _effectiveQuestionCount;

      return Scaffold(
        backgroundColor: const Color(0xFFF2F5FF),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.arrow_back, size: 22),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Quiz Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D4F88),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isPro)
                _InfoCard(
                  backgroundColor: const Color(0xFFE7F0FF),
                  borderColor: const Color(0xFFD4E2F7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Starter Plan Limits',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Questions remaining this month: $_monthlyLimit/$_monthlyLimit',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Questions used for "${widget.courseTitle}": $usedForExam/$maxSelectable',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (_isStarterUsageLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              _InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Number of Questions: ${effectiveQuestionCount.toInt()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Slider(
                      value: effectiveQuestionCount,
                      min: 1,
                      max: maxSelectable.toDouble(),
                      divisions: maxSelectable > 1 ? maxSelectable - 1 : null,
                      activeColor: const Color(0xFF1E4C9A),
                      inactiveColor: const Color(0xFFE4ECFA),
                      onChanged: isPro
                          ? (value) => setState(() {
                              _questionCount = value;
                              _cacheSelectedQuestionCount(value.toInt());
                            })
                          : null,
                    ),
                    Text(
                      isPro
                          ? 'You can access all $totalQuestions question(s) for this exam.'
                          : 'Free users can access $maxSelectable question(s) per session.',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // _InfoCard(
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       const Text(
              //         'Focus on Specific Topics (Optional)',
              //         style: TextStyle(
              //           fontSize: 20,
              //           fontWeight: FontWeight.w700,
              //           color: Color(0xFF111827),
              //         ),
              //       ),
              //       const SizedBox(height: 8),
              //       TextField(
              //         enabled: false,
              //         decoration: InputDecoration(
              //           hintText: 'e.g., welding, NDE, corrosion',
              //           hintStyle: const TextStyle(
              //             color: Color(0xFF9CA3AF),
              //             fontWeight: FontWeight.w500,
              //           ),
              //           filled: true,
              //           fillColor: const Color(0xFFF8FAFF),
              //           disabledBorder: OutlineInputBorder(
              //             borderRadius: BorderRadius.circular(14),
              //             borderSide: const BorderSide(color: Color(0xFFC8D3E7)),
              //           ),
              //         ),
              //       ),
              //       const SizedBox(height: 8),
              //       const Text(
              //         'Upgrade to a paid plan to use this feature.',
              //         style: TextStyle(
              //           fontSize: 13,
              //           fontWeight: FontWeight.w500,
              //           color: Color(0xFF6B7280),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              const SizedBox(height: 16),
              if (isPro) ...[
                _InfoCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Enable Timed Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Switch(
                        value: _timedMode,
                        activeThumbColor: const Color(0xFF2F6DE0),
                        onChanged: (value) =>
                            setState(() => _timedMode = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final useRow = constraints.maxWidth >= 640;
                  final manualButton = _PrimaryButton(
                    label: 'Start Manual Practice',
                    subtext:
                        'Begin manual practice with full question interaction.',
                    icon: Icons.touch_app_rounded,
                    onTap: _startManualPractice,
                  );
                  final voiceButton = _PrimaryButton(
                    label: 'Start Voice Practice',
                    subtext: 'Practice hands-free using voice commands.',
                    icon: Icons.play_circle_fill_rounded,
                    onTap: _startVoicePractice,
                  );
                  if (useRow) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: manualButton),
                        const SizedBox(width: 12),
                        Expanded(child: voiceButton),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      manualButton,
                      const SizedBox(height: 12),
                      voiceButton,
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              const ApiDisclaimerSection(),
            ],
          ),
        ),
        bottomSheet: null,
      );
    });
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;

  const _InfoCard({
    required this.child,
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFE5E7EB),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final String subtext;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
    required this.subtext,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 78),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F3A7D), Color(0xFF174A97)],
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtext,
                    style: const TextStyle(
                      color: Color(0xFFE7F0FF),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
