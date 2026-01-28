import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExamReviewScreen extends StatelessWidget {
  final String courseTitle;
  final List<dynamic> questions;
  final Map<int, int> selected;
  final Set<int> flagged;

  const ExamReviewScreen({
    super.key,
    required this.courseTitle,
    required this.questions,
    required this.selected,
    required this.flagged,
  });

  @override
  Widget build(BuildContext context) {
    final int total = questions.length;
    final List<int> answered = List<int>.generate(total, (i) => i)
        .where((i) => selected[i] != null)
        .toList();
    final List<int> unanswered = List<int>.generate(total, (i) => i)
        .where((i) => selected[i] == null)
        .toList();
    final List<int> flaggedList = List<int>.generate(total, (i) => i)
        .where((i) => flagged.contains(i))
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
                    onPressed: () => context.pop(),
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
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Final answers submitted.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3A7D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
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
