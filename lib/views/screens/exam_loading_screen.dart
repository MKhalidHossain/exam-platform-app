import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:get/get.dart';
import '../../core/error/error_handler.dart';
import '../../controllers/user_controller.dart';
import '../../models/plan_tier.dart';
import '../../services/exam_service.dart';

class ExamLoadingScreen extends StatefulWidget {
  final String courseTitle;
  final String? examId;
  final int? questionCount;
  final bool timedMode;
  final bool regenerate;

  const ExamLoadingScreen({
    super.key,
    required this.courseTitle,
    this.examId,
    this.questionCount,
    this.timedMode = true,
    this.regenerate = false,
  });

  @override
  State<ExamLoadingScreen> createState() => _ExamLoadingScreenState();
}

class _ExamLoadingScreenState extends State<ExamLoadingScreen> {
  final ExamService _examService = ExamService();
  bool _isLoading = true;
  String? _errorMessage;

  bool _isLimitMessage(String? message) {
    if (message == null) return false;
    final lowered = message.toLowerCase();
    return lowered.contains('monthly free questions limit') ||
        lowered.contains('monthly free question limit') ||
        lowered.contains('free questions limit') ||
        lowered.contains('monthly limit') ||
        lowered.contains('purchase to unlock');
  }

  bool _isTimeoutMessage(String? message) {
    if (message == null) return false;
    final lowered = message.toLowerCase();
    return lowered.contains('timeout') || lowered.contains('took too long');
  }

  bool _isQuestionServiceError(String? message) {
    if (message == null) return false;
    final lowered = message.toLowerCase();
    return lowered.contains('question service') ||
        lowered.contains('question generation') ||
        lowered.contains('temporarily unavailable');
  }

  @override
  void initState() {
    super.initState();
    _startExam();
  }

  static const int _maxRetriesFor502 = 2;
  static const Duration _retryDelay502 = Duration(seconds: 12);

  Future<void> _startExam({int retryCount = 0}) async {
    final examId = widget.examId?.trim();
    if (examId == null || examId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Exam ID missing. Please go back and try again.';
      });
      return;
    }

    final int questionCount = widget.questionCount ?? 1;
    final UserController userController = Get.isRegistered<UserController>()
        ? Get.find<UserController>()
        : Get.put(UserController());
    final bool isPro = userController.planTier.value == PlanTier.professional;
    final bool effectiveTimedMode = widget.timedMode && isPro;
    final response = await _examService.startExam(
      examId: examId,
      questionCount: questionCount,
      regenerate: widget.regenerate,
    );

    if (!mounted) return;

    if (response.statusCode == 403) {
      context.go('/subscribe');
      return;
    }

    // 502 often means question service (e.g. Render) is cold-starting.
    // Auto-retry after a short delay.
    if (!response.success &&
        response.statusCode == 502 &&
        retryCount < _maxRetriesFor502) {
      await Future<void>.delayed(_retryDelay502);
      if (!mounted) return;
      return _startExam(retryCount: retryCount + 1);
    }

    if (response.success && response.data != null) {
      DateTime? startTime;
      DateTime? endTime;
      int? durationMinutes;
      if (effectiveTimedMode) {
        durationMinutes = response.data!.durationMinutes;
        startTime = DateTime.now();
        if (durationMinutes != null && durationMinutes > 0) {
          endTime = startTime.add(Duration(minutes: durationMinutes));
        }
      }
      final int sessionId = DateTime.now().millisecondsSinceEpoch;
      context.go(
        '/mcq',
        extra: {
          'courseTitle': widget.courseTitle,
          'examId': examId,
          'questions': response.data!.questions,
          'startTime': startTime,
          'endTime': endTime,
          'durationMinutes': durationMinutes,
          'timedMode': effectiveTimedMode,
          'sessionId': sessionId,
        },
      );
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = ErrorHandler.getMessageFromResponse(
        response,
        failureFallback: 'Failed to start the exam. Please try again.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                if (_isLoading) ...[
                  SizedBox(
                    width: 250,
                    height: 240,
                    child: Lottie.asset(
                      'assets/lottie/loading_run.json',
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Generating ${widget.questionCount ?? 1} questions for your ${widget.courseTitle} exam... This may take a minute.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      height: 1.35,
                    ),
                  ),
                ] else ...[
                  if (_isQuestionServiceError(_errorMessage) ||
                      _isTimeoutMessage(_errorMessage)) ...[
                    SizedBox(
                      width: 220,
                      height: 120,
                      child: Lottie.asset(
                        'assets/lottie/timeout.json',
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Timeout. ',
                            style: TextStyle(color: Color(0xFFE24B4B)),
                          ),
                          const TextSpan(
                            text: 'Try again',
                            style: TextStyle(color: Color(0xFF1E4C9A)),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ] else ...[
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Color(0xFFE24B4B),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Something went wrong.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  ElevatedButton(
                    onPressed: () {
                      if (_isLimitMessage(_errorMessage)) {
                        context.go('/subscribe');
                        return;
                      }
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      _startExam();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E4C9A),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
