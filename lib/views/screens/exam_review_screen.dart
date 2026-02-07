import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import '../../core/error/error_handler.dart';
import '../../services/exam_service.dart';
import '../../controllers/history_controller.dart';
import '../../models/history_attempt_model.dart';
import 'history_models.dart';

class ExamReviewScreen extends StatefulWidget {
  final String courseTitle;
  final List<dynamic> questions;
  final Map<int, int> selected;
  final Set<int> flagged;
  final String? examId;
  final List<int>? timeSpentSec;
  final bool autoSubmit;

  const ExamReviewScreen({
    super.key,
    required this.courseTitle,
    required this.questions,
    required this.selected,
    required this.flagged,
    this.examId,
    this.timeSpentSec,
    this.autoSubmit = false,
  });

  @override
  State<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends State<ExamReviewScreen> {
  final ExamService _examService = ExamService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoSubmit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _submitFinalAnswers();
        }
      });
    }
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
    final scoreDetail =
        total > 0 ? '${attempt.correctCount}/$total' : '${attempt.correctCount}/0';
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
    final Map<String, dynamic> scoreMap =
        score is Map ? Map<String, dynamic>.from(score) : const {};
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
          final value = option['option'] ??
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
    final examId = widget.examId?.trim();
    if (examId == null || examId.isEmpty) {
      ErrorHandler.showSnackBar('Exam ID missing. Please try again.', isError: true, context: context);
      return;
    }

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
        final data =
            response.data is Map ? Map<String, dynamic>.from(response.data!) : null;
        final HistoryController historyController =
            Get.isRegistered<HistoryController>()
                ? Get.find<HistoryController>()
                : Get.put(HistoryController());

        HistoryEntry entry =
            _entryFromSubmitResponse(data, widget.courseTitle, examId);
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
          ErrorHandler.getMessageFromResponse(response, successFallback: 'Final answers submitted.'),
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
        ErrorHandler.showFromResponse(response, context: context, failureFallback: 'Failed to submit answers.');
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showFromException(e, context: context, fallback: 'Submit failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
    final int total = widget.questions.length;
    final List<int> answered = List<int>.generate(total, (i) => i)
        .where((i) => widget.selected[i] != null)
        .toList();
    final List<int> unanswered = List<int>.generate(total, (i) => i)
        .where((i) => widget.selected[i] == null)
        .toList();
    final List<int> flaggedList = List<int>.generate(total, (i) => i)
        .where((i) => widget.flagged.contains(i))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const Text(
              'Exam Review',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
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
              title: 'Flagged for Review (${flaggedList.length})',
              titleColor: const Color(0xFF2F6DE0),
              borderColor: const Color(0xFFFFB020),
              fillColor: const Color(0xFFFFF4D6),
              items: flaggedList,
              onTap: (index) => context.pop(index),
            ),
            const SizedBox(height: 16),
            _ReviewSection(
              title: 'Unanswered (${unanswered.length})',
              titleColor: const Color(0xFFE24B4B),
              borderColor: const Color(0xFFE24B4B),
              fillColor: const Color(0xFFFFD6D6),
              items: unanswered,
              onTap: (index) => context.pop(index),
            ),
            const SizedBox(height: 16),
            _ReviewSection(
              title: 'Answered (${answered.length})',
              titleColor: const Color(0xFF2DBD67),
              borderColor: const Color(0xFF2DBD67),
              fillColor: const Color(0xFFD8F5D8),
              items: answered,
              onTap: (index) => context.pop(index),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(0),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2D4F88)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Return to Question',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D4F88),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitFinalAnswers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3A7D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _DisclaimerSection(),
          ],
        ),
      ),
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

class _DisclaimerSection extends StatelessWidget {
  const _DisclaimerSection();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text.rich(
        TextSpan(
          text: 'Not affiliated with or endorsed by API. ',
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
          children: const [
            TextSpan(
              text: 'See full disclaimer.',
              style: TextStyle(
                color: Color(0xFF2F6DE0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
