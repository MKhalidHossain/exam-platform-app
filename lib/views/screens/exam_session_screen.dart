import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExamSessionScreen extends StatelessWidget {
  final String courseTitle;
  final String? examId;
  final int? questionCount;
  final String? effectivitySheetContent;
  final String? bodyOfKnowledgeContent;

  const ExamSessionScreen({
    super.key,
    required this.courseTitle,
    this.examId,
    this.questionCount,
    this.effectivitySheetContent,
    this.bodyOfKnowledgeContent,
  });

  void _showInstructions(
    BuildContext context,
    String sessionLabel,
    String examType,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final effectivity = effectivitySheetContent?.trim() ?? '';
        final bodyOfKnowledge = bodyOfKnowledgeContent?.trim() ?? '';

        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instructions for $courseTitle',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Review the key knowledge areas for this exam before you begin.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This $sessionLabel session focuses on practical application of the API body of knowledge. Expect questions that cover inspection planning, pressure integrity, corrosion assessment, and repair methods. Familiarity with code references and terminology will help you move efficiently through the quiz.\n\nUse the allotted time wisely and review each question carefully before submitting.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Effectivity Sheet',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  effectivity.isNotEmpty
                      ? effectivity
                      : 'No effectivity sheet content available.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Body of Knowledge',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  bodyOfKnowledge.isNotEmpty
                      ? bodyOfKnowledge
                      : 'No body of knowledge content available.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2D4F88)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Back',
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
                          final id = examId?.trim();
                          if (id == null || id.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Exam ID missing. Please try again.',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.of(dialogContext).pop();
                          context.push(
                            '/exam-loading',
                            extra: {
                              'courseTitle': courseTitle,
                              'examId': id,
                              'questionCount': questionCount ?? 1,
                              'examType': examType,
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F3A7D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Start Quiz',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _DisclaimerSection(),
              ],
            ),
          ),
        );
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
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SessionCard(
                      title: 'Open Book\nSession',
                      description:
                          'This session tests your ability to efficiently find and apply information from the official code documents under time pressure.',
                      onTap: () =>
                          _showInstructions(context, 'Open Book', 'open_book'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SessionCard(
                      title: 'Closed Book\nSession',
                      description:
                          'This session tests your foundational knowledge of concepts, definitions, and procedures that you must know from memory.',
                      onTap: () =>
                          _showInstructions(context, 'Closed Book', 'closed_book'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SessionCard(
              title: 'Full Exam Simulation',
              description:
                  'Replicates the complete exam experience, starting with a timed closed-book session, followed by a timed open-book session.',
              isPrimary: true,
              onTap: () => _showInstructions(context, 'Full Exam', 'full_exam'),
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
            const _DisclaimerSection(),
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
    final Color borderColor = isPrimary ? const Color(0xFF1E3C73) : const Color(0xFFE5E7EB);
    final Color titleColor = isPrimary ? Colors.white : const Color(0xFF111827);
    final Color bodyColor = isPrimary ? Colors.white70 : const Color(0xFF4B5563);

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
