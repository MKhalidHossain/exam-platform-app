import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart' hide ErrorHandler;
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/error/error_handler.dart';
import '../../services/exam_service.dart';
import '../../controllers/history_controller.dart';
import '../../models/history_attempt_model.dart';
import 'history_models.dart';
import '../widgets/api_disclaimer_section.dart';

class ExamReviewScreen extends StatefulWidget {
  final String courseTitle;
  final List<dynamic> questions;
  final Map<int, int> selected;
  final Set<int> flagged;
  final String? examId;
  final List<int>? timeSpentSec;
  final bool autoSubmit;
  final bool voiceModeEnabled;

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
  });

  @override
  State<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends State<ExamReviewScreen> {
  final ExamService _examService = ExamService();
  final SpeechToText _speech = SpeechToText();
  late final FlutterTts _tts;
  bool _isSubmitting = false;
  bool _voiceModeEnabled = false;
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _awaitingSubmitConfirmation = false;
  Timer? _submitConfirmationTimer;
  String? _speechLocaleId;
  String _heardText = '';

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _voiceModeEnabled = widget.voiceModeEnabled;
    _configureTts();
    _initSpeech();
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
    _submitConfirmationTimer?.cancel();
    unawaited(_tts.stop());
    unawaited(_speech.cancel());
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
      if (_voiceModeEnabled && !_isSubmitting && !_isListening) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && _voiceModeEnabled && !_isSubmitting) {
            unawaited(_startListening());
          }
        });
      }
    });
    _tts.setCancelHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (_) {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (!mounted) return;
        if ((status == 'done' || status == 'notListening') && _isListening) {
          setState(() => _isListening = false);
        }
      },
    );
    String? preferredLocaleId;
    if (available) {
      preferredLocaleId = await _resolvePreferredSpeechLocaleId();
    }
    if (!mounted) return;
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
      buffer.write('$flagged question${flagged == 1 ? '' : 's'} flagged for review. ');
    }
    if (unanswered > 0) {
      buffer.write('$unanswered question${unanswered == 1 ? '' : 's'} unanswered. ');
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
    await _speech.cancel();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });
    await _tts.speak(text);
  }

  Future<void> _toggleVoiceMode() async {
    if (_voiceModeEnabled) {
      await _tts.stop();
      await _speech.cancel();
      if (!mounted) return;
      setState(() {
        _voiceModeEnabled = false;
        _isListening = false;
        _isSpeaking = false;
        _heardText = '';
      });
      return;
    }

    if (!_speechAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition is not available on this device.'),
        ),
      );
      return;
    }

    setState(() {
      _voiceModeEnabled = true;
      _heardText = '';
    });
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted && _voiceModeEnabled) {
      await _speakReviewSummary();
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable || _isListening || _isSpeaking || _isSubmitting) {
      return;
    }
    setState(() {
      _isListening = true;
      _heardText = '';
    });
    await _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 7),
      localeId: _speechLocaleId,
      listenOptions: SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  Future<void> _interruptAndListen() async {
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _isListening = false;
    });
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) unawaited(_startListening());
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() => _heardText = result.recognizedWords);
    if (result.finalResult) {
      setState(() => _isListening = false);
      final text = result.recognizedWords.trim();
      if (text.isNotEmpty) {
        _handleVoiceCommand(text);
      }
    }
  }

  bool _wordMatch(String text, List<String> keywords) =>
      keywords.any((kw) => text == kw || text.contains(kw));

  void _handleVoiceCommand(String rawText) {
    final text = _normalizeCommand(rawText);

    final qMatch = RegExp(r'(?:question|go to|number|q)\s*(\d+)').firstMatch(text);
    if (qMatch != null) {
      final n = int.tryParse(qMatch.group(1) ?? '') ?? 0;
      _goToQuestionViaVoice(n - 1);
      return;
    }

    if (_wordMatch(text, [
      'confirm',
      'confirm submit',
      'yes submit',
      'submit confirm',
      'confirm finish',
    ])) {
      _confirmSubmitViaVoice();
      return;
    }

    if (_wordMatch(text, [
      'submit',
      'finish',
      'done',
      'complete',
      'submit exam',
    ])) {
      _submitViaVoice();
      return;
    }

    if (_wordMatch(text, [
      'back',
      'return',
      'go back',
      'return to question',
      'back to exam',
    ])) {
      _returnToQuestionViaVoice();
      return;
    }

    if (_wordMatch(text, ['unanswered', 'review unanswered', 'open unanswered'])) {
      _jumpToBucketViaVoice(_unansweredIndexes, 'There are no unanswered questions.');
      return;
    }

    if (_wordMatch(text, ['flagged', 'review flagged', 'open flagged'])) {
      _jumpToBucketViaVoice(_flaggedIndexes, 'There are no flagged questions.');
      return;
    }

    if (_wordMatch(text, ['read', 'repeat', 'again', 'summary', 'review'])) {
      unawaited(_speakReviewSummary());
      return;
    }

    if (_wordMatch(text, ['help', 'commands', 'what can i say'])) {
      unawaited(_speakFeedback(
        'Review commands. '
        'Say submit, then say confirm submit, to finish the exam. '
        'Say question 5 to return to that question. '
        'Say unanswered to jump to the first unanswered question. '
        'Say flagged to jump to the first flagged question. '
        'Say back to return to the exam. '
        'Say read to hear this summary again.',
      ));
      return;
    }

    final heard = rawText.trim().isNotEmpty ? 'I heard "$rawText". ' : '';
    unawaited(_speakFeedback(
      '${heard}Not recognised. Try submit, confirm submit, back, unanswered, flagged, or question number.',
    ));
  }

  String _normalizeCommand(String rawText) {
    var text = rawText.toLowerCase();
    text = text.replaceAll("'", '');
    text = text.replaceAll(RegExp(r"[^a-z0-9\s]"), ' ');
    const fillerPhrases = [
      'please',
      'can you',
      'could you',
      'would you',
      'i want to',
      'i wanna',
      'let me',
      'show me',
      'take me to',
      'go ahead and',
      'i would like to',
    ];
    for (final filler in fillerPhrases) {
      text = text.replaceAll(filler, ' ');
    }

    const phraseAliases = {
      'go previous': 'back',
      'go back to exam': 'back',
      'return to exam': 'back',
      'open unanswered': 'unanswered',
      'review unanswered': 'unanswered',
      'open flagged': 'flagged',
      'review flagged': 'flagged',
      'finish exam': 'submit',
      'submit now': 'submit',
      'yes confirm': 'confirm submit',
      'confirm now': 'confirm submit',
      'read again': 'read',
      'say again': 'read',
      'review summary': 'summary',
    };
    phraseAliases.forEach((from, to) {
      text = text.replaceAll(from, to);
    });

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _goToQuestionViaVoice(int index) {
    if (index < 0 || index >= widget.questions.length) {
      unawaited(_speakFeedback(
        'Question ${index + 1} does not exist. There are ${widget.questions.length} questions total.',
      ));
      return;
    }
    unawaited(_returnToExam(index));
  }

  void _returnToQuestionViaVoice() {
    final target = _unansweredIndexes.isNotEmpty
        ? _unansweredIndexes.first
        : _flaggedIndexes.isNotEmpty
            ? _flaggedIndexes.first
            : _answeredIndexes.isNotEmpty
                ? _answeredIndexes.first
                : 0;
    unawaited(_returnToExam(target));
  }

  void _jumpToBucketViaVoice(List<int> indexes, String emptyMessage) {
    if (indexes.isEmpty) {
      unawaited(_speakFeedback(emptyMessage));
      return;
    }
    unawaited(_returnToExam(indexes.first));
  }

  void _submitViaVoice() {
    if (_isSubmitting) {
      unawaited(_speakFeedback('Your answers are already submitting.'));
      return;
    }
    _awaitingSubmitConfirmation = true;
    _submitConfirmationTimer?.cancel();
    _submitConfirmationTimer = Timer(const Duration(seconds: 12), () {
      _awaitingSubmitConfirmation = false;
    });

    final unanswered = _unansweredIndexes.length;
    final flagged = _flaggedIndexes.length;
    final summary = StringBuffer();
    if (unanswered > 0) {
      summary.write(
        'You still have $unanswered unanswered '
        '${unanswered == 1 ? 'question' : 'questions'}. ',
      );
    }
    if (flagged > 0) {
      summary.write(
        '$flagged question${flagged == 1 ? '' : 's'} flagged for review. ',
      );
    }
    summary.write('Say confirm submit to finish the exam now.');
    unawaited(_speakFeedback(summary.toString()));
  }

  void _confirmSubmitViaVoice() {
    if (!_awaitingSubmitConfirmation) {
      unawaited(_speakFeedback(
        'Please say submit first, then say confirm submit.',
      ));
      return;
    }
    _awaitingSubmitConfirmation = false;
    _submitConfirmationTimer?.cancel();
    unawaited(_submitFinalAnswers());
  }

  Future<void> _returnToExam(int index) async {
    await _tts.stop();
    await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _heardText = '';
    });
    context.pop(index);
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
      _isSpeaking = false;
      _isListening = false;
      _heardText = '';
    });
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
      onPressed: _isSubmitting ? null : _submitFinalAnswers,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0F3A7D),
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
          : const Text(
              'Submit Final Answers',
              textAlign: TextAlign.center,
              style: TextStyle(
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
                  isListening: _isListening,
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
          ? _ReviewListeningOverlay(
              isListening: _isListening,
              isSpeaking: _isSpeaking,
              heardText: _heardText,
              onMicTap: _isSpeaking
                  ? _interruptAndListen
                  : (_isListening ? _stopListening : _startListening),
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
  State<_ReviewListeningOverlay> createState() => _ReviewListeningOverlayState();
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
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.isListening;
    final speaking = widget.isSpeaking;
    final borderColor = listening
        ? const Color(0xFFEF4444)
        : speaking
            ? const Color(0xFF2D4F88)
            : const Color(0xFFD1D5DB);
    final micBg = listening ? const Color(0xFFEF4444) : const Color(0xFF2D4F88);
    final statusText = listening
        ? 'Listening...'
        : speaking
            ? 'Speaking...'
            : 'Voice mode active - tap mic to speak';
    final statusColor = listening
        ? const Color(0xFFB91C1C)
        : speaking
            ? const Color(0xFF1E4C9A)
            : const Color(0xFF6B7280);

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 42),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onMicTap,
                  child: listening
                      ? ScaleTransition(
                          scale: _scale,
                          child: _ReviewMicCircle(bg: micBg),
                        )
                      : _ReviewMicCircle(bg: micBg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      if (widget.heardText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Heard: "${widget.heardText}"',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Tooltip(
                  message:
                      'Review: submit, back, unanswered, flagged, question 5, read',
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
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
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: const Icon(Icons.mic, color: Colors.white, size: 20),
    );
  }
}
