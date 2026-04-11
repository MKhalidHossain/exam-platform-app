import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/api_disclaimer_section.dart';

class ExamSessionScreen extends StatelessWidget {
  final String courseTitle;
  final String? examId;
  final int? questionCount;
  final int? totalQuestionCount;
  final String? effectivitySheetContent;
  final String? bodyOfKnowledgeContent;
  final bool timedMode;

  const ExamSessionScreen({
    super.key,
    required this.courseTitle,
    this.examId,
    this.questionCount,
    this.totalQuestionCount,
    this.effectivitySheetContent,
    this.bodyOfKnowledgeContent,
    this.timedMode = true,
  });

  void _startQuiz(BuildContext context) {
    final id = examId?.trim();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam ID missing. Please try again.')),
      );
      return;
    }

    context.push(
      '/exam-loading',
      extra: {
        'courseTitle': courseTitle,
        'examId': id,
        'questionCount': questionCount ?? 1,
        'totalQuestionCount': totalQuestionCount ?? questionCount ?? 1,
        'timedMode': timedMode,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const Center(
              child: Text(
                'Quiz Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D4F88),
                ),
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Select Your Exam Session',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                text: 'You are about to start a quiz for the ',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B5563),
                ),
                children: [
                  TextSpan(
                    text: courseTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2F6DE0),
                    ),
                  ),
                  const TextSpan(text: ' certification'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SessionCard(
              title: 'Start Test',
              description:
                  'Begin your full exam simulation with timed closed-book and open-book sections.',
              isPrimary: true,
              onTap: () => _startQuiz(context),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _InfoTile(
                      title: 'Questions',
                      value: '${questionCount ?? 1}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: _InfoTile(title: 'Format', value: 'Full Exam'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2D4F88), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.arrow_back, color: Color(0xFF2D4F88)),
              label: const Text(
                'Back to the Exam selection',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D4F88),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const ApiDisclaimerSection(),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isPrimary;
  final VoidCallback onTap;

  const _SessionCard({
    required this.title,
    required this.description,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isPrimary ? const Color(0xFF274B8A) : Colors.white;
    final Color borderColor = isPrimary
        ? const Color(0xFF1E3C73)
        : const Color(0xFFE5E7EB);
    final Color titleColor = isPrimary ? Colors.white : const Color(0xFF111827);
    final Color bodyColor = isPrimary
        ? Colors.white70
        : const Color(0xFF4B5563);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: bodyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E0F5), width: 1.1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3C73),
            ),
          ),
        ],
      ),
    );
  }
}
