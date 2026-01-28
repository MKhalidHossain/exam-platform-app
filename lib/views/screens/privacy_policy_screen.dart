import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/gradient_background.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
                      color: const Color(0xFF2D4F88),
                    ),
                    const Expanded(
                      child: Text(
                        'Privacy policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D4F88),
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
                        'Explain how \'Inspector\'s Path\' collects, uses, protects and respects user data.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '1. Introduction',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '\'Inspector\'s Path\' is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and related services.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please read this Privacy Policy carefully. By using our app, you agree to the collection and use of information in accordance with this policy.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '2. Information We Collect',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'A. Personal Information We may collect:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Fullname'),
                      _buildBulletPoint('Email address'),
                      _buildBulletPoint('Phone number'),
                      _buildBulletPoint('Profile photo'),
                      _buildBulletPoint('Subscription and billing information'),
                      const SizedBox(height: 12),
                      const Text(
                        'B. Account & Usage Data:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Exam attempts and scores'),
                      _buildBulletPoint('Study history and progress'),
                      _buildBulletPoint('App interactions and preferences'),
                      _buildBulletPoint('Device type and operating system (for performance and security)'),
                      const SizedBox(height: 12),
                      const Text(
                        'C. Payment Information:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Payment details are processed securely by third-party payment providers. We do not store your full credit or debit card numbers.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '3. How We Use Your information We use your information to:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Provide and improve exam preparation services'),
                      _buildBulletPoint('Personalize your learning experience'),
                      _buildBulletPoint('Track progress and exam history'),
                      _buildBulletPoint('Manage subscriptions and billing'),
                      _buildBulletPoint('Communicate important updates (account, security, or service-related)'),
                      const SizedBox(height: 24),
                      const Text(
                        '4. Data Sharing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We do not sell or rent your personal data. Data may be shared only with:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Payment processors (for billing)'),
                      _buildBulletPoint('Authentication providers (for secure login)'),
                      _buildBulletPoint('Legal authorities, if required by law'),
                      const SizedBox(height: 24),
                      const Text(
                        '5. Data Security',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We use Industry-standard security measures including:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Encrypted data transmission'),
                      _buildBulletPoint('Secure authentication'),
                      _buildBulletPoint('Restricted internal access'),
                      const SizedBox(height: 8),
                      const Text(
                        'While we strive to protect your personal information, no method of transmission over the Internet or electronic storage is 100% secure. We take reasonable steps to protect your information.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '6. Data Retention',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Account data is retained while your account is active'),
                      _buildBulletPoint('You may request deletion of your account and associated data at any time'),
                      const SizedBox(height: 24),
                      const Text(
                        '7. Your Rights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You have the right to:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Access your personal data'),
                      _buildBulletPoint('Update or correct your information'),
                      _buildBulletPoint('Request deletion of your account'),
                      const SizedBox(height: 24),
                      const Text(
                        '8. Changes to This Policy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy within the app. You are advised to review this Privacy Policy periodically for any changes.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '9. Contact Us',
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
