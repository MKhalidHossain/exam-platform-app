import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart' hide ErrorHandler;
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/error/error_handler.dart';
import '../../controllers/quiz_voice_controller.dart';
import '../../services/exam_service.dart';
import '../../controllers/history_controller.dart';
import '../../models/history_attempt_model.dart';
import '../../utils/quiz_voice_intent_parser.dart';
import '../../utils/quiz_voice_route_aware.dart';
import 'history_models.dart';
import '../widgets/api_disclaimer_section.dart';
import '../widgets/quiz_voice_debug_panel.dart';
import '../widgets/quiz_voice_overlay.dart';

class ExamReviewScreen extends StatefulWidget {
  final String courseTitle;
  final List<dynamic> questions;
  final Map<int, int> selected;
  final Set<int> flagged;
  final String? examId;
  final List<int>? timeSpentSec;
  final bool autoSubmit;
  final bool voiceModeEnabled;
  final int returnQuestionIndex;

  const ExamReviewScreen({
    super.key,
    required this.courseTitle,
    required this.questions,
    required this.selected,
    required this.flagged,
    this.examId,
    this.timeSpentSec,
    this.autoSubmit = false,
    this.voiceModeEnabled = false,
    this.returnQuestionIndex = 0,
  });

  @override
  State<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends State<ExamReviewScreen>
    with QuizVoiceRouteAware<ExamReviewScreen> {
  final ExamService _examService = ExamService();
  final SpeechToText _speech = SpeechToText();
  late final FlutterTts _tts;
  bool _isSubmitting = false;
  bool _voiceModeEnabled = false;
  bool _speechAvailable = false;
  bool _speechInitializing = false;
  bool _isListening = false;
  bool _isPreparingToListen = false;
  bool _isSpeaking = false;
  bool _awaitingSubmitConfirmation = false;
  Timer? _listeningRestartTimer;
  Timer? _submitConfirmationTimer;
  String? _speechLocaleId;
  String _heardText = '';

  QuizVoiceController get _voiceController =>
      Get.isRegistered<QuizVoiceController>()
      ? Get.find<QuizVoiceController>()
      : Get.put(QuizVoiceController(), permanent: true);

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _voiceModeEnabled =
        widget.voiceModeEnabled || _voiceController.isEnabledValue;
    _configureTts();
    unawaited(_primeSpeechAvailability());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.autoSubmit) {
        _bindVoiceSession(requestEntryAction: false);
      }
    });
    if (widget.autoSubmit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_submitFinalAnswers());
        }
      });
    }
  }

  @override
  void dispose() {
    _listeningRestartTimer?.cancel();
    _submitConfirmationTimer?.cancel();
    unawaited(_tts.stop());
    unawaited(_speech.cancel());
    _voiceController.unbindScreen(QuizVoiceScreen.examReview);
    super.dispose();
  }

  List<int> get _answeredIndexes => List<int>.generate(
    widget.questions.length,
    (i) => i,
  ).where((i) => widget.selected[i] != null).toList();

  List<int> get _unansweredIndexes => List<int>.generate(
    widget.questions.length,
    (i) => i,
  ).where((i) => widget.selected[i] == null).toList();

  List<int> get _flaggedIndexes => List<int>.generate(
    widget.questions.length,
    (i) => i,
  ).where((i) => widget.flagged.contains(i)).toList();

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      _syncVoiceSessionState();
      if (_voiceModeEnabled && !_isSubmitting && !_isListening) {
        _scheduleListeningRestart(const Duration(milliseconds: 400));
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
      screen: QuizVoiceScreen.examReview,
      onRecoverListening: () async {
        await _forceVoiceRecovery();
      },
      onEntryAction: () async {
        if (!mounted ||
            !_voiceModeEnabled ||
            _isSubmitting ||
            widget.autoSubmit) {
          return;
        }
        await _speakReviewSummary();
      },
      requestEntryAction: requestEntryAction,
    );
    _syncVoiceSessionState();
  }

  Future<void> _forceVoiceRecovery() async {
    if (!mounted || !_voiceModeEnabled || _isSubmitting || widget.autoSubmit) {
      return;
    }
    _voiceController.logEvent(
      'force voice recovery',
      screen: QuizVoiceScreen.examReview,
    );
    _listeningRestartTimer?.cancel();
    _submitConfirmationTimer?.cancel();
    await _tts.stop();
    await _speech.cancel();
    if (!mounted || !_voiceModeEnabled || _isSubmitting || widget.autoSubmit) {
      return;
    }
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _heardText = '';
      _awaitingSubmitConfirmation = false;
    });
    _syncVoiceSessionState();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted || !_voiceModeEnabled || _isSubmitting || widget.autoSubmit) {
      return;
    }
    await _startListening();
  }

  @override
  void onVoiceRouteActive() {
    if (!mounted || widget.autoSubmit) return;
    _bindVoiceSession(requestEntryAction: false);
  }

  @override
  void onVoiceRouteInactive() {
    if (!_voiceModeEnabled || widget.autoSubmit) return;
    _voiceController.beginNavigation();
  }

  void _syncVoiceSessionState() {
    _voiceController.setVoiceEnabled(
      _voiceModeEnabled,
      screen: QuizVoiceScreen.examReview,
    );
    _voiceController.markHeardText(_heardText);
    if (!_voiceModeEnabled) return;
    final phase = _isSubmitting
        ? QuizVoicePhase.submitting
        : _isSpeaking
        ? QuizVoicePhase.speaking
        : _isListening
        ? QuizVoicePhase.listening
        : QuizVoicePhase.idle;
    _voiceController.setPhase(phase, screen: QuizVoiceScreen.examReview);
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
            screen: QuizVoiceScreen.examReview,
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
            screen: QuizVoiceScreen.examReview,
          );
          if (status == 'listening' &&
              (!_isListening || _isPreparingToListen)) {
            setState(() {
              _isListening = true;
              _isPreparingToListen = false;
            });
            _syncVoiceSessionState();
          }
          if ((status == 'done' || status == 'notListening') &&
              (_isListening || _isPreparingToListen)) {
            setState(() {
              _isListening = false;
              _isPreparingToListen = false;
            });
            _syncVoiceSessionState();
          }
          if (status == 'done' || status == 'notListening') {
            _scheduleListeningRestart();
          }
        },
        options: [SpeechToText.androidNoBluetooth],
      );
      String? preferredLocaleId;
      if (available) {
        preferredLocaleId = await _resolvePreferredSpeechLocaleId();
      }
      if (!mounted) return available;
      setState(() {
        _speechAvailable = available;
        _speechLocaleId = preferredLocaleId;
      });
      if (_voiceModeEnabled && available && !widget.autoSubmit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _voiceModeEnabled && !_isSubmitting) {
            unawaited(_speakReviewSummary());
          }
        });
      }
      return available;
    } catch (_) {
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

  Future<void> _showSpeechUnavailableMessage() async {
    final hasPermission = await _speech.hasPermission;
    if (!mounted) return;
    final message = hasPermission
        ? 'Speech recognition is not available on this device right now.'
        : 'Microphone permission is required for voice mode. If you denied it before, enable Microphone for this app in Android settings and try again.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _scheduleListeningRestart([
    Duration delay = const Duration(milliseconds: 700),
  ]) {
    _listeningRestartTimer?.cancel();
    if (!_voiceModeEnabled) return;
    if (mounted &&
        !_isListening &&
        !_isSpeaking &&
        !_isSubmitting &&
        !_isPreparingToListen) {
      setState(() => _isPreparingToListen = true);
    }
    _listeningRestartTimer = Timer(delay, () {
      if (!mounted ||
          !_voiceModeEnabled ||
          _isListening ||
          _isSpeaking ||
          _isSubmitting) {
        return;
      }
      unawaited(_startListening());
    });
  }

  Future<String?> _resolvePreferredSpeechLocaleId() async {
    try {
      final systemLocale = await _speech.systemLocale();
      final locales = await _speech.locales();
      final localeIds = locales.map((locale) => locale.localeId).toSet();

      final String? systemLocaleId = systemLocale?.localeId;
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

  String _buildReviewSummary() {
    final total = widget.questions.length;
    final answered = _answeredIndexes.length;
    final unanswered = _unansweredIndexes.length;
    final flagged = _flaggedIndexes.length;
    final buffer = StringBuffer();
    buffer.write('Exam review. ');
    buffer.write('You answered $answered out of $total questions. ');
    if (flagged > 0) {
      buffer.write(
        '$flagged question${flagged == 1 ? '' : 's'} flagged for review. ',
      );
    }
    if (unanswered > 0) {
      buffer.write(
        '$unanswered question${unanswered == 1 ? '' : 's'} unanswered. ',
      );
      buffer.write(
        'Say question ${_unansweredIndexes.first + 1} to return to an unanswered question, '
        'or say submit to begin final confirmation. ',
      );
    } else {
      buffer.write('All questions are covered. ');
      buffer.write(
        'Say submit to begin final confirmation, or say question number to go back. ',
      );
    }
    buffer.write('Say help to hear all review commands.');
    return buffer.toString();
  }

  Future<void> _speakReviewSummary() async {
    await _speakFeedback(_buildReviewSummary());
  }

  Future<void> _speakFeedback(String text) async {
    _voiceController.logEvent(
      'speak feedback requested',
      screen: QuizVoiceScreen.examReview,
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
        screen: QuizVoiceScreen.examReview,
        requestEntryAction: true,
      );
      await _speakReviewSummary();
    }
  }

  Future<void> _startListening() async {
    _voiceController.logEvent(
      'start listening requested',
      screen: QuizVoiceScreen.examReview,
    );
    _listeningRestartTimer?.cancel();
    if (_isListening || _isSpeaking || _isSubmitting) {
      return;
    }
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
      screen: QuizVoiceScreen.examReview,
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
        screen: QuizVoiceScreen.examReview,
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
        screen: QuizVoiceScreen.examReview,
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
      screen: QuizVoiceScreen.examReview,
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
    if (mounted) unawaited(_startListening());
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() => _heardText = result.recognizedWords);
    _voiceController.markHeardText(_heardText);
    _voiceController.logTranscript(
      result.recognizedWords,
      isFinal: result.finalResult,
      screen: QuizVoiceScreen.examReview,
    );
    if (result.finalResult) {
      setState(() {
        _isListening = false;
        _isPreparingToListen = false;
      });
      _voiceController.setPhase(
        QuizVoicePhase.processing,
        screen: QuizVoiceScreen.examReview,
      );
      final text = result.recognizedWords.trim();
      if (text.isNotEmpty) {
        _handleVoiceCommand(text);
      }
    }
  }

  void _handleVoiceCommand(String rawText) {
    final result = QuizVoiceIntentParser.parse(
      QuizVoiceScreen.examReview,
      rawText,
    );
    _voiceController.logEvent(
      'parsed intent: ${result.intent.name}'
      '${result.numberValue != null ? ' (${result.numberValue})' : ''}',
      screen: QuizVoiceScreen.examReview,
    );

    switch (result.intent) {
      case QuizVoiceIntent.stopVoiceMode:
        unawaited(_disableVoiceModeWithFeedback('Voice mode turned off.'));
        return;
      case QuizVoiceIntent.questionNumber:
        if (result.numberValue != null) {
          _goToQuestionViaVoice(result.numberValue! - 1);
          return;
        }
        break;
      case QuizVoiceIntent.confirmSubmit:
        _confirmSubmitViaVoice();
        return;
      case QuizVoiceIntent.submit:
        _submitViaVoice();
        return;
      case QuizVoiceIntent.goBack:
        _returnToQuestionViaVoice();
        return;
      case QuizVoiceIntent.unanswered:
        _jumpToBucketViaVoice(
          _unansweredIndexes,
          'There are no unanswered questions.',
        );
        return;
      case QuizVoiceIntent.flagged:
        _jumpToBucketViaVoice(
          _flaggedIndexes,
          'There are no flagged questions.',
        );
        return;
      case QuizVoiceIntent.readSummary:
        unawaited(_speakReviewSummary());
        return;
      case QuizVoiceIntent.help:
        unawaited(
          _speakFeedback(
            'Review commands. '
            'Say submit, then say confirm submit, to finish the exam. '
            'Say question 5 to return to that question. '
            'Say unanswered to jump to the first unanswered question. '
            'Say flagged to jump to the first flagged question. '
            'Say back to return to the exam. '
            'Say read to hear this summary again. '
            'Say stop voice mode to turn off hands free mode.',
          ),
        );
        return;
      case QuizVoiceIntent.unknown:
      case QuizVoiceIntent.startQuiz:
      case QuizVoiceIntent.nextQuestion:
      case QuizVoiceIntent.timedModeOn:
      case QuizVoiceIntent.timedModeOff:
      case QuizVoiceIntent.maxQuestions:
      case QuizVoiceIntent.minQuestions:
      case QuizVoiceIntent.increaseQuestions:
      case QuizVoiceIntent.decreaseQuestions:
      case QuizVoiceIntent.setQuestionCount:
      case QuizVoiceIntent.startTest:
      case QuizVoiceIntent.explainQuestion:
      case QuizVoiceIntent.openReview:
      case QuizVoiceIntent.status:
      case QuizVoiceIntent.pauseAssistant:
      case QuizVoiceIntent.retry:
      case QuizVoiceIntent.cancel:
        break;
    }

    final heard = rawText.trim().isNotEmpty ? 'I heard "$rawText". ' : '';
    unawaited(
      _speakFeedback(
        '${heard}Not recognised. Try submit, confirm submit, back, unanswered, flagged, or question number.',
      ),
    );
  }

  void _goToQuestionViaVoice(int index) {
    if (index < 0 || index >= widget.questions.length) {
      unawaited(
        _speakFeedback(
          'Question ${index + 1} does not exist. There are ${widget.questions.length} questions total.',
        ),
      );
      return;
    }
    unawaited(_returnToExam(index));
  }

  void _returnToQuestionViaVoice() {
    final target = widget.questions.isEmpty
        ? 0
        : widget.returnQuestionIndex.clamp(0, widget.questions.length - 1);
    unawaited(_returnToExam(target));
  }

  void _jumpToBucketViaVoice(List<int> indexes, String emptyMessage) {
    if (indexes.isEmpty) {
      unawaited(_speakFeedback(emptyMessage));
      return;
    }
    unawaited(_returnToExam(indexes.first));
  }

  String _buildSubmitConfirmationMessage() {
    final summary = StringBuffer();
    final unanswered = _unansweredIndexes.length;
    final flagged = _flaggedIndexes.length;
    if (unanswered > 0) {
      summary.write('$unanswered unanswered. ');
    }
    if (flagged > 0) {
      summary.write('$flagged flagged. ');
    }
    if (summary.isEmpty) {
      summary.write('Ready to submit. ');
    }
    summary.write('Say confirm submit.');
    return summary.toString();
  }

  void _armSubmitConfirmation() {
    if (_awaitingSubmitConfirmation) return;
    setState(() => _awaitingSubmitConfirmation = true);
    _submitConfirmationTimer?.cancel();
    _submitConfirmationTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted) return;
      setState(() => _awaitingSubmitConfirmation = false);
    });
  }

  void _submitViaVoice() {
    if (_isSubmitting) {
      unawaited(_speakFeedback('Submission is already in progress.'));
      return;
    }
    _armSubmitConfirmation();
    unawaited(_speakFeedback(_buildSubmitConfirmationMessage()));
  }

  void _confirmSubmitViaVoice() {
    if (!_awaitingSubmitConfirmation) {
      unawaited(
        _speakFeedback('Please say submit first, then say confirm submit.'),
      );
      return;
    }
    _awaitingSubmitConfirmation = false;
    _submitConfirmationTimer?.cancel();
    unawaited(_submitFinalAnswers());
  }

  void _submitFromButton() {
    if (_isSubmitting) return;
    if (_awaitingSubmitConfirmation) {
      _confirmSubmitViaVoice();
      return;
    }

    _armSubmitConfirmation();
    final message = _buildSubmitConfirmationMessage();
    if (_voiceModeEnabled) {
      unawaited(_speakFeedback(message));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap Confirm Submit to finish.')),
      );
    }
  }

  Future<void> _returnToExam(int index) async {
    _listeningRestartTimer?.cancel();
    await _tts.stop();
    await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _heardText = '';
    });
    _syncVoiceSessionState();
    _voiceController.beginNavigation(targetScreen: QuizVoiceScreen.mcq);
    context.pop(index);
  }

  Future<void> _disableVoiceModeWithFeedback(String message) async {
    _listeningRestartTimer?.cancel();
    _submitConfirmationTimer?.cancel();
    await _speech.cancel();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _voiceModeEnabled = false;
      _isListening = false;
      _isSpeaking = false;
      _heardText = '';
      _awaitingSubmitConfirmation = false;
    });
    _syncVoiceSessionState();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year}, '
        '$hour:$minute:$second $ampm';
  }

  String _formatAttemptDate(HistoryAttempt attempt) {
    final date = attempt.endedAt ?? attempt.startedAt;
    if (date == null) return '-';
    return _formatDate(date);
  }

  HistoryEntry _mapAttemptToEntry(HistoryAttempt attempt) {
    final total =
        attempt.correctCount + attempt.wrongCount + attempt.unansweredCount;
    final scoreDetail = total > 0
        ? '${attempt.correctCount}/$total'
        : '${attempt.correctCount}/0';
    return HistoryEntry(
      examName: attempt.examName,
      date: _formatAttemptDate(attempt),
      scorePercent: attempt.score.toDouble(),
      scoreDetail: scoreDetail,
      attemptId: attempt.attemptId,
      examId: attempt.examId,
    );
  }

  HistoryEntry _entryFromSubmitResponse(
    Map<String, dynamic>? data,
    String examName,
    String? examId,
  ) {
    final score = data?['score'];
    final Map<String, dynamic> scoreMap = score is Map
        ? Map<String, dynamic>.from(score)
        : const {};
    final percent = _toDouble(scoreMap['percent']);
    final correct = _toInt(scoreMap['correct']);
    final total = _toInt(scoreMap['total']);
    final attemptId = data?['attemptId']?.toString();

    return HistoryEntry(
      examName: examName,
      date: _formatDate(DateTime.now()),
      scorePercent: percent,
      scoreDetail: total > 0 ? '$correct/$total' : '$correct/0',
      attemptId: attemptId,
      examId: examId,
    );
  }

  List<String> _extractOptions(dynamic question) {
    List<dynamic>? rawOptions;
    if (question is Map) {
      final options = question['options'];
      final choices = question['choices'];
      final answers = question['answers'];
      if (options is List) {
        rawOptions = options;
      } else if (choices is List) {
        rawOptions = choices;
      } else if (answers is List) {
        rawOptions = answers;
      }
    } else {
      try {
        final dynamic options = (question as dynamic).options;
        if (options is List) {
          rawOptions = options;
        }
      } catch (_) {}
    }

    final List<String> options = [];
    if (rawOptions != null) {
      for (final option in rawOptions) {
        if (option is Map) {
          final value =
              option['option'] ??
              option['text'] ??
              option['label'] ??
              option['value'] ??
              option['answer'];
          if (value != null) {
            options.add(value.toString());
          }
        } else if (option != null) {
          options.add(option.toString());
        }
      }
    }

    if (options.isEmpty) {
      options.addAll(const ['Option A', 'Option B', 'Option C', 'Option D']);
    }
    return options;
  }

  String _extractQuestionId(dynamic question, int index) {
    if (question == null) {
      return 'q_$index';
    }
    String? rawId;
    if (question is Map) {
      rawId = question['_id']?.toString();
      rawId ??= question['id']?.toString();
      rawId ??= question['questionId']?.toString();
    } else {
      try {
        rawId = (question as dynamic).id?.toString();
      } catch (_) {}
      try {
        rawId ??= (question as dynamic).questionId?.toString();
      } catch (_) {}
    }
    final trimmed = rawId?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return 'q_$index';
  }

  List<dynamic> _buildAnswers() {
    final total = widget.questions.length;
    final answers = List<dynamic>.filled(total, null);
    widget.selected.forEach((index, selectedIndex) {
      if (index < 0 || index >= total) return;
      if (selectedIndex < 0) return;
      final options = _extractOptions(widget.questions[index]);
      if (selectedIndex < options.length) {
        answers[index] = options[selectedIndex];
      } else {
        answers[index] = selectedIndex.toString();
      }
    });
    return answers;
  }

  List<String> _buildFlaggedIds() {
    final ids = <String>[];
    final total = widget.questions.length;
    for (final index in widget.flagged) {
      if (index < 0 || index >= total) continue;
      ids.add(_extractQuestionId(widget.questions[index], index));
    }
    return ids;
  }

  Future<void> _submitFinalAnswers() async {
    if (_isSubmitting) return;
    _awaitingSubmitConfirmation = false;
    _submitConfirmationTimer?.cancel();
    final examId = widget.examId?.trim();
    if (examId == null || examId.isEmpty) {
      ErrorHandler.showSnackBar(
        'Exam ID missing. Please try again.',
        isError: true,
        context: context,
      );
      return;
    }

    await _tts.stop();
    await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _voiceModeEnabled = false;
      _isSpeaking = false;
      _isListening = false;
      _isPreparingToListen = false;
      _heardText = '';
    });
    _voiceController.setVoiceEnabled(false, screen: QuizVoiceScreen.examReview);
    setState(() => _isSubmitting = true);
    try {
      final answers = _buildAnswers();
      final flaggedIds = _buildFlaggedIds();
      final response = await _examService.submitExam(
        examId: examId,
        answers: answers,
        flaggedQuestionIds: flaggedIds,
        timeSpentSec: widget.timeSpentSec,
      );

      if (!mounted) return;
      if (response.success) {
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data!)
            : null;
        final HistoryController historyController =
            Get.isRegistered<HistoryController>()
            ? Get.find<HistoryController>()
            : Get.put(HistoryController());

        HistoryEntry entry = _entryFromSubmitResponse(
          data,
          widget.courseTitle,
          examId,
        );
        List<HistoryEntry> historyEntries = const [];
        try {
          await historyController.fetchAttempts(page: 1, limit: 10);
          historyEntries = historyController.attempts
              .map(_mapAttemptToEntry)
              .toList();
          final matching = historyController.attempts
              .where((attempt) => attempt.examId == examId)
              .toList();
          if (matching.isNotEmpty) {
            entry = _mapAttemptToEntry(matching.first);
          }
        } catch (_) {
          // Keep fallback entry if history fetch fails.
        }

        if (!mounted) return;
        ErrorHandler.showSnackBar(
          ErrorHandler.getMessageFromResponse(
            response,
            successFallback: 'Final answers submitted.',
          ),
          isError: false,
          context: context,
        );
        setState(() {
          _isListening = false;
          _isSpeaking = false;
          _isPreparingToListen = false;
          _heardText = '';
        });
        _voiceController.setVoiceEnabled(
          false,
          screen: QuizVoiceScreen.examReview,
        );
        context.push(
          '/history-detail',
          extra: {
            'entry': entry,
            'historyEntries': historyEntries,
            'topics': const <TopicBreakdown>[],
          },
        );
      } else {
        ErrorHandler.showFromResponse(
          response,
          context: context,
          failureFallback: 'Failed to submit answers.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showFromException(
        e,
        context: context,
        fallback: 'Submit failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _syncVoiceSessionState();
      }
    }
  }

  Widget _buildReturnButton() {
    return OutlinedButton(
      onPressed: () => context.pop(0),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF2D4F88)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: const Text(
        'Return to Question',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2D4F88)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitFromButton,
      style: ElevatedButton.styleFrom(
        backgroundColor: _awaitingSubmitConfirmation
            ? const Color(0xFFB45309)
            : const Color(0xFF0F3A7D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: _isSubmitting
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Submitting...',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            )
          : Text(
              _awaitingSubmitConfirmation
                  ? 'Confirm Submit'
                  : 'Submit Final Answers',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    );
  }

  Widget _buildResponsiveActionButtons(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final useStackedLayout = availableWidth < 580 || textScale > 1.15;
            final gap = availableWidth >= 760 ? 16.0 : 12.0;

            if (useStackedLayout) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildReturnButton(),
                  SizedBox(height: gap),
                  _buildSubmitButton(),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: _buildReturnButton()),
                SizedBox(width: gap),
                Expanded(child: _buildSubmitButton()),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.autoSubmit && _isSubmitting) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F5FF),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      color: Color(0xFF1E4C9A),
                      backgroundColor: Color(0xFFD5D8DE),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Time is up. Submitting your answers...",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            _voiceModeEnabled ? 146 : 24,
          ),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Exam Review',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                _ReviewVoiceModeButton(
                  isEnabled: _voiceModeEnabled,
                  isListening: _isListening || _isPreparingToListen,
                  speechAvailable: _speechAvailable,
                  onTap: _toggleVoiceMode,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.courseTitle,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F6DE0),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Review your answers before final submission, Click on a question number to jump back to it',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 20),
            _ReviewSection(
              title: 'Flagged for Review (${_flaggedIndexes.length})',
              titleColor: const Color(0xFF2F6DE0),
              borderColor: const Color(0xFFFFB020),
              fillColor: const Color(0xFFFFF4D6),
              items: _flaggedIndexes,
              onTap: (index) => context.pop(index),
            ),
            const SizedBox(height: 16),
            _ReviewSection(
              title: 'Unanswered (${_unansweredIndexes.length})',
              titleColor: const Color(0xFFE24B4B),
              borderColor: const Color(0xFFE24B4B),
              fillColor: const Color(0xFFFFD6D6),
              items: _unansweredIndexes,
              onTap: (index) => context.pop(index),
            ),
            const SizedBox(height: 16),
            _ReviewSection(
              title: 'Answered (${_answeredIndexes.length})',
              titleColor: const Color(0xFF2DBD67),
              borderColor: const Color(0xFF2DBD67),
              fillColor: const Color(0xFFD8F5D8),
              items: _answeredIndexes,
              onTap: (index) => context.pop(index),
            ),
            const SizedBox(height: 26),
            _buildResponsiveActionButtons(context),
            const SizedBox(height: 18),
            const ApiDisclaimerSection(),
          ],
        ),
      ),
      bottomSheet: _voiceModeEnabled && !widget.autoSubmit
          ? QuizVoiceOverlay(
              isListening: _isListening || _isPreparingToListen,
              isPreparingToListen: _isPreparingToListen,
              isSpeaking: _isSpeaking,
              heardText: _heardText,
              onMicTap: _isSpeaking
                  ? _interruptAndListen
                  : (_isListening ? _stopListening : _startListening),
              listeningHint: 'Say submit, confirm submit, or back.',
              speakingHint: 'Assistant is speaking.',
              idleHint: 'Tap the mic or say a review command.',
              instructionItems: const <String>[
                'submit',
                'confirm submit',
                'back',
              ],
              bottomPadding: 42,
            )
          : null,
    );
  }
}

class _ReviewSection extends StatelessWidget {
  final String title;
  final Color titleColor;
  final Color borderColor;
  final Color fillColor;
  final List<int> items;
  final ValueChanged<int> onTap;

  const _ReviewSection({
    required this.title,
    required this.titleColor,
    required this.borderColor,
    required this.fillColor,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (index) => GestureDetector(
                  onTap: () => onTap(index),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.4),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: borderColor,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ReviewVoiceModeButton extends StatelessWidget {
  final bool isEnabled;
  final bool isListening;
  final bool speechAvailable;
  final VoidCallback onTap;

  const _ReviewVoiceModeButton({
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
    final String tooltip;

    if (!speechAvailable) {
      bg = Colors.transparent;
      iconColor = Colors.grey.shade400;
      icon = Icons.mic_off;
      tooltip = 'Speech recognition unavailable';
    } else if (isEnabled) {
      bg = isListening ? const Color(0xFFFFE4E4) : const Color(0xFFDCFCE7);
      iconColor = isListening
          ? const Color(0xFFB91C1C)
          : const Color(0xFF166534);
      icon = Icons.mic;
      tooltip = 'Tap to turn off voice mode';
    } else {
      bg = Colors.transparent;
      iconColor = const Color(0xFF274B8A);
      icon = Icons.mic_none;
      tooltip = 'Tap to turn on voice mode';
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
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
      ),
    );
  }
}

class _ReviewListeningOverlay extends StatefulWidget {
  final bool isListening;
  final bool isSpeaking;
  final String heardText;
  final VoidCallback onMicTap;

  const _ReviewListeningOverlay({
    required this.isListening,
    required this.isSpeaking,
    required this.heardText,
    required this.onMicTap,
  });

  @override
  State<_ReviewListeningOverlay> createState() =>
      _ReviewListeningOverlayState();
}

class _ReviewListeningOverlayState extends State<_ReviewListeningOverlay>
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
        : 'Hands-free review ready';
    final helperText = listening
        ? 'Say submit, back, unanswered, flagged, or question number.'
        : speaking
        ? 'Assistant is reading the review guidance.'
        : 'Tap mic anytime to interrupt and speak.';

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 42),
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
                      _ReviewMicCircle(bg: accentColor),
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
                Tooltip(
                  message:
                      'Review: submit, back, unanswered, flagged, question 5, read',
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: accentColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewMicCircle extends StatelessWidget {
  final Color bg;

  const _ReviewMicCircle({required this.bg});

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
