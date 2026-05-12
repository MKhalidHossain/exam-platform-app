import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart' hide ErrorHandler;
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/error/error_handler.dart';
import '../../controllers/quiz_voice_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/plan_tier.dart';
import '../../services/exam_service.dart';
import '../../utils/voice_command_processor.dart';
import '../../utils/quiz_voice_intent_parser.dart';
import '../../utils/voice_listen_start.dart';
import '../../utils/quiz_voice_route_aware.dart';
import '../widgets/quiz_voice_debug_panel.dart';
import '../widgets/quiz_voice_overlay.dart';

class ExamLoadingScreen extends StatefulWidget {
  final String courseTitle;
  final String? examId;
  final int? questionCount;
  final int? totalQuestionCount;
  final bool timedMode;
  final bool regenerate;
  final bool voiceModeEnabled;
  final bool voicePracticeMode;

  const ExamLoadingScreen({
    super.key,
    required this.courseTitle,
    this.examId,
    this.questionCount,
    this.totalQuestionCount,
    this.timedMode = true,
    this.regenerate = false,
    this.voiceModeEnabled = false,
    this.voicePracticeMode = false,
  });

  @override
  State<ExamLoadingScreen> createState() => _ExamLoadingScreenState();
}

class _ExamLoadingScreenState extends State<ExamLoadingScreen>
    with QuizVoiceRouteAware<ExamLoadingScreen> {
  final ExamService _examService = ExamService();
  final SpeechToText _speech = SpeechToText();
  late final FlutterTts _tts;
  bool _isLoading = true;
  String? _errorMessage;
  bool _voiceModeEnabled = false;
  bool _speechAvailable = false;
  bool _speechInitializing = false;
  bool _isListening = false;
  bool _isPreparingToListen = false;
  bool _isSpeaking = false;
  bool _cancelRequested = false;
  Timer? _listeningRestartTimer;
  String? _speechLocaleId;
  String _heardText = '';
  final VoiceCommandProcessor _voiceCommandProcessor = VoiceCommandProcessor();
  final String _voiceScreenToken =
      'examLoading-${DateTime.now().microsecondsSinceEpoch}';

  QuizVoiceController get _voiceController =>
      Get.isRegistered<QuizVoiceController>()
      ? Get.find<QuizVoiceController>()
      : Get.put(QuizVoiceController(), permanent: true);

  bool get _autoListenEnabled =>
      _voiceController.assistantSettings.value.autoListenOnScreenOpen;
  bool get _isCurrentVoiceScreen =>
      _voiceController.isCurrentScreenToken(_voiceScreenToken);

  UserController get _userController => Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  bool _isLimitMessage(String? message) {
    if (message == null) return false;
    final lowered = message.toLowerCase();
    return lowered.contains('monthly free questions limit') ||
        lowered.contains('monthly free question limit') ||
        lowered.contains('free questions limit') ||
        lowered.contains('monthly limit') ||
        lowered.contains('purchase to unlock');
  }

  bool _isTimeoutMessage(String? message) {
    if (message == null) return false;
    final lowered = message.toLowerCase();
    return lowered.contains('timeout') || lowered.contains('took too long');
  }

  bool _isQuestionServiceError(String? message) {
    if (message == null) return false;
    final lowered = message.toLowerCase();
    return lowered.contains('question service') ||
        lowered.contains('question generation') ||
        lowered.contains('temporarily unavailable');
  }

  bool _shouldKeepWaiting({
    required int? statusCode,
    required String? message,
  }) {
    if (statusCode == 502 || statusCode == 504 || statusCode == 408) {
      return true;
    }
    return _isTimeoutMessage(message) || _isQuestionServiceError(message);
  }

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _voiceModeEnabled =
        widget.voicePracticeMode &&
        (widget.voiceModeEnabled || _voiceController.isEnabledValue);
    _configureTts();
    unawaited(_primeSpeechAvailability());
    _startExam();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _activateVoiceScreen();
        _bindVoiceSession(requestEntryAction: widget.voicePracticeMode);
      }
    });
  }

  @override
  void dispose() {
    _listeningRestartTimer?.cancel();
    unawaited(_tts.stop());
    unawaited(_speech.cancel());
    _voiceController.unbindScreen(
      QuizVoiceScreen.examLoading,
      screenToken: _voiceScreenToken,
    );
    super.dispose();
  }

  void _activateVoiceScreen() {
    _voiceController.activateScreen(
      QuizVoiceScreen.examLoading,
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

  static const Duration _retryDelayWhileGenerating = Duration(seconds: 12);

  void _bindVoiceSession({bool requestEntryAction = false}) {
    _voiceController.bindScreen(
      screen: QuizVoiceScreen.examLoading,
      screenToken: _voiceScreenToken,
      onRecoverListening: () async {
        await _forceVoiceRecovery();
      },
      onEntryAction: () async {
        if (!mounted || !_voiceModeEnabled) return;
        await _speakCurrentStatus();
      },
      requestEntryAction: requestEntryAction && _autoListenEnabled,
    );
    _syncVoiceSessionState();
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

  void _syncVoiceSessionState() {
    _voiceController.setVoiceEnabled(
      _voiceModeEnabled,
      screen: QuizVoiceScreen.examLoading,
    );
    _voiceController.markHeardText(_heardText);
    if (!_voiceModeEnabled) return;
    final QuizVoicePhase phase = _isSpeaking
        ? QuizVoicePhase.speaking
        : _isListening
        ? QuizVoicePhase.listening
        : _isLoading
        ? QuizVoicePhase.navigating
        : QuizVoicePhase.idle;
    _voiceController.setPhase(phase, screen: QuizVoiceScreen.examLoading);
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
            screen: QuizVoiceScreen.examLoading,
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
            screen: QuizVoiceScreen.examLoading,
          );
          _voiceController.onSpeechStatus(
            status,
            screen: QuizVoiceScreen.examLoading,
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
        screen: QuizVoiceScreen.examLoading,
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

  Future<void> _forceVoiceRecovery() async {
    if (!mounted || !_isCurrentVoiceScreen || !_voiceModeEnabled) return;
    _voiceController.logEvent(
      'force voice recovery',
      screen: QuizVoiceScreen.examLoading,
    );
    _listeningRestartTimer?.cancel();
    await _tts.stop();
    await _speech.cancel();
    if (!mounted || !_isCurrentVoiceScreen || !_voiceModeEnabled) return;
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _isPreparingToListen = false;
      _heardText = '';
    });
    _voiceController.setVoiceState(
      VoiceState.idle,
      screen: QuizVoiceScreen.examLoading,
    );
    _syncVoiceSessionState();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted ||
        !_isCurrentVoiceScreen ||
        !_voiceModeEnabled ||
        _isSpeaking) {
      return;
    }
    await _startListening();
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
    _bindVoiceSession();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted && _voiceModeEnabled) {
      _voiceController.setVoiceEnabled(
        true,
        screen: QuizVoiceScreen.examLoading,
        requestEntryAction: true,
      );
      await _speakCurrentStatus();
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
      screen: QuizVoiceScreen.examLoading,
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

  Future<void> _speakCurrentStatus() async {
    if (_isLoading) {
      await _speakFeedback(
        'Generating ${widget.questionCount ?? 1} questions for ${widget.courseTitle}. '
        'Please wait. Say status, cancel, retry, or stop voice mode.',
      );
      return;
    }
    await _speakFeedback(
      '${_errorMessage ?? 'Generation stopped.'} '
      'Say retry to try again, back to return, or stop voice mode.',
    );
  }

  void _scheduleListeningRestart([
    Duration delay = const Duration(milliseconds: 700),
  ]) {
    _listeningRestartTimer?.cancel();
    if (!_voiceModeEnabled || !_autoListenEnabled) return;
    final retryDelay = enforceMinimumVoiceListenRetryDelay(delay);
    if (mounted && !_isListening && !_isSpeaking && !_isPreparingToListen) {
      setState(() => _isPreparingToListen = true);
    }
    _listeningRestartTimer = Timer(retryDelay, () {
      if (!mounted ||
          !_isCurrentVoiceScreen ||
          !_voiceModeEnabled ||
          _isListening ||
          _isSpeaking) {
        return;
      }
      unawaited(_startListening());
    });
  }

  Future<void> _startListening() async {
    if (!_isCurrentVoiceScreen) return;
    _voiceController.logEvent(
      'start listening requested',
      screen: QuizVoiceScreen.examLoading,
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
      screen: QuizVoiceScreen.examLoading,
    );
    final started = await startSpeechListeningSafely(
      speech: _speech,
      controller: _voiceController,
      screen: QuizVoiceScreen.examLoading,
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
        screen: QuizVoiceScreen.examLoading,
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
      screen: QuizVoiceScreen.examLoading,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted || !_isCurrentVoiceScreen) return;
    setState(() {
      _isListening = false;
      _isPreparingToListen = false;
    });
    _syncVoiceSessionState();
  }

  Future<void> _interruptAndListen() async {
    await _tts.stop();
    if (!mounted || !_isCurrentVoiceScreen) return;
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _isPreparingToListen = false;
    });
    _syncVoiceSessionState();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted && _isCurrentVoiceScreen) {
      unawaited(_startListening());
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted || !_isCurrentVoiceScreen) return;
    setState(() => _heardText = result.recognizedWords);
    _voiceController.markHeardText(_heardText);
    _voiceController.logTranscript(
      result.recognizedWords,
      isFinal: result.finalResult,
      screen: QuizVoiceScreen.examLoading,
    );
    if (result.finalResult) {
      setState(() {
        _isListening = false;
        _isPreparingToListen = false;
      });
      _voiceController.setPhase(
        QuizVoicePhase.processing,
        screen: QuizVoiceScreen.examLoading,
      );
      final text = result.recognizedWords.trim();
      if (text.isNotEmpty) {
        unawaited(_handleVoiceCommand(text));
      }
    }
  }

  Future<void> _handleVoiceCommand(String rawText) async {
    final decision = await _voiceCommandProcessor.process(
      screen: QuizVoiceScreen.examLoading,
      heardText: rawText,
      sensitivity: _voiceController.assistantSettings.value.commandSensitivity,
    );
    final result = decision.parseResult;
    _voiceController.logEvent(
      'parsed intent: ${result.intent?.name ?? 'none'}'
      ' confidence: ${result.confidence.toStringAsFixed(2)}',
      screen: QuizVoiceScreen.examLoading,
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
        unawaited(_disableVoiceModeWithFeedback('Voice mode turned off.'));
        return;
      case VoiceIntent.help:
      case VoiceIntent.status:
        unawaited(_speakCurrentStatus());
        return;
      case VoiceIntent.retry:
        _retryLoading();
        return;
      case VoiceIntent.cancel:
      case VoiceIntent.back:
        _cancelAndReturn();
        return;
      default:
        break;
    }

    unawaited(
      _speakFeedback('Try status, retry, cancel, back, or stop voice mode.'),
    );
  }

  void _handleLimitRedirect() {
    final isPro = _userController.planTier.value == PlanTier.professional;
    _voiceController.setVoiceEnabled(
      false,
      screen: QuizVoiceScreen.examLoading,
    );
    context.go(isPro ? '/home' : '/subscribe');
  }

  Future<void> _startExam() async {
    _cancelRequested = false;
    final examId = widget.examId?.trim();
    if (examId == null || examId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Exam ID missing. Please go back and try again.';
      });
      _syncVoiceSessionState();
      return;
    }

    final int questionCount = widget.questionCount ?? 1;
    final bool isPro = _userController.planTier.value == PlanTier.professional;
    final bool effectiveTimedMode = widget.timedMode && isPro;
    _voiceController.logEvent(
      'start exam request loop',
      screen: QuizVoiceScreen.examLoading,
    );
    _syncVoiceSessionState();

    while (mounted && !_cancelRequested) {
      final response = await _examService.startExam(
        examId: examId,
        questionCount: questionCount,
        regenerate: widget.regenerate,
      );

      if (!mounted || _cancelRequested) return;

      if (response.statusCode == 403) {
        _handleLimitRedirect();
        return;
      }

      if (response.success && response.data != null) {
        DateTime? startTime;
        DateTime? endTime;
        int? durationMinutes;
        if (effectiveTimedMode) {
          durationMinutes = response.data!.durationMinutes;
          startTime = DateTime.now();
          if (durationMinutes != null && durationMinutes > 0) {
            endTime = startTime.add(Duration(minutes: durationMinutes));
          }
        }
        final int sessionId = DateTime.now().millisecondsSinceEpoch;
        _voiceController.beginNavigation(targetScreen: QuizVoiceScreen.mcq);
        context.go(
          '/mcq',
          extra: {
            'courseTitle': widget.courseTitle,
            'examId': examId,
            'questions': response.data!.questions,
            'totalQuestionCount': widget.totalQuestionCount ?? questionCount,
            'startTime': startTime,
            'endTime': endTime,
            'durationMinutes': durationMinutes,
            'timedMode': effectiveTimedMode,
            'sessionId': sessionId,
            'voiceModeEnabled': widget.voiceModeEnabled,
            'voicePracticeMode': widget.voicePracticeMode,
          },
        );
        return;
      }

      final failureMessage = ErrorHandler.getMessageFromResponse(
        response,
        failureFallback: 'Failed to start the exam. Please try again.',
      );
      if (_shouldKeepWaiting(
        statusCode: response.statusCode,
        message: failureMessage,
      )) {
        _voiceController.logEvent(
          'generation still pending, retrying after wait',
          screen: QuizVoiceScreen.examLoading,
        );
        await Future<void>.delayed(_retryDelayWhileGenerating);
        continue;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = failureMessage;
      });
      _syncVoiceSessionState();
      if (_voiceModeEnabled) {
        unawaited(_speakCurrentStatus());
      }
      return;
    }
  }

  void _retryLoading() {
    _voiceController.logEvent(
      'retry loading requested',
      screen: QuizVoiceScreen.examLoading,
    );
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _heardText = '';
      _isSpeaking = false;
      _isListening = false;
    });
    _syncVoiceSessionState();
    unawaited(_startExam());
  }

  Future<void> _disableVoiceModeWithFeedback(String message) async {
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

  void _cancelAndReturn() {
    _cancelRequested = true;
    unawaited(_tts.stop());
    unawaited(_speech.cancel());
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isListening = false;
      });
    }
    _voiceController.beginNavigation(targetScreen: QuizVoiceScreen.examSession);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            _voiceModeEnabled ? 170 : 24,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _cancelAndReturn,
                    icon: const Icon(Icons.arrow_back, size: 22),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Generating Exam',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D4F88),
                      ),
                    ),
                  ),
                  if (widget.voicePracticeMode)
                    _LoadingVoiceModeButton(
                      isEnabled: _voiceModeEnabled,
                      isListening: _isListening || _isPreparingToListen,
                      speechAvailable: _speechAvailable,
                      onTap: _toggleVoiceMode,
                    ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        if (_isLoading) ...[
                          SizedBox(
                            width: 250,
                            height: 240,
                            child: Lottie.asset(
                              'assets/lottie/loading_run.json',
                              fit: BoxFit.contain,
                              repeat: true,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Generating ${widget.questionCount ?? 1} questions for your ${widget.courseTitle} exam... This may take a minute.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                              height: 1.35,
                            ),
                          ),
                        ] else ...[
                          if (_isQuestionServiceError(_errorMessage) ||
                              _isTimeoutMessage(_errorMessage)) ...[
                            SizedBox(
                              width: 220,
                              height: 120,
                              child: Lottie.asset(
                                'assets/lottie/timeout.json',
                                fit: BoxFit.contain,
                                repeat: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Timeout. ',
                                    style: TextStyle(color: Color(0xFFE24B4B)),
                                  ),
                                  const TextSpan(
                                    text: 'Try again',
                                    style: TextStyle(color: Color(0xFF1E4C9A)),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 18),
                          ] else ...[
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Color(0xFFE24B4B),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage ?? 'Something went wrong.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          ElevatedButton(
                            onPressed: () {
                              if (_isLimitMessage(_errorMessage)) {
                                _handleLimitRedirect();
                                return;
                              }
                              _retryLoading();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E4C9A),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'Try Again',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: widget.voicePracticeMode && _voiceModeEnabled
          ? QuizVoiceOverlay(
              isListening: _isListening || _isPreparingToListen,
              isPreparingToListen: _isPreparingToListen,
              isSpeaking: _isSpeaking,
              heardText: _heardText,
              onMicTap: _isSpeaking
                  ? _interruptAndListen
                  : (_isListening ? _stopListening : _startListening),
              listeningHint:
                  'Say status, retry, cancel, back, or stop voice mode.',
              speakingHint: 'Assistant is speaking.',
              idleHint: 'Tap the mic or say a loading command.',
              instructionItems: const <String>[
                'status',
                'retry',
                'cancel',
                'back',
                'stop voice mode',
              ],
            )
          : null,
    );
  }
}

class _LoadingVoiceModeButton extends StatelessWidget {
  final bool isEnabled;
  final bool isListening;
  final bool speechAvailable;
  final VoidCallback onTap;

  const _LoadingVoiceModeButton({
    required this.isEnabled,
    required this.isListening,
    required this.speechAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isEnabled
        ? (isListening ? const Color(0xFFFFE2E5) : const Color(0xFFEAF1FF))
        : const Color(0xFFF3F4F6);
    final Color iconColor = isEnabled
        ? (isListening ? const Color(0xFFE24B4B) : const Color(0xFF2D4F88))
        : const Color(0xFF6B7280);
    final String tooltip = isEnabled
        ? 'Tap to turn off voice mode'
        : speechAvailable
        ? 'Tap to turn on voice mode'
        : 'Microphone permission required';

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: iconColor.withValues(alpha: 0.18)),
          ),
          child: Icon(Icons.mic_rounded, color: iconColor, size: 20),
        ),
      ),
    );
  }
}

class _LoadingListeningOverlay extends StatefulWidget {
  final bool isListening;
  final bool isSpeaking;
  final String heardText;
  final VoidCallback onMicTap;

  const _LoadingListeningOverlay({
    required this.isListening,
    required this.isSpeaking,
    required this.heardText,
    required this.onMicTap,
  });

  @override
  State<_LoadingListeningOverlay> createState() =>
      _LoadingListeningOverlayState();
}

class _LoadingListeningOverlayState extends State<_LoadingListeningOverlay>
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
    final bool listening = widget.isListening;
    final bool speaking = widget.isSpeaking;
    final Color accentColor = listening
        ? const Color(0xFFEF4444)
        : speaking
        ? const Color(0xFF2D4F88)
        : const Color(0xFF5B6B88);
    final List<Color> panelGradient = listening
        ? const [Color(0xFFFFF1F2), Color(0xFFFFFFFF), Color(0xFFFFFBFB)]
        : speaking
        ? const [Color(0xFFF3F7FF), Color(0xFFFFFFFF), Color(0xFFF8FBFF)]
        : const [Color(0xFFF8FAFC), Color(0xFFFFFFFF), Color(0xFFF6F8FB)];
    final String statusText = listening
        ? 'Listening...'
        : speaking
        ? 'Speaking...'
        : 'Hands-free loading ready';
    final String helperText = listening
        ? 'Say status, retry, cancel, back, or stop voice mode.'
        : speaking
        ? 'Assistant is reading the loading status.'
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
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.9),
                            accentColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
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
