import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/payment_success_details.dart';

class ExamUnlockSuccessScreen extends StatelessWidget {
  final String courseTitle;
  final String examId;
  final int? questionCount;
  final String? effectivitySheetContent;
  final String? bodyOfKnowledgeContent;
  final PaymentSuccessDetails paymentDetails;

  const ExamUnlockSuccessScreen({
    super.key,
    required this.courseTitle,
    required this.examId,
    this.questionCount,
    this.effectivitySheetContent,
    this.bodyOfKnowledgeContent,
    required this.paymentDetails,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPlanPurchase = paymentDetails.purchaseType == 'plan';
    final String purchaseTitle = paymentDetails.title.trim().isEmpty
        ? (isPlanPurchase ? 'Professional Plan' : courseTitle)
        : paymentDetails.title.trim();
    final String amountLabel = _formatMoney(
      paymentDetails.amountPaid,
      paymentDetails.currency,
    );
    final String providerLabel =
        _formatProvider(paymentDetails.provider) ?? 'Stripe';
    final String paymentMethodLabel =
        paymentDetails.paymentMethodLabel?.trim().isNotEmpty ?? false
        ? paymentDetails.paymentMethodLabel!.trim()
        : (providerLabel == 'PayPal' ? 'PayPal' : 'Card');
    final String receiptLabel =
        paymentDetails.receiptNumber?.trim().isNotEmpty ?? false
        ? paymentDetails.receiptNumber!.trim()
        : 'Pending';
    final String transactionLabel =
        paymentDetails.transactionReference?.trim().isNotEmpty ?? false
        ? paymentDetails.transactionReference!.trim()
        : 'Pending';
    final String statusLabel = paymentDetails.status?.trim().isNotEmpty ?? false
        ? _titleCase(paymentDetails.status!)
        : 'Successful';
    final DateTime paidAt = paymentDetails.paidAt ?? DateTime.now();
    final String durationLabel = isPlanPurchase
        ? (paymentDetails.billingCycleLabel?.trim().isNotEmpty ?? false
              ? paymentDetails.billingCycleLabel!.trim()
              : 'Pending')
        : 'Lifetime access';
    final DateTime? resolvedNextBillingDate =
        paymentDetails.nextBillingDate ??
        _inferNextBillingDate(
          startDate: paymentDetails.subscriptionStartedAt ?? paidAt,
          durationLabel: paymentDetails.billingCycleLabel,
        );
    final String nextBillingLabel = isPlanPurchase
        ? (resolvedNextBillingDate != null
              ? _formatDate(resolvedNextBillingDate)
              : 'Pending')
        : 'Not applicable';
    final List<MapEntry<String, String>> summaryRows =
        <MapEntry<String, String>>[
          MapEntry(
            isPlanPurchase ? 'Plan' : 'Exam',
            isPlanPurchase ? purchaseTitle : courseTitle,
          ),
          MapEntry(
            isPlanPurchase ? 'Amount Paid Today' : 'Amount Paid',
            amountLabel,
          ),
          MapEntry('Duration', durationLabel),
          if (isPlanPurchase && paymentDetails.subscriptionStartedAt != null)
            MapEntry(
              'Activated On',
              _formatDate(paymentDetails.subscriptionStartedAt!),
            ),
          MapEntry('Next Billing Date', nextBillingLabel),
          MapEntry('Payment Method', paymentMethodLabel),
          MapEntry('Provider', providerLabel),
          MapEntry('Receipt #', receiptLabel),
          if (transactionLabel != receiptLabel)
            MapEntry('Transaction ID', transactionLabel),
          MapEntry('Paid On', _formatDate(paidAt)),
          MapEntry('Status', statusLabel),
        ];

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
                    'Payment successful',
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
                      color: const Color(0xFF2DBD67).withValues(alpha: 0.15),
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
            Center(
              child: Text(
                isPlanPurchase
                    ? 'Upgrade successfully'
                    : 'Exam unlocked successfully',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                isPlanPurchase
                    ? 'You’re now on the $purchaseTitle. Your subscription is\nactive and premium features are unlocked.'
                    : 'Your payment is complete. This exam is now unlocked\nand ready to start.',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
            ...summaryRows.map(
              (row) => _SummaryRow(label: row.key, value: row.value),
            ),
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

  static String _formatMoney(num amount, String currency) {
    final String upperCurrency = currency.toUpperCase();
    if (upperCurrency == 'USD') {
      return '\$${amount.toStringAsFixed(2)}';
    }
    return '$upperCurrency ${amount.toStringAsFixed(2)}';
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final month = months[local.month - 1];
    return '$month ${local.day}, ${local.year}';
  }

  static DateTime? _inferNextBillingDate({
    required DateTime startDate,
    required String? durationLabel,
  }) {
    final text = durationLabel?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return null;

    final match = RegExp(
      r'(\d+)\s+(day|days|month|months|year|years)',
    ).firstMatch(text);
    if (match == null) return null;

    final count = int.tryParse(match.group(1) ?? '');
    final unit = match.group(2) ?? '';
    if (count == null || count <= 0) return null;

    switch (unit) {
      case 'day':
      case 'days':
        return startDate.add(Duration(days: count));
      case 'month':
      case 'months':
        return DateTime(
          startDate.year,
          startDate.month + count,
          startDate.day,
          startDate.hour,
          startDate.minute,
          startDate.second,
          startDate.millisecond,
          startDate.microsecond,
        );
      case 'year':
      case 'years':
        return DateTime(
          startDate.year + count,
          startDate.month,
          startDate.day,
          startDate.hour,
          startDate.minute,
          startDate.second,
          startDate.millisecond,
          startDate.microsecond,
        );
      default:
        return null;
    }
  }

  static String? _formatProvider(String? provider) {
    final normalized = provider?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return null;
    switch (normalized) {
      case 'stripe':
        return 'Stripe';
      case 'paypal':
        return 'PayPal';
      case 'manual':
        return 'Manual';
      default:
        return _titleCase(normalized);
    }
  }

  static String _titleCase(String value) {
    return value
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
