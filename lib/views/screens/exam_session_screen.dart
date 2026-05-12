import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../controllers/quiz_voice_controller.dart';
import '../../utils/voice_command_processor.dart';
import '../../utils/quiz_voice_intent_parser.dart';
import '../../utils/voice_listen_start.dart';
import '../../utils/quiz_voice_route_aware.dart';
import '../widgets/api_disclaimer_section.dart';
import '../widgets/quiz_voice_debug_panel.dart';
import '../widgets/quiz_voice_overlay.dart';

class ExamSessionScreen extends StatefulWidget {
  final String courseTitle;
  final String? examId;
  final int? questionCount;
  final int? totalQuestionCount;
  final String? effectivitySheetContent;
  final String? bodyOfKnowledgeContent;
  final bool timedMode;
  final bool voiceModeEnabled;
  final bool voicePracticeMode;

  const ExamSessionScreen({
    super.key,
    required this.courseTitle,
    this.examId,
    this.questionCount,
    this.totalQuestionCount,
    this.effectivitySheetContent,
    this.bodyOfKnowledgeContent,
    this.timedMode = true,
    this.voiceModeEnabled = false,
    this.voicePracticeMode = false,
  });

  @override
  State<ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends State<ExamSessionScreen>
    with QuizVoiceRouteAware<ExamSessionScreen> {
  final SpeechToText _speech = SpeechToText();
  late final FlutterTts _tts;

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
      'examSession-${DateTime.now().microsecondsSinceEpoch}';

  QuizVoiceController get _voiceController =>
      Get.isRegistered<QuizVoiceController>()
      ? Get.find<QuizVoiceController>()
      : Get.put(QuizVoiceController(), permanent: true);

  bool get _autoListenEnabled =>
      _voiceController.assistantSettings.value.autoListenOnScreenOpen;
  bool get _isCurrentVoiceScreen =>
      _voiceController.isCurrentScreenToken(_voiceScreenToken);

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _voiceModeEnabled =
        widget.voicePracticeMode &&
        (widget.voiceModeEnabled || _voiceController.isEnabledValue);
    _configureTts();
    unawaited(_primeSpeechAvailability());
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
      QuizVoiceScreen.examSession,
      screenToken: _voiceScreenToken,
    );
    super.dispose();
  }

  void _activateVoiceScreen() {
    _voiceController.activateScreen(
      QuizVoiceScreen.examSession,
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
      screen: QuizVoiceScreen.examSession,
      screenToken: _voiceScreenToken,
      onRecoverListening: () async {
        await _forceVoiceRecovery();
      },
      onEntryAction: () async {
        if (!mounted || !_voiceModeEnabled) return;
        await _speakSessionSummary();
      },
      requestEntryAction: requestEntryAction && _autoListenEnabled,
    );
    _syncVoiceSessionState();
  }

  Future<void> _forceVoiceRecovery() async {
    if (!mounted || !_isCurrentVoiceScreen || !_voiceModeEnabled) return;
    _voiceController.logEvent(
      'force voice recovery',
      screen: QuizVoiceScreen.examSession,
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
      screen: QuizVoiceScreen.examSession,
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
      screen: QuizVoiceScreen.examSession,
    );
    _voiceController.markHeardText(_heardText);
    if (!_voiceModeEnabled) return;
    final phase = _isSpeaking
        ? QuizVoicePhase.speaking
        : _isListening
        ? QuizVoicePhase.listening
        : QuizVoicePhase.idle;
    _voiceController.setPhase(phase, screen: QuizVoiceScreen.examSession);
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
            screen: QuizVoiceScreen.examSession,
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
            screen: QuizVoiceScreen.examSession,
          );
          _voiceController.onSpeechStatus(
            status,
            screen: QuizVoiceScreen.examSession,
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
      if (_voiceModeEnabled && available) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _voiceModeEnabled && !_isSpeaking) {
            unawaited(_speakSessionSummary());
          }
        });
      }
      return available;
    } catch (error, stackTrace) {
      _voiceController.logEvent(
        'speech initialize failed: $error\n$stackTrace',
        screen: QuizVoiceScreen.examSession,
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
        screen: QuizVoiceScreen.examSession,
        requestEntryAction: true,
      );
      await _speakSessionSummary();
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
      screen: QuizVoiceScreen.examSession,
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

  Future<void> _speakSessionSummary({bool force = false}) async {
    final timedText = widget.timedMode
        ? 'Timed mode is on.'
        : 'Timed mode is off.';
    final text =
        'Exam session. ${widget.questionCount ?? 1} questions selected. $timedText '
        'Say start test to continue, say back to return to settings, or say help.';
    final examKey = widget.examId?.trim().isNotEmpty == true
        ? widget.examId!.trim()
        : widget.courseTitle;
    final shouldSpeak = _voiceController.speakOnce(
      key: 'session_$examKey',
      text: text,
      force: force,
      screen: QuizVoiceScreen.examSession,
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
      screen: QuizVoiceScreen.examSession,
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
      screen: QuizVoiceScreen.examSession,
    );
    final started = await startSpeechListeningSafely(
      speech: _speech,
      controller: _voiceController,
      screen: QuizVoiceScreen.examSession,
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
        screen: QuizVoiceScreen.examSession,
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
      screen: QuizVoiceScreen.examSession,
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
    await Future.delayed(const Duration(milliseconds: 250));
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
      screen: QuizVoiceScreen.examSession,
    );
    if (result.finalResult) {
      setState(() {
        _isListening = false;
        _isPreparingToListen = false;
      });
      _voiceController.setPhase(
        QuizVoicePhase.processing,
        screen: QuizVoiceScreen.examSession,
      );
      final text = result.recognizedWords.trim();
      if (text.isNotEmpty) {
        unawaited(_handleVoiceCommand(text));
      }
    }
  }

  Future<void> _handleVoiceCommand(String rawText) async {
    final decision = await _voiceCommandProcessor.process(
      screen: QuizVoiceScreen.examSession,
      heardText: rawText,
      sensitivity: _voiceController.assistantSettings.value.commandSensitivity,
    );
    final result = decision.parseResult;
    _voiceController.logEvent(
      'parsed intent: ${result.intent?.name ?? 'none'}'
      ' confidence: ${result.confidence.toStringAsFixed(2)}',
      screen: QuizVoiceScreen.examSession,
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
        unawaited(_speakSessionSummary(force: true));
        return;
      case VoiceIntent.startTest:
      case VoiceIntent.startQuiz:
        _startQuiz();
        return;
      case VoiceIntent.back:
        _goBack();
        return;
      default:
        break;
    }

    final heard = rawText.trim().isNotEmpty ? 'I heard "$rawText". ' : '';
    unawaited(_speakFeedback('${heard}Try start test, go back, or help.'));
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

  void _startQuiz() {
    final id = widget.examId?.trim();
    if (id == null || id.isEmpty) {
      unawaited(
        _speakFeedback('Exam ID is missing. Please go back and try again.'),
      );
      return;
    }

    unawaited(_tts.stop());
    unawaited(_speech.cancel());
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isListening = false;
      });
    }
    _voiceController.beginNavigation(targetScreen: QuizVoiceScreen.examLoading);
    context.push(
      '/exam-loading',
      extra: {
        'courseTitle': widget.courseTitle,
        'examId': id,
        'questionCount': widget.questionCount ?? 1,
        'totalQuestionCount':
            widget.totalQuestionCount ?? widget.questionCount ?? 1,
        'timedMode': widget.timedMode,
        'voiceModeEnabled': _voiceModeEnabled,
        'voicePracticeMode': widget.voicePracticeMode,
      },
    );
  }

  void _goBack() {
    unawaited(_tts.stop());
    unawaited(_speech.cancel());
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isListening = false;
      });
    }
    _voiceController.beginNavigation(
      targetScreen: QuizVoiceScreen.quizSettings,
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
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
                if (widget.voicePracticeMode)
                  _SessionVoiceModeButton(
                    isEnabled: _voiceModeEnabled,
                    isListening: _isListening || _isPreparingToListen,
                    speechAvailable: _speechAvailable,
                    onTap: _toggleVoiceMode,
                  ),
              ],
            ),
            const SizedBox(height: 26),
            const Text(
              'Select Your Exam Session',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                text: 'You are about to start a quiz for the ',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B5563),
                ),
                children: [
                  TextSpan(
                    text: widget.courseTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2F6DE0),
                    ),
                  ),
                  const TextSpan(text: ' certification'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SessionCard(
              title: 'Start Manual Practice',
              description:
                  'Begin manual practice with full question interaction.',
              isPrimary: true,
              onTap: _startQuiz,
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _InfoTile(
                      title: 'Questions',
                      value: '${widget.questionCount ?? 1}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoTile(
                      title: 'Mode',
                      value: widget.timedMode ? 'Timed' : 'Practice',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: _goBack,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2D4F88), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.arrow_back, color: Color(0xFF2D4F88)),
              label: const Text(
                'Back to the Exam selection',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D4F88),
                ),
              ),
            ),
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
              listeningHint: 'Say start test, go back, or help.',
              speakingHint: 'Assistant is speaking.',
              idleHint: 'Tap the mic or say a session command.',
              instructionItems: const <String>['start test', 'go back', 'help'],
            )
          : null,
    );
  }
}

class _SessionCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isPrimary;
  final VoidCallback onTap;

  const _SessionCard({
    required this.title,
    required this.description,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isPrimary ? const Color(0xFF274B8A) : Colors.white;
    final Color borderColor = isPrimary
        ? const Color(0xFF1E3C73)
        : const Color(0xFFE5E7EB);
    final Color titleColor = isPrimary ? Colors.white : const Color(0xFF111827);
    final Color bodyColor = isPrimary
        ? Colors.white70
        : const Color(0xFF4B5563);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: bodyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E0F5), width: 1.1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3C73),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionVoiceModeButton extends StatelessWidget {
  final bool isEnabled;
  final bool isListening;
  final bool speechAvailable;
  final VoidCallback onTap;

  const _SessionVoiceModeButton({
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

class _SessionListeningOverlay extends StatefulWidget {
  final bool isListening;
  final bool isSpeaking;
  final String heardText;
  final VoidCallback onMicTap;

  const _SessionListeningOverlay({
    required this.isListening,
    required this.isSpeaking,
    required this.heardText,
    required this.onMicTap,
  });

  @override
  State<_SessionListeningOverlay> createState() =>
      _SessionListeningOverlayState();
}

class _SessionListeningOverlayState extends State<_SessionListeningOverlay>
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
        : 'Hands-free session ready';
    final helperText = listening
        ? 'Say start test, go back, or help.'
        : speaking
        ? 'Assistant is reading the session step.'
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
                    _SessionMicCircle(bg: accentColor),
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

class _SessionMicCircle extends StatelessWidget {
  final Color bg;

  const _SessionMicCircle({required this.bg});

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
