import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExamUnlockSuccessScreen extends StatelessWidget {
  final String courseTitle;
  final String examId;
  final int? questionCount;
  final String? effectivitySheetContent;
  final String? bodyOfKnowledgeContent;
  final int amountPaid;

  const ExamUnlockSuccessScreen({
    super.key,
    required this.courseTitle,
    required this.examId,
    this.questionCount,
    this.effectivitySheetContent,
    this.bodyOfKnowledgeContent,
    this.amountPaid = 150,
  });

  @override
  Widget build(BuildContext context) {
    final String amountLabel =
        '\$${amountPaid.toDouble().toStringAsFixed(2)}';

    return Scaffold(
      backgroundColor: const Color(0xFFEAF0FF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, size: 22),
                  color: const Color(0xFF2D4F88),
                ),
                const Expanded(
                  child: Text(
                    'Upgrade successfully',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D4F88),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2DBD67).withOpacity(0.15),
                    ),
                  ),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2DBD67),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Upgrade successfully',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'You’re now on the Professional Plan. Your Subscription is\nactive and premium Features are unlocked.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),
            _SummaryRow(label: 'Plan', value: 'Professional'),
            _SummaryRow(label: 'Amount Paid Today', value: amountLabel),
            const _SummaryRow(label: 'Next Billing Date', value: '6 Month'),
            const _SummaryRow(label: 'Payment Method', value: 'Card **** 1234'),
            const _SummaryRow(label: 'Receipt #', value: 'INV - 000124'),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () {
                context.go(
                  '/quiz-settings',
                  extra: {
                    'courseTitle': courseTitle,
                    'examId': examId,
                    'questionCount': questionCount,
                    'effectivitySheetContent': effectivitySheetContent,
                    'bodyOfKnowledgeContent': bodyOfKnowledgeContent,
                  },
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2D4F88), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: const Color(0xFF2D4F88),
                backgroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text(
                'Back to Exam',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
