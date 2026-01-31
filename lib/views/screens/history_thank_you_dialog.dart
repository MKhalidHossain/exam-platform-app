import 'package:flutter/material.dart';

class HistoryThankYouDialog extends StatelessWidget {
  const HistoryThankYouDialog({
    super.key,
    required this.onBackToExam,
  });

  final VoidCallback onBackToExam;

  @override
  Widget build(BuildContext context) {
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
              onPressed: onBackToExam,
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
  }
}
