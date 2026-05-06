import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../controllers/quiz_voice_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/plan_tier.dart';
import '../../services/api_service.dart';
import '../../utils/api_endpoints.dart';
import '../../utils/quiz_voice_intent_parser.dart';
import '../../utils/quiz_voice_route_aware.dart';
import '../widgets/api_disclaimer_section.dart';
import '../widgets/quiz_voice_debug_panel.dart';
import '../widgets/quiz_voice_overlay.dart';

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
        _bindVoiceSession(requestEntryAction: false);
      }
    });
  }

  @override
  void dispose() {
    _listeningRestartTimer?.cancel();
    unawaited(_tts.stop());
    unawaited(_speech.cancel());
    _voiceController.unbindScreen(QuizVoiceScreen.quizSettings);
    super.dispose();
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

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      _syncVoiceSessionState();
      if (_voiceModeEnabled && !_isListening) {
        _scheduleListeningRestart(const Duration(milliseconds: 450));
      }
    });
    _tts.setCancelHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      _syncVoiceSessionState();
    });
    _tts.setErrorHandler((_) {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      _syncVoiceSessionState();
    });
  }

  void _bindVoiceSession({bool requestEntryAction = false}) {
    _voiceController.bindScreen(
      screen: QuizVoiceScreen.quizSettings,
      onRecoverListening: () async {
        await _forceVoiceRecovery();
      },
      onEntryAction: () async {
        if (!mounted || !_voiceModeEnabled || _isStarterUsageLoading) return;
        await _speakSettingsSummary();
      },
      requestEntryAction: requestEntryAction,
    );
    _syncVoiceSessionState();
  }

  Future<void> _forceVoiceRecovery() async {
    if (!mounted || !_voiceModeEnabled || _isStarterUsageLoading) return;
    _voiceController.logEvent(
      'force voice recovery',
      screen: QuizVoiceScreen.quizSettings,
    );
    _listeningRestartTimer?.cancel();
    await _tts.stop();
    await _speech.cancel();
    if (!mounted || !_voiceModeEnabled || _isStarterUsageLoading) return;
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _heardText = '';
    });
    _syncVoiceSessionState();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted || !_voiceModeEnabled || _isStarterUsageLoading) return;
    await _startListening();
  }

  @override
  void onVoiceRouteActive() {
    if (!mounted) return;
    _bindVoiceSession(requestEntryAction: false);
  }

  @override
  void onVoiceRouteInactive() {
    if (!_voiceModeEnabled) return;
    _voiceController.beginNavigation();
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
          if (!mounted) return;
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
          if (!mounted) return;
          _voiceController.logEvent(
            'speech status: $status',
            screen: QuizVoiceScreen.quizSettings,
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
    } finally {
      _speechInitializing = false;
    }
  }

  Future<String?> _resolvePreferredSpeechLocaleId() async {
    try {
      final systemLocale = await _speech.systemLocale();
      final locales = await _speech.locales();
      final localeIds = locales.map((locale) => locale.localeId).toSet();
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

  Future<void> _toggleVoiceMode() async {
    if (_voiceModeEnabled) {
      _listeningRestartTimer?.cancel();
      await _tts.stop();
      await _speech.cancel();
      if (!mounted) return;
      setState(() {
        _voiceModeEnabled = false;
        _isListening = false;
        _isSpeaking = false;
        _heardText = '';
      });
      _syncVoiceSessionState();
      return;
    }

    final speechReady = await _initSpeech(requestPermission: true);
    if (!speechReady) {
      await _showSpeechUnavailableMessage();
      return;
    }

    setState(() {
      _voiceModeEnabled = true;
      _heardText = '';
    });
    _bindVoiceSession(requestEntryAction: false);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted && _voiceModeEnabled) {
      _voiceController.setVoiceEnabled(
        true,
        screen: QuizVoiceScreen.quizSettings,
        requestEntryAction: true,
      );
      await _speakSettingsSummary();
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
    if (!mounted) return;
    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });
    _syncVoiceSessionState();
    await _tts.speak(text);
  }

  Future<void> _speakSettingsSummary() async {
    final String timedText = _effectiveTimedMode
        ? 'Timed mode is on.'
        : 'Timed mode is off.';
    final String accessText = _isProUser
        ? 'You can choose up to $_totalQuestions questions.'
        : 'Starter plan allows up to $_maxSelectableQuestionCount questions.';
    await _speakFeedback(
      'Quiz settings. ${_effectiveQuestionCount.toInt()} questions selected. $timedText $accessText '
      'Say set questions to a number, turn timed mode on or off, start quiz, or go back.',
    );
  }

  void _scheduleListeningRestart([
    Duration delay = const Duration(milliseconds: 700),
  ]) {
    _listeningRestartTimer?.cancel();
    if (!_voiceModeEnabled) return;
    if (mounted &&
        !_isListening &&
        !_isSpeaking &&
        !_isStarterUsageLoading &&
        !_isPreparingToListen) {
      setState(() => _isPreparingToListen = true);
    }
    _listeningRestartTimer = Timer(delay, () {
      if (!mounted ||
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
    bool started = false;
    try {
      started = await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(minutes: 1),
        localeId: _speechLocaleId,
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (error) {
      _voiceController.logEvent(
        'speech listen start failed: $error',
        screen: QuizVoiceScreen.quizSettings,
      );
    }
    if (!mounted) return;
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

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _isPreparingToListen = false;
    });
    _syncVoiceSessionState();
  }

  Future<void> _interruptAndListen() async {
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _isPreparingToListen = false;
    });
    _syncVoiceSessionState();
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      unawaited(_startListening());
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
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
        _handleVoiceCommand(text);
      }
    }
  }

  void _handleVoiceCommand(String rawText) {
    final result = QuizVoiceIntentParser.parse(
      QuizVoiceScreen.quizSettings,
      rawText,
    );
    _voiceController.logEvent(
      'parsed intent: ${result.intent.name}'
      '${result.numberValue != null ? ' (${result.numberValue})' : ''}',
      screen: QuizVoiceScreen.quizSettings,
    );

    switch (result.intent) {
      case QuizVoiceIntent.stopVoiceMode:
        unawaited(_speakAndDisableVoiceMode('Voice mode turned off.'));
        return;
      case QuizVoiceIntent.help:
        unawaited(_speakSettingsSummary());
        return;
      case QuizVoiceIntent.startQuiz:
        _startQuiz();
        return;
      case QuizVoiceIntent.goBack:
        _goBackHome();
        return;
      case QuizVoiceIntent.timedModeOn:
        _setTimedMode(true);
        return;
      case QuizVoiceIntent.timedModeOff:
        _setTimedMode(false);
        return;
      case QuizVoiceIntent.maxQuestions:
        _setQuestionCount(_maxSelectableQuestionCount);
        return;
      case QuizVoiceIntent.minQuestions:
        _setQuestionCount(1);
        return;
      case QuizVoiceIntent.increaseQuestions:
        _setQuestionCount(
          (_effectiveQuestionCount.toInt() + 1).clamp(
            1,
            _maxSelectableQuestionCount,
          ),
        );
        return;
      case QuizVoiceIntent.decreaseQuestions:
        _setQuestionCount(
          (_effectiveQuestionCount.toInt() - 1).clamp(
            1,
            _maxSelectableQuestionCount,
          ),
        );
        return;
      case QuizVoiceIntent.setQuestionCount:
        if (result.numberValue != null) {
          _setQuestionCount(result.numberValue!);
          return;
        }
        break;
      case QuizVoiceIntent.unknown:
      case QuizVoiceIntent.startTest:
      case QuizVoiceIntent.explainQuestion:
      case QuizVoiceIntent.openReview:
      case QuizVoiceIntent.status:
      case QuizVoiceIntent.nextQuestion:
      case QuizVoiceIntent.pauseAssistant:
      case QuizVoiceIntent.retry:
      case QuizVoiceIntent.cancel:
      case QuizVoiceIntent.questionNumber:
      case QuizVoiceIntent.confirmSubmit:
      case QuizVoiceIntent.submit:
      case QuizVoiceIntent.unanswered:
      case QuizVoiceIntent.flagged:
      case QuizVoiceIntent.readSummary:
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
      },
    );
    if (!mounted || !_voiceModeEnabled) return;
    _bindVoiceSession(requestEntryAction: false);
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
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              _voiceModeEnabled ? 156 : 24,
            ),
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
                  _SettingsVoiceModeButton(
                    isEnabled: _voiceModeEnabled,
                    isListening: _isListening || _isPreparingToListen,
                    speechAvailable: _speechAvailable,
                    onTap: _toggleVoiceMode,
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
              _PrimaryButton(label: 'Start Quiz', onTap: _startQuiz),
              const SizedBox(height: 18),
              const ApiDisclaimerSection(),
            ],
          ),
        ),
        bottomSheet: _voiceModeEnabled
            ? QuizVoiceOverlay(
                isListening: _isListening || _isPreparingToListen,
                isPreparingToListen: _isPreparingToListen,
                isSpeaking: _isSpeaking,
                heardText: _heardText,
                onMicTap: _isSpeaking
                    ? _interruptAndListen
                    : (_isListening ? _stopListening : _startListening),
                listeningHint:
                    'Say start quiz, set questions, timed mode on or off, or go back.',
                speakingHint: 'Assistant is speaking.',
                idleHint: 'Tap the mic or say a settings command.',
                instructionItems: const <String>[
                  'start quiz',
                  'set questions',
                  'timed mode on',
                  'timed mode off',
                  'go back',
                ],
              )
            : null,
      );
    });
  }
}

class _SettingsVoiceModeButton extends StatelessWidget {
  final bool isEnabled;
  final bool isListening;
  final bool speechAvailable;
  final VoidCallback onTap;

  const _SettingsVoiceModeButton({
    required this.isEnabled,
    required this.isListening,
    required this.speechAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color iconColor;
    final IconData icon;
    if (!speechAvailable) {
      bg = Colors.transparent;
      iconColor = Colors.grey.shade400;
      icon = Icons.mic_off;
    } else if (isEnabled) {
      bg = isListening ? const Color(0xFFFFE4E4) : const Color(0xFFDCFCE7);
      iconColor = isListening
          ? const Color(0xFFB91C1C)
          : const Color(0xFF166534);
      icon = Icons.mic;
    } else {
      bg = Colors.transparent;
      iconColor = const Color(0xFF274B8A);
      icon = Icons.mic_none;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

class _SettingsListeningOverlay extends StatefulWidget {
  final bool isListening;
  final bool isSpeaking;
  final String heardText;
  final VoidCallback onMicTap;

  const _SettingsListeningOverlay({
    required this.isListening,
    required this.isSpeaking,
    required this.heardText,
    required this.onMicTap,
  });

  @override
  State<_SettingsListeningOverlay> createState() =>
      _SettingsListeningOverlayState();
}

class _SettingsListeningOverlayState extends State<_SettingsListeningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _buildVoiceBars(Color color, {required bool active}) {
    return SizedBox(
      width: 38,
      height: 18,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final double wave = math.sin(
                (_pulse.value * math.pi * 2) + (index * 0.75),
              );
              final double height = active ? 6 + ((wave + 1) * 4.5) : 5;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 5,
                height: height.clamp(5, 15),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: active ? 1 : 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.isListening;
    final speaking = widget.isSpeaking;
    final accentColor = listening
        ? const Color(0xFFEF4444)
        : speaking
        ? const Color(0xFF2D4F88)
        : const Color(0xFF5B6B88);
    final panelGradient = listening
        ? const [Color(0xFFFFF1F2), Color(0xFFFFFFFF), Color(0xFFFFFBFB)]
        : speaking
        ? const [Color(0xFFF3F7FF), Color(0xFFFFFFFF), Color(0xFFF8FBFF)]
        : const [Color(0xFFF8FAFC), Color(0xFFFFFFFF), Color(0xFFF6F8FB)];
    final statusText = listening
        ? 'Listening...'
        : speaking
        ? 'Speaking...'
        : 'Hands-free settings ready';
    final helperText = listening
        ? 'Say set questions, timed mode on or off, start quiz, or go back.'
        : speaking
        ? 'Assistant is reading the settings.'
        : 'Tap mic anytime to interrupt and speak.';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: panelGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.28),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onMicTap,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (listening || speaking)
                      ScaleTransition(
                        scale: _scale,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    _SettingsMicCircle(bg: accentColor),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildVoiceBars(
                          accentColor,
                          active: listening || speaking,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      helperText,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    if (widget.heardText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Heard: "${widget.heardText}"',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const QuizVoiceDebugPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsMicCircle extends StatelessWidget {
  final Color bg;

  const _SettingsMicCircle({required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [bg.withValues(alpha: 0.9), bg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.mic, color: Colors.white, size: 20),
    );
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
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F3A7D), Color(0xFF174A97)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
