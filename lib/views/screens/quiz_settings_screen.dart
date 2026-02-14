import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/user_controller.dart';
import '../../models/plan_tier.dart';

class QuizSettingsScreen extends StatefulWidget {
  final String courseTitle;
  final String? examId;
  final int? questionCount;
  final String? effectivitySheetContent;
  final String? bodyOfKnowledgeContent;

  const QuizSettingsScreen({
    super.key,
    required this.courseTitle,
    this.examId,
    this.questionCount,
    this.effectivitySheetContent,
    this.bodyOfKnowledgeContent,
  });

  @override
  State<QuizSettingsScreen> createState() => _QuizSettingsScreenState();
}

class _QuizSettingsScreenState extends State<QuizSettingsScreen> {
  double _questionCount = 2;
  bool _timedMode = true;
  final int _monthlyLimit = 15;
  final int _usedForExam = 0;

  @override
  void initState() {
    super.initState();
    final int initialCount = widget.questionCount ?? 2;
    if (initialCount > 0) {
      _questionCount = initialCount.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.isRegistered<UserController>()
        ? Get.find<UserController>()
        : Get.put(UserController());

    return Obx(() {
      final bool isPro = userController.planTier.value == PlanTier.professional;
      final int rawTotalQuestions = widget.questionCount ?? 2;
      final int totalQuestions = rawTotalQuestions > 0 ? rawTotalQuestions : 1;
      final int freeLimit = totalQuestions < 2 ? totalQuestions : 2;
      final int maxSelectable = isPro ? totalQuestions : freeLimit;
      final double effectiveQuestionCount = _questionCount
          .clamp(1, maxSelectable)
          .toDouble();

      return Scaffold(
        backgroundColor: const Color(0xFFF2F5FF),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.arrow_back, size: 22),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Quiz Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D4F88),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoCard(
                backgroundColor: const Color(0xFFE7F0FF),
                borderColor: const Color(0xFFD4E2F7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPro ? 'Professional Plan' : 'Starter Plan Limits',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Questions remaining this month: $_monthlyLimit/$_monthlyLimit',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Questions used for "${widget.courseTitle}": $_usedForExam/$maxSelectable',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Number of Questions: ${effectiveQuestionCount.toInt()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Slider(
                      value: effectiveQuestionCount,
                      min: 1,
                      max: maxSelectable.toDouble(),
                      divisions: maxSelectable > 1 ? maxSelectable - 1 : null,
                      activeColor: const Color(0xFF1E4C9A),
                      inactiveColor: const Color(0xFFE4ECFA),
                      onChanged: isPro
                          ? (value) => setState(() => _questionCount = value)
                          : null,
                    ),
                    Text(
                      isPro
                          ? 'You can access all $totalQuestions question(s) for this exam.'
                          : 'Free users can access $maxSelectable question(s) per session.',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // _InfoCard(
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       const Text(
              //         'Focus on Specific Topics (Optional)',
              //         style: TextStyle(
              //           fontSize: 20,
              //           fontWeight: FontWeight.w700,
              //           color: Color(0xFF111827),
              //         ),
              //       ),
              //       const SizedBox(height: 8),
              //       TextField(
              //         enabled: false,
              //         decoration: InputDecoration(
              //           hintText: 'e.g., welding, NDE, corrosion',
              //           hintStyle: const TextStyle(
              //             color: Color(0xFF9CA3AF),
              //             fontWeight: FontWeight.w500,
              //           ),
              //           filled: true,
              //           fillColor: const Color(0xFFF8FAFF),
              //           disabledBorder: OutlineInputBorder(
              //             borderRadius: BorderRadius.circular(14),
              //             borderSide: const BorderSide(color: Color(0xFFC8D3E7)),
              //           ),
              //         ),
              //       ),
              //       const SizedBox(height: 8),
              //       const Text(
              //         'Upgrade to a paid plan to use this feature.',
              //         style: TextStyle(
              //           fontSize: 13,
              //           fontWeight: FontWeight.w500,
              //           color: Color(0xFF6B7280),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              const SizedBox(height: 16),
              _InfoCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Enable Timed Mode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Switch(
                      value: _timedMode,
                      activeThumbColor: const Color(0xFF2F6DE0),
                      onChanged: (value) => setState(() => _timedMode = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _PrimaryButton(
                label: 'Start Quiz',
                onTap: () {
                  final examId = widget.examId?.trim();
                  if (examId == null || examId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Exam ID missing. Please try again.'),
                      ),
                    );
                    return;
                  }
                  context.push(
                    '/exam-session',
                    extra: {
                      'courseTitle': widget.courseTitle,
                      'examId': examId,
                      'questionCount': effectiveQuestionCount.toInt(),
                      'effectivitySheetContent': widget.effectivitySheetContent,
                      'bodyOfKnowledgeContent': widget.bodyOfKnowledgeContent,
                      'timedMode': _timedMode,
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              const _DisclaimerSection(),
            ],
          ),
        ),
      );
    });
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;

  const _InfoCard({
    required this.child,
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFE5E7EB),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F3A7D), Color(0xFF174A97)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Colors.white),
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
