import 'package:flutter/material.dart';

class HistoryTestimonialDialog extends StatefulWidget {
  const HistoryTestimonialDialog({
    super.key,
    required this.onSubmit,
    required this.onSkip,
  });

  final VoidCallback onSubmit;
  final VoidCallback onSkip;

  @override
  State<HistoryTestimonialDialog> createState() =>
      _HistoryTestimonialDialogState();
}

class _HistoryTestimonialDialogState extends State<HistoryTestimonialDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _testimonialController;
  int _selectedStars = 3;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Butlar Mane');
    _testimonialController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _testimonialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
                    onPressed: () =>
                        setState(() => _selectedStars = index + 1),
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
            TextField(
              controller: _testimonialController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'e.g., This platform was a game-changer for my\nexam preparation.',
                hintStyle: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9AA3B2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    onPressed: widget.onSkip,
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
                    onPressed: widget.onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E4AA8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Submit Testimonial',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Disclaimer tapped.')),
                  );
                },
                child: const Text.rich(
                  TextSpan(
                    text: 'Not affiliated with or endorsed by API. ',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6C7685),
                    ),
                    children: [
                      TextSpan(
                        text: 'See full\n',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF1E6CF3),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      TextSpan(
                        text: 'disclaimer.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF1E6CF3),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
