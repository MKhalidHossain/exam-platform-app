import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/error/error_handler.dart';
import '../../services/exam_service.dart';

class ExamLoadingScreen extends StatefulWidget {
  final String courseTitle;
  final String? examId;
  final int? questionCount;
  final String? examType;

  const ExamLoadingScreen({
    super.key,
    required this.courseTitle,
    this.examId,
    this.questionCount,
    this.examType,
  });

  @override
  State<ExamLoadingScreen> createState() => _ExamLoadingScreenState();
}

class _ExamLoadingScreenState extends State<ExamLoadingScreen> {
  final ExamService _examService = ExamService();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startExam();
  }

  Future<void> _startExam() async {
    final examId = widget.examId?.trim();
    if (examId == null || examId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Exam ID missing. Please go back and try again.';
      });
      return;
    }

    final int questionCount = widget.questionCount ?? 1;
    final response = await _examService.startExam(
      examId: examId,
      questionCount: questionCount,
      recreate: false,
      examType: widget.examType,
    );

    if (!mounted) return;

    if (response.success && response.data != null) {
      context.go(
        '/mcq',
        extra: {
          'courseTitle': widget.courseTitle,
          'examId': examId,
          'questions': response.data!.questions,
          'startTime': response.data!.startTime,
          'endTime': response.data!.endTime,
          'durationMinutes': response.data!.durationMinutes,
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
                  const SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      strokeWidth: 8,
                      color: Color(0xFF1E4C9A),
                      backgroundColor: Color(0xFFD5D8DE),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                  const Icon(Icons.error_outline,
                      size: 48, color: Color(0xFFE24B4B)),
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
                  ElevatedButton(
                    onPressed: () {
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
