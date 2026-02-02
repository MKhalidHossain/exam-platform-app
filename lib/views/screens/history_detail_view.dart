import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';

import 'history_models.dart';
import 'performance_screen.dart';
import 'history_testimonial_dialog.dart';
import 'history_thank_you_dialog.dart';
import '../../controllers/history_controller.dart';
import '../../models/history_attempt_detail_model.dart';

class HistoryDetailView extends StatefulWidget {
  const HistoryDetailView({
    super.key,
    required this.entry,
    required this.topics,
    required this.onBack,
    required this.historyEntries,
  });

  final HistoryEntry entry;
  final List<TopicBreakdown> topics;
  final List<HistoryEntry> historyEntries;
  final VoidCallback onBack;

  @override
  State<HistoryDetailView> createState() => _HistoryDetailViewState();
}

class _HistoryDetailViewState extends State<HistoryDetailView> {
  bool _dialogShown = false;
  final ScrollController _topicScrollController = ScrollController();
  late final HistoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<HistoryController>()
        ? Get.find<HistoryController>()
        : Get.put(HistoryController());
    _fetchDetail();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dialogShown && widget.entry.scorePercent >= 100) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTestimonialDialog(context);
      });
    }
  }

  @override
  void didUpdateWidget(covariant HistoryDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.attemptId != widget.entry.attemptId) {
      _fetchDetail();
    }
  }

  void _fetchDetail() {
    final attemptId = widget.entry.attemptId;
    if (attemptId == null || attemptId.trim().isEmpty) return;
    if (_controller.attemptDetails.containsKey(attemptId) ||
        (_controller.attemptDetailLoading[attemptId] ?? false)) {
      return;
    }
    _controller.fetchAttemptDetail(attemptId);
  }

  String _joinAnswers(List<String> values) {
    final cleaned =
        values.map((value) => value.trim()).where((value) => value.isNotEmpty);
    return cleaned.isEmpty ? '-' : cleaned.join(', ');
  }

  List<TopicBreakdown> _mapTopicBreakdown(HistoryAttemptDetail? detail) {
    final breakdown = detail?.review?.topicBreakdown ?? const [];
    if (breakdown.isEmpty) return const [];
    return breakdown
        .map(
          (topic) => TopicBreakdown(
            category: topic.category,
            correct: topic.correct,
            incorrect: topic.incorrect,
            accuracy: topic.accuracy,
          ),
        )
        .toList();
  }

  Widget _buildSectionMessage(
    String message,
    double scale, {
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 8 * scale),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11 * scale,
              color: const Color(0xFF6C7685),
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(height: 8 * scale),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showTestimonialDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF8B909B),
      builder: (dialogContext) {
        return HistoryTestimonialDialog(
          onSkip: () => Navigator.of(dialogContext).pop(),
          onSubmit: () {
            Navigator.of(dialogContext).pop();
            _showThankYouDialog(context);
          },
        );
      },
    );
  }

  Future<void> _showThankYouDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF8B909B),
      builder: (dialogContext) {
        return HistoryThankYouDialog(
          onBackToExam: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }

  @override
  void dispose() {
    _topicScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final attemptId = widget.entry.attemptId;
      final HistoryAttemptDetail? detail = attemptId == null
          ? null
          : _controller.attemptDetails[attemptId];
      final bool isDetailLoading = attemptId != null &&
          (_controller.attemptDetailLoading[attemptId] ?? false);
      final String? detailError =
          attemptId == null ? null : _controller.attemptDetailErrors[attemptId];
      final List<TopicBreakdown> detailTopics = _mapTopicBreakdown(detail);
      final List<AttemptReviewAnswer> reviewAnswers =
          detail?.review?.answers ?? const [];
      final String examName = (detail?.exam?.name ?? '').trim().isNotEmpty
          ? detail!.exam!.name
          : widget.entry.examName;
      final double scorePercent =
          detail != null ? detail.score.toDouble() : widget.entry.scorePercent;

      return LayoutBuilder(
        builder: (context, constraints) {
          final double scale = (constraints.maxWidth / 375).clamp(0.85, 1.15);
          final double hPad = 12 * scale;
          final double titleSize = 15 * scale;
          final double captionSize = 10.5 * scale;
          final double scoreSize = 22 * scale;
          final double buttonSize = 12 * scale;
          final double sectionTitle = 14 * scale;
          final double headerSize = 9.5 * scale;
          final double rowSize = 10 * scale;
          final double cardTitle = 11 * scale;
          final double cardBody = 10 * scale;
          final double colCategory = 150 * scale;
          final double colCorrect = 62 * scale;
          final double colIncorrect = 70 * scale;
          final double colAccuracy = 70 * scale;
          final double colStatus = 60 * scale;
          final bool useFallbackTopics = attemptId == null;
          final List<TopicBreakdown> topics =
              useFallbackTopics ? widget.topics : detailTopics;
          final double topicTableWidth = colCategory +
              colCorrect +
              colIncorrect +
              colAccuracy +
              colStatus;
          final double questionTableWidth =
              colCategory + colCorrect + colIncorrect + colStatus;

          final Widget topicContent;
          if (attemptId != null && detail == null && isDetailLoading) {
            topicContent = const Center(child: CircularProgressIndicator());
          } else if (attemptId != null &&
              detail == null &&
              detailError != null &&
              detailError.trim().isNotEmpty) {
            topicContent = _buildSectionMessage(
              detailError,
              scale,
              onRetry: _fetchDetail,
            );
          } else if (useFallbackTopics || detailTopics.isNotEmpty) {
            topicContent = Scrollbar(
              controller: _topicScrollController,
              thumbVisibility: true,
              thickness: 2,
              radius: const Radius.circular(4),
              child: SingleChildScrollView(
                controller: _topicScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: topicTableWidth,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _TopicHeaderCell(
                            label: 'Category',
                            width: colCategory,
                            fontSize: headerSize,
                            height: 24 * scale,
                          ),
                          _TopicHeaderCell(
                            label: 'Correct',
                            width: colCorrect,
                            fontSize: headerSize,
                            height: 24 * scale,
                          ),
                          _TopicHeaderCell(
                            label: 'Incorrect',
                            width: colIncorrect,
                            fontSize: headerSize,
                            height: 24 * scale,
                          ),
                          _TopicHeaderCell(
                            label: 'Accuracy',
                            width: colAccuracy,
                            fontSize: headerSize,
                            height: 24 * scale,
                          ),
                          _TopicHeaderCell(
                            label: 'Status',
                            width: colStatus,
                            fontSize: headerSize,
                            height: 24 * scale,
                          ),
                        ],
                      ),
                      SizedBox(height: 14 * scale),
                      ...topics.map(
                        (topic) {
                          final bool passed = topic.correct > 0;
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 6 * scale),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: colCategory,
                                  child: Text(
                                    topic.category,
                                    style: TextStyle(fontSize: rowSize),
                                  ),
                                ),
                                SizedBox(
                                  width: colCorrect,
                                  child: Text(
                                    '${topic.correct}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: rowSize),
                                  ),
                                ),
                                SizedBox(
                                  width: colIncorrect,
                                  child: Text(
                                    '${topic.incorrect}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: rowSize),
                                  ),
                                ),
                                SizedBox(
                                  width: colAccuracy,
                                  child: Text(
                                    '${topic.accuracy}%',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: rowSize),
                                  ),
                                ),
                                SizedBox(
                                  width: colStatus,
                                  child: Center(
                                    child: Icon(
                                      passed ? Icons.check : Icons.close,
                                      size: 16 * scale,
                                      color: passed
                                          ? const Color(0xFF1BA64B)
                                          : const Color(0xFFE53935),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          } else if (reviewAnswers.isNotEmpty) {
            topicContent = Scrollbar(
              controller: _topicScrollController,
              thumbVisibility: true,
              thickness: 2,
              radius: const Radius.circular(4),
              child: SingleChildScrollView(
                controller: _topicScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: questionTableWidth,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _TopicHeaderCell(
                            label: 'Category',
                            width: colCategory,
                            fontSize: headerSize,
                            height: 24 * scale,
                          ),
                          _TopicHeaderCell(
                            label: 'Correct',
                            width: colCorrect,
                            fontSize: headerSize,
                            height: 24 * scale,
                          ),
                          _TopicHeaderCell(
                            label: 'Incorrect',
                            width: colIncorrect,
                            fontSize: headerSize,
                            height: 24 * scale,
                          ),
                          _TopicHeaderCell(
                            label: 'Status',
                            width: colStatus,
                            fontSize: headerSize,
                            height: 24 * scale,
                          ),
                        ],
                      ),
                      SizedBox(height: 14 * scale),
                      ...reviewAnswers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final answer = entry.value;
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 6 * scale),
                          child: Row(
                            children: [
                              SizedBox(
                                width: colCategory,
                                child: Text(
                                  'Q${index + 1}',
                                  style: TextStyle(fontSize: rowSize),
                                ),
                              ),
                              SizedBox(
                                width: colCorrect,
                                child: Text(
                                  answer.isCorrect ? '1' : '0',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: rowSize),
                                ),
                              ),
                              SizedBox(
                                width: colIncorrect,
                                child: Text(
                                  answer.isCorrect ? '0' : '1',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: rowSize),
                                ),
                              ),
                              SizedBox(
                                width: colStatus,
                                child: Center(
                                  child: Icon(
                                    answer.isCorrect
                                        ? Icons.check
                                        : Icons.close,
                                    size: 16 * scale,
                                    color: answer.isCorrect
                                        ? const Color(0xFF1BA64B)
                                        : const Color(0xFFE53935),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          } else {
            topicContent =
                _buildSectionMessage('No topic breakdown available.', scale);
          }

          final Widget reviewContent;
          if (attemptId != null && detail == null && isDetailLoading) {
            reviewContent = const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (attemptId != null &&
              detail == null &&
              detailError != null &&
              detailError.trim().isNotEmpty) {
            reviewContent = _buildSectionMessage(
              detailError,
              scale,
              onRetry: _fetchDetail,
            );
          } else if (reviewAnswers.isEmpty) {
            reviewContent =
                _buildSectionMessage('No answers available.', scale);
          } else {
            reviewContent = Column(
              children: reviewAnswers.asMap().entries.map((entry) {
                final index = entry.key;
                final answer = entry.value;
                final correctAnswers = answer.correctAnswer.isNotEmpty
                    ? answer.correctAnswer
                    : (answer.isCorrect ? answer.userAnswer : const <String>[]);
                return _ReviewCard(
                  questionNumber: index + 1,
                  question: answer.questionId.isNotEmpty
                      ? 'Question ID: ${answer.questionId}'
                      : 'Question ${index + 1}',
                  userAnswer: _joinAnswers(answer.userAnswer),
                  isCorrect: answer.isCorrect,
                  correctAnswer: _joinAnswers(correctAnswers),
                  scale: scale,
                  titleSize: cardTitle,
                  bodySize: cardBody,
                );
              }).toList(),
            );
          }

          return Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, 6 * scale, hPad, 24 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        color: const Color(0xFF27407C),
                      ),
                      Expanded(
                        child: Text(
                          examName,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF27407C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 6 * scale),
                    child: Text(
                      "Here's how you did on the '$examName'\nexam.",
                      style: TextStyle(
                        fontSize: captionSize,
                        color: const Color(0xFF6C7685),
                      ),
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Your Score.',
                          style: TextStyle(
                            fontSize: captionSize,
                            color: const Color(0xFF6C7685),
                          ),
                        ),
                        SizedBox(height: 4 * scale),
                        Text(
                          '${scorePercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: scoreSize,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E6CF3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            context.push(
                              '/quiz-settings',
                              extra: {
                                'courseTitle': examName,
                                'examId': widget.entry.examId,
                              },
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF20324A),
                            backgroundColor: const Color(0xFFE1E4EA),
                            side: const BorderSide(color: Color(0xFFBCC6D6)),
                            padding: EdgeInsets.symmetric(vertical: 12 * scale),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            'Try Again',
                            style: TextStyle(fontSize: buttonSize),
                          ),
                        ),
                      ),
                      SizedBox(width: 12 * scale),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            context.push(
                              '/performance',
                              extra: PerformanceArgs(
                                entry: widget.entry,
                                history: widget.historyEntries,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E4AA8),
                            padding: EdgeInsets.symmetric(vertical: 12 * scale),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            'Performance',
                            style: TextStyle(fontSize: buttonSize),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10 * scale),
                  OutlinedButton.icon(
                    onPressed: () {
                      final examId = widget.entry.examId?.trim();
                      if (examId == null || examId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Exam ID missing. Please try again.',
                            ),
                          ),
                        );
                        return;
                      }
                      context.push(
                        '/exam-loading',
                        extra: {
                          'courseTitle': examName,
                          'examId': examId,
                          'questionCount': 120,
                          'examType': 'full_exam',
                        },
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E4AA8),
                      side: const BorderSide(color: Color(0xFF9FB4E9)),
                      padding: EdgeInsets.symmetric(
                        vertical: 12 * scale,
                        horizontal: 16 * scale,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(
                      'Regenerate Exam (120 New Questions)',
                      style: TextStyle(fontSize: buttonSize),
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  Center(
                    child: Text(
                      'Topic Breakdown',
                      style: TextStyle(
                        fontSize: sectionTitle,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8 * scale,
                      vertical: 8 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE0E5F1)),
                    ),
                    child: topicContent,
                  ),
                  SizedBox(height: 16 * scale),
                  Center(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(10 * scale),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE0E5F1)),
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: 4 * scale),
                          Center(
                            child: Text(
                              'Review Your Answers',
                              style: TextStyle(
                                fontSize: 13 * scale,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(height: 10 * scale),
                          reviewContent,
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Disclaimer tapped.'),
                                  ),
                                );
                              },
                              child: Text.rich(
                                TextSpan(
                                  text: 'Not affiliated with or endorsed by API. ',
                                  style: TextStyle(
                                    fontSize: 10 * scale,
                                    color: const Color(0xFF6C7685),
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'See full\n',
                                      style: TextStyle(
                                        fontSize: 10 * scale,
                                        color: Color(0xFF1E6CF3),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'disclaimer.',
                                      style: TextStyle(
                                        fontSize: 10 * scale,
                                        color: Color(0xFF1E6CF3),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          SizedBox(height: 12 * scale),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

class _TopicHeaderCell extends StatelessWidget {
  const _TopicHeaderCell({
    required this.label,
    required this.width,
    required this.fontSize,
    required this.height,
  });

  final String label;
  final double width;
  final double fontSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE0E5F1)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.questionNumber,
    required this.question,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.scale,
    required this.titleSize,
    required this.bodySize,
  });

  final int questionNumber;
  final String question;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final double scale;
  final double titleSize;
  final double bodySize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10 * scale),
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD5DAE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q$questionNumber. $question',
            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6 * scale),
          if (!isCorrect)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your answer : ',
                  style: TextStyle(
                    fontSize: bodySize + 2,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text(
                    ' $userAnswer (Incorrect)',
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      fontSize: bodySize,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: 4 * scale),
          Text(
            'Correct answer : $correctAnswer',
            style: TextStyle(fontSize: bodySize, color: Colors.green),
          ),
        ],
      ),
    );
  }
}
