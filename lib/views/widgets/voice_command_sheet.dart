import 'package:flutter/material.dart';

import '../../controllers/quiz_voice_controller.dart';

/// Bottom sheet that shows the user every voice command supported on the
/// current screen, grouped by purpose.
///
/// Opened by the `help` voice intent and by the help button in the
/// `QuizVoiceOverlay`. Designed to be scannable in 2–3 seconds so the user
/// can pick a command they don't remember.
class VoiceCommandSheet extends StatelessWidget {
  final QuizVoiceScreen screen;

  const VoiceCommandSheet({super.key, required this.screen});

  @override
  Widget build(BuildContext context) {
    final sections = _sectionsFor(screen);
    final media = MediaQuery.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 12,
            bottom: media.viewInsets.bottom + 12,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mic_rounded,
                      color: Color(0xFF2D4F88),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'What can I say?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Tap close or say "stop" to dismiss. Any of these phrases work — '
                  'pick whichever feels natural.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: sections.length,
                  itemBuilder: (context, index) =>
                      _SectionCard(section: sections[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static List<_CommandSection> _sectionsFor(QuizVoiceScreen screen) {
    switch (screen) {
      case QuizVoiceScreen.mcq:
        return _mcqSections;
      case QuizVoiceScreen.examReview:
        return _reviewSections;
      case QuizVoiceScreen.examLoading:
        return _loadingSections;
      case QuizVoiceScreen.examSession:
      case QuizVoiceScreen.quizSettings:
      case QuizVoiceScreen.none:
        return _genericSections;
    }
  }

  static const List<_CommandSection> _mcqSections = [
    _CommandSection(
      icon: Icons.check_circle_outline,
      title: 'Pick an answer',
      examples: [
        '"A"  or  "B"  or  "C"  or  "D"',
        '"The answer is C"',
        '"I think it\'s B"',
        '"Pick option D"',
        '"First option"  /  "Second one"',
        '"True"  /  "False"  (true/false questions)',
      ],
    ),
    _CommandSection(
      icon: Icons.navigation_outlined,
      title: 'Navigate',
      examples: [
        '"Next"  /  "Next question"  /  "Move on"',
        '"Back"  /  "Previous question"',
        '"Question 5"  (jump to a specific question)',
        '"Skip this"',
      ],
    ),
    _CommandSection(
      icon: Icons.replay_rounded,
      title: 'Hear it again',
      examples: [
        '"Repeat"  /  "Read again"  /  "Say it again"',
        '"What did you say?"',
        '"Explain"  /  "Why"  /  "Tell me more"',
      ],
    ),
    _CommandSection(
      icon: Icons.flag_outlined,
      title: 'Flag for later',
      examples: [
        '"Flag"  /  "Flag this question"',
        '"Bookmark"  /  "Mark it"',
        '"Save this"',
      ],
    ),
    _CommandSection(
      icon: Icons.checklist_rounded,
      title: 'Finish or review',
      examples: [
        '"Review"  /  "Open review"',
        '"Submit"  /  "Finish"  /  "I\'m done"',
      ],
    ),
    _CommandSection(
      icon: Icons.speed_rounded,
      title: 'Reading speed',
      examples: [
        '"Faster"  /  "Speak faster"',
        '"Slower"  /  "Slow down"',
        '"Normal speed"  /  "Reset speed"',
      ],
    ),
    _CommandSection(
      icon: Icons.pause_circle_outline_rounded,
      title: 'Stop, pause, exit',
      examples: [
        '"Stop"  (silences reader, mic stays on)',
        '"Pause"  /  "Wait"  /  "Hold on"',
        '"Resume"  /  "Continue"',
        '"Stop voice mode"  (fully exit hands-free)',
      ],
    ),
  ];

  static const List<_CommandSection> _reviewSections = [
    _CommandSection(
      icon: Icons.task_alt_rounded,
      title: 'Submit or wait',
      examples: [
        '"Submit"  /  "Finish"  /  "I\'m done"',
        '"Confirm"  /  "Yes"  /  "Go ahead"  (on confirm dialog)',
        '"No"  /  "Wait"  /  "Nevermind"  (cancel confirm)',
      ],
    ),
    _CommandSection(
      icon: Icons.fact_check_outlined,
      title: 'Review questions',
      examples: [
        '"Show unanswered"  /  "What did I miss"',
        '"Show flagged"  /  "Flagged"',
        '"Back to question"  /  "Return to quiz"',
      ],
    ),
    _CommandSection(
      icon: Icons.replay_rounded,
      title: 'Hear it again',
      examples: [
        '"Repeat"  /  "Read summary"  /  "Say it again"',
      ],
    ),
    _CommandSection(
      icon: Icons.pause_circle_outline_rounded,
      title: 'Stop, pause, exit',
      examples: [
        '"Stop"  (silences reader, mic stays on)',
        '"Pause"  /  "Wait"',
        '"Stop voice mode"  (fully exit hands-free)',
      ],
    ),
  ];

  static const List<_CommandSection> _loadingSections = [
    _CommandSection(
      icon: Icons.refresh_rounded,
      title: 'While waiting',
      examples: [
        '"Status"  /  "What\'s happening"',
        '"Retry"  /  "Try again"',
        '"Cancel"  /  "Back"',
      ],
    ),
  ];

  static const List<_CommandSection> _genericSections = [
    _CommandSection(
      icon: Icons.mic_rounded,
      title: 'Voice commands',
      examples: [
        '"Help"  /  "What can I say"',
        '"Stop voice mode"  to fully exit hands-free',
      ],
    ),
  ];
}

class _CommandSection {
  final IconData icon;
  final String title;
  final List<String> examples;

  const _CommandSection({
    required this.icon,
    required this.title,
    required this.examples,
  });
}

class _SectionCard extends StatelessWidget {
  final _CommandSection section;

  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFE0E7FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  section.icon,
                  color: const Color(0xFF2D4F88),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final example in section.examples) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(
                      Icons.arrow_right_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      example,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
