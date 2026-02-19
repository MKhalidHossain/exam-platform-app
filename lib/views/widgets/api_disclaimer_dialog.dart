import 'package:flutter/material.dart';

const String kApiFullDisclaimerText =
    '"Inspector\'s Path" is an independent exam-practice platform. This app is not '
    'affiliated with, endorsed by, or sponsored by the American Petroleum Institute '
    '(API). API\u00AE, API 510\u00AE, API 570\u00AE, API 653\u00AE, and related certification '
    'names are registered trademarks of the American Petroleum Institute.';

Future<void> showApiDisclaimerDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Full disclaimer',
    // barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, _) {
      final bottomInset = MediaQuery.of(dialogContext).viewPadding.bottom;
      return SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 26 + bottomInset),
            child: Material(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 36, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      kApiFullDisclaimerText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.28,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF65666B),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F4EA3),
                          side: const BorderSide(
                            color: Color(0xFF0F4EA3),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(34),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Got it'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}
