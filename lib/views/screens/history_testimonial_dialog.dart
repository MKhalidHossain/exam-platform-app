import 'package:flutter/material.dart';
import '../../core/error/error_handler.dart';
import '../../services/exam_service.dart';
import '../widgets/api_disclaimer_section.dart';

class HistoryTestimonialDialog extends StatefulWidget {
  const HistoryTestimonialDialog({
    super.key,
    required this.examId,
    required this.onSubmitted,
    required this.onSkip,
  });

  final String examId;
  final VoidCallback onSubmitted;
  final VoidCallback onSkip;

  @override
  State<HistoryTestimonialDialog> createState() =>
      _HistoryTestimonialDialogState();
}

class _HistoryTestimonialDialogState extends State<HistoryTestimonialDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ExamService _examService = ExamService();
  late final TextEditingController _nameController;
  late final TextEditingController _testimonialController;
  int _selectedStars = 5;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _testimonialController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _testimonialController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final examId = widget.examId.trim();
    if (examId.isEmpty) {
      ErrorHandler.showSnackBar(
        'Exam ID missing. Please try again.',
        isError: true,
        context: context,
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    final feedbackText = _testimonialController.text.trim();
    final name = _nameController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final response = await _examService.submitExamReview(
        examId: examId,
        stars: _selectedStars,
        feedbackText: feedbackText,
        name: name,
      );

      if (!mounted) return;
      if (response.success) {
        Navigator.of(context).pop();
        widget.onSubmitted();
        return;
      }

      ErrorHandler.showFromResponse(
        response,
        context: context,
        failureFallback: 'Failed to submit testimonial. Please try again.',
      );
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showFromException(
        e,
        context: context,
        fallback: 'Failed to submit testimonial. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Great Job!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF202B3C),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "You're amazing! Would you be willing to share a few\n"
                "words about your experience to help others on their\n"
                'certification journey?',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF6C7685),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Rate 1 to 5 stars',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF202B3C),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (index) {
                  final isSelected = index < _selectedStars;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.star,
                        size: 28,
                        color: isSelected
                            ? const Color(0xFFFFB233)
                            : const Color(0xFFB8BDC8),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _selectedStars = index + 1),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your Testimonial',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF202B3C),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _testimonialController,
                maxLines: 3,
                minLines: 3,
                textInputAction: TextInputAction.newline,
                validator: (value) => _validateRequired(value, 'Testimonial'),
                decoration: InputDecoration(
                  hintText:
                      'e.g., This platform was a game-changer for my\nexam preparation.',
                  hintStyle: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9AA3B2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFD5DAE6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFD5DAE6)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your Name',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF202B3C),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                validator: (value) => _validateRequired(value, 'Name'),
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'e.g., Khalid Hossain',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2F5BD5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2F5BD5)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : widget.onSkip,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E4AA8),
                        side: const BorderSide(color: Color(0xFF1E4AA8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'No, Thanks',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E4AA8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit Testimonial',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const ApiDisclaimerSection(
                baseStyle: TextStyle(fontSize: 10, color: Color(0xFF6C7685)),
                linkStyle: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF1E6CF3),
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
