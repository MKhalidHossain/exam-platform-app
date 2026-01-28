import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class McqScreen extends StatefulWidget {
  final String courseTitle;

  const McqScreen({
    super.key,
    required this.courseTitle,
  });

  @override
  State<McqScreen> createState() => _McqScreenState();
}

class _McqScreenState extends State<McqScreen> {
  late final List<_Question> _questions;
  int _currentIndex = 0;
  final Map<int, int> _selectedIndex = {};
  final Set<int> _lockedQuestions = {};
  final Set<int> _flaggedQuestions = {};
  bool _showExplanation = false;

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestions();
  }

  List<_Question> _buildQuestions() {
    return List<_Question>.generate(20, (index) {
      return _Question(
        number: index + 1,
        text: 'Q${index + 1}. When I think about my childhood, I feel:',
        options: const [
          'Nostalgic and warm',
          'Disconnected or uncertain',
          'Some unresolved pain or sadness',
          'Grateful for the lessons learned',
        ],
        correctIndex: 2,
        codeReference:
            'API 510, Section 3 (Definitions) - "Alteration"',
        explanation:
            'An alteration is a change that affects the pressure-retaining capability or design conditions of a pressure vessel.\n\nA change in design temperature directly affects allowable stress and MAWP, so it is classified as an alteration.\n\n• D (weld buildup to restore metal loss) is a repair, not an alteration, because it restores the vessel to its original design condition.',
      );
    });
  }

  void _onSelect(int index) {
    if (_lockedQuestions.contains(_currentIndex)) return;
    setState(() {
      _selectedIndex[_currentIndex] = index;
      if (index != _questions[_currentIndex].correctIndex) {
        _lockedQuestions.add(_currentIndex);
      }
    });
  }

  void _onNext() async {
    if (_selectedIndex[_currentIndex] == null) return;
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex += 1;
        _showExplanation = false;
      });
      return;
    }

    if (_selectedIndex.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions first.')),
      );
      return;
    }

    final result = await context.push<Object?>(
      '/exam-review',
      extra: {
        'courseTitle': widget.courseTitle,
        'questions': _questions,
        'selected': _selectedIndex,
        'flagged': _flaggedQuestions,
      },
    );

    if (result is int) {
      setState(() {
        _currentIndex = result.clamp(0, _questions.length - 1);
      });
    }
  }

  void _toggleFlag() {
    setState(() {
      if (_flaggedQuestions.contains(_currentIndex)) {
        _flaggedQuestions.remove(_currentIndex);
      } else {
        _flaggedQuestions.add(_currentIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final _Question question = _questions[_currentIndex];
    final int? selected = _selectedIndex[_currentIndex];
    final bool isFlagged = _flaggedQuestions.contains(_currentIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, size: 22),
                ),
                Expanded(
                  child: Text(
                    widget.courseTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _InfoPill(
                  label: '${_selectedIndex.length}/20 Question Answered',
                ),
                const SizedBox(width: 8),
                _InfoPill(
                  icon: Icons.timer,
                  label: '19 m 20s',
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.volume_up, color: Color(0xFF274B8A)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _questions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final int? selected = _selectedIndex[index];
                  final bool isAnswered = selected != null;
                  final bool isFlag = _flaggedQuestions.contains(index);
                  final bool isCurrent = index == _currentIndex;
                  Color border = const Color(0xFF2D4F88);
                  Color fill = Colors.white;
                  Color textColor = const Color(0xFF111827);

                  if (isAnswered) {
                    final bool isCorrect =
                        selected == _questions[index].correctIndex;
                    if (isCorrect) {
                      fill = const Color(0xFFD8F5D8);
                      border = const Color(0xFF2DBD67);
                      textColor = const Color(0xFF1B6C3E);
                    } else {
                      fill = const Color(0xFFFFD6D6);
                      border = const Color(0xFFE24B4B);
                      textColor = const Color(0xFFB42323);
                    }
                  } else if (isFlag) {
                    fill = const Color(0xFFFFF4D6);
                    border = const Color(0xFFFFB020);
                    textColor = const Color(0xFFB76A00);
                  }
                  if (isCurrent) {
                    border = const Color(0xFF111827);
                  }

                  return GestureDetector(
                    onTap: () => setState(() => _currentIndex = index),
                    child: Container(
                      width: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border, width: 1.2),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              question.text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(question.options.length, (index) {
              final String option = question.options[index];
              final bool isSelected = selected == index;
              final bool isCorrect = index == question.correctIndex;
              final bool locked = _lockedQuestions.contains(_currentIndex);

              Color borderColor = const Color(0xFFE5E7EB);
              Color fillColor = const Color(0xFFF3F4F6);
              Color textColor = const Color(0xFF111827);

              if (selected != null) {
                if (isCorrect) {
                  borderColor = const Color(0xFF2DBD67);
                  fillColor = const Color(0xFFD8F5D8);
                  textColor = const Color(0xFF1B6C3E);
                }
                if (isSelected && !isCorrect) {
                  borderColor = const Color(0xFFE24B4B);
                  fillColor = const Color(0xFFFFD6D6);
                  textColor = const Color(0xFFB42323);
                }
              }

              return GestureDetector(
                onTap: locked ? null : () => _onSelect(index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 1.4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          String.fromCharCode(65 + index),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            Center(
              child: TextButton.icon(
                onPressed: _toggleFlag,
                icon: Icon(
                  Icons.flag,
                  color: isFlagged ? const Color(0xFFB76A00) : Colors.black,
                ),
                label: Text(
                  'Flag',
                  style: TextStyle(
                    color: isFlagged ? const Color(0xFFB76A00) : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFE5E7EB),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _PrimaryButton(
              label: 'Next',
              isEnabled: selected != null,
              onTap: _onNext,
            ),
            const SizedBox(height: 14),
            _DropdownHeader(
              isExpanded: _showExplanation,
              onTap: () => setState(() => _showExplanation = !_showExplanation),
            ),
            if (_showExplanation) ...[
              const SizedBox(height: 12),
              _ReferenceSection(
                reference: question.codeReference,
              ),
              const SizedBox(height: 16),
              _ExplanationSection(text: question.explanation),
            ],
            const SizedBox(height: 18),
            const _DisclaimerSection(),
          ],
        ),
      ),
    );
  }
}

class _Question {
  final int number;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String codeReference;
  final String explanation;

  const _Question({
    required this.number,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.codeReference,
    required this.explanation,
  });
}

class _InfoPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _InfoPill({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: const Color(0xFF1E4C9A)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isEnabled;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.5,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3A7D), Color(0xFF174A97)],
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownHeader extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const _DropdownHeader({
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF2F6DE0), width: 1.5),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'View Explanation \$ Reference',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F6DE0),
              ),
            ),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: const Color(0xFF2F6DE0),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceSection extends StatelessWidget {
  final String reference;

  const _ReferenceSection({required this.reference});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.menu_book, color: Color(0xFF2D4F88)),
            SizedBox(width: 8),
            Text(
              'Code reference',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          reference,
          style: const TextStyle(
            fontSize: 14.5,
            color: Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
        const Divider(height: 20, thickness: 1),
      ],
    );
  }
}

class _ExplanationSection extends StatelessWidget {
  final String text;

  const _ExplanationSection({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.psychology, color: Color(0xFF2D4F88)),
            SizedBox(width: 8),
            Text(
              'Explanation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.4,
            color: Color(0xFF111827),
          ),
        ),
      ],
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
