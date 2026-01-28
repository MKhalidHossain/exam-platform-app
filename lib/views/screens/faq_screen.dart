import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/gradient_background.dart';
import 'package:url_launcher/url_launcher.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

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
                        'FAQ',
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
                      _buildQASection(
                        question: 'What is "Inspector\'s Path"?',
                        answer:
                            '"Inspector\'s Path" is a professional exam-preparation platform for API certification exams. We offer mock exams, study modes, and detailed explanations to help you prepare for your certification.',
                      ),
                      const SizedBox(height: 24),
                      _buildQASection(
                        question: 'Is "Inspector\'s Path" affiliated with API or ASME?',
                        answer:
                            'No. "Inspector\'s Path" is an independent educational platform. We are not affiliated with, endorsed by, or sponsored by API, ASME, or any certification body.',
                      ),
                      const SizedBox(height: 24),
                      _buildQASection(
                        question: 'Which exams are supported?',
                        answer:
                            'We currently support the following exams:\n• API 510 - Pressure Vessels\n• API 570 - Piping\n• API 653 - Storage Tanks\n• API 936 - Refractory Personnel\n• API 1169 - Pipeline\n• SIF/SIRT/SIE - Source Inspection',
                      ),
                      const SizedBox(height: 24),
                      _buildQASection(
                        question: 'Are the questions similar to the real exam?',
                        answer:
                            'Yes. Our questions are designed to match the style, difficulty, and structure of real certification exams, based on applicable codes and standards.',
                      ),
                      const SizedBox(height: 24),
                      _buildQASection(
                        question: 'Does the app guarantee I will pass the exam?',
                        answer:
                            'While we provide comprehensive preparation materials, exam success depends on individual study, experience, and understanding. We cannot guarantee exam results.',
                      ),
                      const SizedBox(height: 24),
                      _buildQASection(
                        question: 'Can I cancel my subscription at any time?',
                        answer:
                            'Yes. You can cancel your subscription at any time from the Subscription page. Your access will continue until the end of the current billing period.',
                      ),
                      const SizedBox(height: 24),
                      _buildQASection(
                        question: 'Will I get a refund if I cancel early?',
                        answer:
                            'No partial refunds are provided for unused time unless required by law.',
                      ),
                      const SizedBox(height: 24),
                      _buildQASection(
                        question: 'Can I change my email or password?',
                        answer:
                            'Yes. You can update both your email and password securely from the Settings page.',
                      ),
                      const SizedBox(height: 24),
                      _buildQASection(
                        question: 'Is my data secure?',
                        answer:
                            'Yes. We use industry-standard security practices to protect your personal and account data.',
                      ),
                      const SizedBox(height: 24),
                      _buildQASection(
                        question: 'How do I contact support?',
                        answer: '',
                        isEmail: true,
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

  Widget _buildQASection({
    required String question,
    required String answer,
    bool isEmail = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Q: $question',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        if (isEmail)
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
          )
        else
          Text(
            answer,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF111827),
              height: 1.5,
            ),
          ),
      ],
    );
  }
}
