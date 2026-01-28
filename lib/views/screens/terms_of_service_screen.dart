import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/gradient_background.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        useImage: true,
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                      color: const Color(0xFF111827),
                    ),
                    const Expanded(
                      child: Text(
                        'Terms & Conditions',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Purpose',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Establish the legal and usage terms governing \'Inspector\'s Path\', while protecting both the user and the platform.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '1. Acceptance of Terms',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'By accessing or using \'Inspector\'s Path\', you agree to be bound by these Terms and Conditions. If you do not agree with any part of these terms, you must not use the application.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '2. Use of the Service',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You agree to:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Use the app for personal, educational purposes only'),
                      _buildBulletPoint('Not reproduce, distribute, or resell any content from the app'),
                      _buildBulletPoint('Not attempt to reverse-engineer, decompile, or misuse the platform'),
                      const SizedBox(height: 24),
                      const Text(
                        '3. Account Responsibility',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You are responsible for:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Maintaining the confidentiality of your login credentials'),
                      _buildBulletPoint('All activities that occur under your account'),
                      _buildBulletPoint('Notifying us immediately of any unauthorized access'),
                      const SizedBox(height: 24),
                      const Text(
                        '4. Intellectual Property',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All content within \'Inspector\'s Path\', including but not limited to exam questions, explanations, UI designs, logos, and branding, is the exclusive property of \'Inspector\'s Path\' and protected by copyright and intellectual property laws.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '5. Subscriptions & Payments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Subscription terms:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Subscription fees are billed in advance'),
                      _buildBulletPoint('Prices may change with prior notice'),
                      _buildBulletPoint('No refunds for partially used subscription periods unless required by law'),
                      const SizedBox(height: 24),
                      const Text(
                        '6. Disclaimer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '\'Inspector\'s Path\' does not:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Guarantee certification or exam success'),
                      _buildBulletPoint('Affiliate with API, ASME, or any certification body'),
                      _buildBulletPoint('Provide anything other than educational content'),
                      const SizedBox(height: 24),
                      const Text(
                        '7. Limitation of Liability',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '\'Inspector\'s Path\' shall not be liable for:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Exam outcomes or results'),
                      _buildBulletPoint('Lost certification opportunities'),
                      _buildBulletPoint('Indirect or consequential damages'),
                      const SizedBox(height: 8),
                      const Text(
                        'Use of the app is at your own risk.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '8. Termination',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We reserve the right to suspend or terminate your account if you violate these Terms and Conditions, without prior notice.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '9. Governing Law',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'These Terms and Conditions are governed by the laws of the applicable jurisdiction where \'Inspector\'s Academy\' operates.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '10. Contact Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'For privacy-related questions:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _launchEmail('contact@inspectorspath.com'),
                        child: const Text(
                          'contact@inspectorspath.com',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2D4F88),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF111827),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF111827),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
