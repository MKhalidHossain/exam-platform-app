import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'history_models.dart';
import 'performance_screen.dart';

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
    final nameController = TextEditingController(text: 'Butlar Mane');
    final testimonialController = TextEditingController();
    int selectedStars = 3;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF8B909B),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Great Job!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202B3C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "You're amazing! Would you be willing to share a few\n"
                      "words about your experience to help others on their\n"
                      'certification journey?',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6C7685),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Rate 1 to 5 stars',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF202B3C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(5, (index) {
                        final isSelected = index < selectedStars;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.star,
                              size: 28,
                              color: isSelected
                                  ? const Color(0xFFFFB233)
                                  : const Color(0xFFB8BDC8),
                            ),
                            onPressed: () =>
                                setState(() => selectedStars = index + 1),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your Testimonial',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF202B3C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: testimonialController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            'e.g., This platform was a game-changer for my\nexam preparation.',
                        hintStyle: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9AA3B2),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFD5DAE6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFD5DAE6)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your Name',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF202B3C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2F5BD5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2F5BD5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E4AA8),
                              side: const BorderSide(color: Color(0xFF1E4AA8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'No, Thanks',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _showThankYouDialog(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E4AA8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'Submit Testimonial',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Disclaimer tapped.')),
                          );
                        },
                        child: const Text.rich(
                          TextSpan(
                            text: 'Not affiliated with or endorsed by API. ',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF6C7685),
                            ),
                            children: [
                              TextSpan(
                                text: 'See full\n',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF1E6CF3),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(
                                text: 'disclaimer.',
                                style: TextStyle(
                                  fontSize: 10,
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
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    nameController.dispose();
    testimonialController.dispose();
  }

  Future<void> _showThankYouDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF8B909B),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 36),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDFF5E2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFF33C44F),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 28),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Thank you! 🎉',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202B3C),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'your feedback is invaluable and helps others make\n'
                  'confident decisions. We appreciate you!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6C7685),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF143E88),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 26),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text(
                    'Back to Exam',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Try Again pressed.')),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exam regenerated.')),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        _TopicHeaderCell(
                          label: 'Category',
                          flex: 4,
                          fontSize: headerSize,
                          height: 24 * scale,
                        ),
                        _TopicHeaderCell(
                          label: 'Correct',
                          flex: 2,
                          fontSize: headerSize,
                          height: 24 * scale,
                        ),
                        _TopicHeaderCell(
                          label: 'Incorrect',
                          flex: 2,
                          fontSize: headerSize,
                          height: 24 * scale,
                        ),
                        _TopicHeaderCell(
                          label: 'Acc',
                          flex: 1,
                          fontSize: headerSize,
                          height: 24 * scale,
                        ),
                      ],
                    ),
                    SizedBox(height: 6 * scale),
                    ...widget.topics.map(
                      (topic) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 6 * scale),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                topic.category,
                                style: TextStyle(fontSize: rowSize),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${topic.correct}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: rowSize),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${topic.incorrect}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: rowSize),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${topic.accuracy}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: rowSize),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 6 * scale),
                    Container(
                      height: 8 * scale,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E8EC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 36 * scale,
                          margin: EdgeInsets.all(1.5 * scale),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7A7F88),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16 * scale),
              Center(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 10 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE0E5F1)),
                  ),
                  child: Center(
                    child: Text(
                      'Review Your Answers',
                      style: TextStyle(
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
              SizedBox(height: 12 * scale),
              Center(
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Disclaimer tapped.')),
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
        );
      },
    );
  }
}

class _TopicHeaderCell extends StatelessWidget {
  const _TopicHeaderCell({
    required this.label,
    required this.flex,
    required this.fontSize,
    required this.height,
  });

  final String label;
  final int flex;
  final double fontSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        height: height,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE0E5F1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
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
            Text(
              'Your answer : $userAnswer (Incorrect)',
              style: TextStyle(fontSize: bodySize, color: Colors.red),
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
