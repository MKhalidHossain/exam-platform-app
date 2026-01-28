import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExamLoadingScreen extends StatefulWidget {
  final String courseTitle;

  const ExamLoadingScreen({
    super.key,
    required this.courseTitle,
  });

  @override
  State<ExamLoadingScreen> createState() => _ExamLoadingScreenState();
}

class _ExamLoadingScreenState extends State<ExamLoadingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), _goNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goNext() {
    if (!mounted) return;
    context.go(
      '/mcq',
      extra: {'courseTitle': widget.courseTitle},
    );
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
                  'Generating 20 questions for your ${widget.courseTitle} exam... This may take a minute.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
