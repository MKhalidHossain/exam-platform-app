import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'history_models.dart';
import 'performance_screen.dart';
import 'history_testimonial_dialog.dart';
import 'history_thank_you_dialog.dart';

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
        final double tableWidth = colCategory +
            colCorrect +
            colIncorrect +
            colAccuracy +
            colStatus;

        return SingleChildScrollView(
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
                      widget.entry.examName,
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
                  "Here's how you did on the '${widget.entry.examName}'\nexam.",
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
                      '${widget.entry.scorePercent.toStringAsFixed(1)}%',
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
                          extra: {'courseTitle': widget.entry.examName},
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
                  context.push(
                    '/exam-loading',
                    extra: {'courseTitle': widget.entry.examName},
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
                child: Scrollbar(
                  controller: _topicScrollController,
                  thumbVisibility: true,
                  thickness: 2,
                  radius: const Radius.circular(4),
                  child: SingleChildScrollView(
                    controller: _topicScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
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
                          ...widget.topics.map(
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
                ),
              ),
              SizedBox(height: 16 * scale),
              Center(
                child: Container(
                  width: double.infinity,
                  // padding: EdgeInsets.symmetric(vertical: 10 * scale),
                  padding: EdgeInsets.all( 10 * scale),
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
                      ...List.generate(
                        10,
                        (index) => _ReviewCard(
                          questionNumber: index + 1,
                          question: 'When I think about my childhood, I\nfeel?',
                          userAnswer: '0.0025 inches/years',
                          isCorrect: index == 3 || index == 4 || index == 5,
                          correctAnswer: '0.010 inches/year',
                          scale: scale,
                          titleSize: cardTitle,
                          bodySize: cardBody,
                        ),
                      ),
                      // SizedBox(height: 12 * scale),
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
        );
      },
    );
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
              children: [
                Text(
                  'Your answer : ',
                  style: TextStyle(
                    fontSize: bodySize + 2,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  ' $userAnswer (Incorrect)',
                  style: TextStyle(
                    fontSize: bodySize,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
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
