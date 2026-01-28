import 'package:flutter/material.dart';
import 'home_screen.dart';

class NavbarScreen extends StatefulWidget {
  final PlanTier planTier;
  final Set<String> unlockedCourseIds;

  const NavbarScreen({
    super.key,
    this.planTier = PlanTier.starter,
    this.unlockedCourseIds = const {'api510'},
  });

  @override
  State<NavbarScreen> createState() => _NavbarScreenState();
}

class _NavbarScreenState extends State<NavbarScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            planTier: widget.planTier,
            unlockedCourseIds: widget.unlockedCourseIds,
          ),
          const _HistoryTab(),
          const _ProfileTab(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: _BottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF2D4F88),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332F3E6B),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _NavItem(
            index: 0,
            currentIndex: currentIndex,
            icon: Icons.home_filled,
            label: 'Home',
            onTap: onTap,
          ),
          _NavItem(
            index: 1,
            currentIndex: currentIndex,
            icon: Icons.history,
            label: 'History',
            onTap: onTap,
          ),
          _NavItem(
            index: 2,
            currentIndex: currentIndex,
            icon: Icons.person_outline,
            label: 'Profile',
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final String label;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = index == currentIndex;
    final Color color = isSelected ? Colors.white : Colors.white70;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final List<_HistoryEntry> _history = const [
    _HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    _HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    _HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    _HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    _HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    _HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    _HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    _HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    _HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/9/2026, 4:00:18 PM',
      scorePercent: 30.0,
      scoreDetail: '3/10',
    ),
    _HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/9/2026, 2:46:37 PM',
      scorePercent: 20.0,
      scoreDetail: '2/10',
    ),
  ];

  final List<_TopicBreakdown> _topics = const [
    _TopicBreakdown(
      category: 'Preheating and Heat\nTreatment',
      correct: 0,
      incorrect: 0,
      accuracy: 1,
    ),
    _TopicBreakdown(
      category: 'Corrosion Rates and\nInspection Intervals',
      correct: 0,
      incorrect: 0,
      accuracy: 1,
    ),
    _TopicBreakdown(
      category: 'Weld Joint Quality\nFactors',
      correct: 0,
      incorrect: 0,
      accuracy: 1,
    ),
    _TopicBreakdown(
      category: 'Internal Pressure /\nMinimum Thickness of\nPipe',
      correct: 0,
      incorrect: 0,
      accuracy: 1,
    ),
    _TopicBreakdown(
      category: 'Pressure Testing',
      correct: 0,
      incorrect: 0,
      accuracy: 1,
    ),
    _TopicBreakdown(
      category: 'Thermal Expansion',
      correct: 0,
      incorrect: 0,
      accuracy: 1,
    ),
    _TopicBreakdown(
      category: 'Blanks',
      correct: 1,
      incorrect: 1,
      accuracy: 1,
    ),
    _TopicBreakdown(
      category: 'Impact Testing',
      correct: 1,
      incorrect: 1,
      accuracy: 1,
    ),
    _TopicBreakdown(
      category: 'Flanges',
      correct: 1,
      incorrect: 1,
      accuracy: 1,
    ),
  ];

  _HistoryEntry? _selectedEntry;
  String _selectedFilter = 'All Exams';

  @override
  Widget build(BuildContext context) {
    final List<_HistoryEntry> filtered = _selectedFilter == 'All Exams'
        ? _history
        : _history
            .where((entry) => entry.examName == _selectedFilter)
            .toList();

    return SafeArea(
      child: _selectedEntry == null
          ? _HistoryListView(
              entries: filtered,
              filterValue: _selectedFilter,
              onFilterChanged: (value) =>
                  setState(() => _selectedFilter = value),
              onSelect: (entry) =>
                  setState(() => _selectedEntry = entry),
            )
          : _HistoryDetailView(
              entry: _selectedEntry!,
              topics: _topics,
              onBack: () => setState(() => _selectedEntry = null),
            ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Text(
          'Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HistoryListView extends StatelessWidget {
  const _HistoryListView({
    required this.entries,
    required this.filterValue,
    required this.onFilterChanged,
    required this.onSelect,
  });

  final List<_HistoryEntry> entries;
  final String filterValue;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<_HistoryEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final double scale = (width / 375).clamp(0.85, 1.15);
        final double hPad = 16 * scale;
        final double titleSize = 16 * scale;
        final double subtitleSize = 13 * scale;
        final double headerSize = 11 * scale;
        final double rowTitleSize = 11 * scale;
        final double rowDateSize = 10 * scale;
        final double rowScoreSize = 11 * scale;
        final double topPad = 8 * scale;
        final double bottomPad = 12 * scale;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hPad - 4, topPad, hPad, bottomPad),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: const Color(0xFF27407C),
                  ),
                  Text(
                    'History',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF27407C),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                children: [
                  Text(
                    'Consolidated Quiz History',
                    style: TextStyle(
                      fontSize: subtitleSize,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF202B3C),
                    ),
                  ),
                  const Spacer(),
                  _ExamFilterMenu(
                    value: filterValue,
                    options: const [
                      'All Exams',
                      'API 570 - Piping Inspector',
                      'API 510 - Pressure Vessel',
                    ],
                    maxWidth: 140 * scale,
                    onSelected: onFilterChanged,
                  ),
                ],
              ),
            ),
            SizedBox(height: 12 * scale),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          12 * scale,
                          12 * scale,
                          12 * scale,
                          8 * scale,
                        ),
                        child: Row(
                          children: [
                            _HeaderChip(
                              label: 'EXAM',
                              fontSize: headerSize,
                              height: 28 * scale,
                            ),
                            SizedBox(width: 8 * scale),
                            _HeaderChip(
                              label: 'DATE',
                              fontSize: headerSize,
                              height: 28 * scale,
                            ),
                            SizedBox(width: 8 * scale),
                            _HeaderChip(
                              label: 'SCORE',
                              fontSize: headerSize,
                              height: 28 * scale,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE4E8F2)),
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final Color scoreColor = entry.scorePercent <= 20
                                ? const Color(0xFFE53935)
                                : entry.scorePercent <= 30
                                    ? const Color(0xFFFF8A00)
                                    : const Color(0xFFFF4D4D);
                            return InkWell(
                              onTap: () => onSelect(entry),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 10 * scale,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        entry.examName,
                                        style: TextStyle(
                                          fontSize: rowTitleSize,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF2A3240),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        entry.date.replaceFirst(', ', ',\n'),
                                        textAlign: TextAlign.center,
                                        softWrap: true,
                                        style: TextStyle(
                                          fontSize: rowDateSize,
                                          color: const Color(0xFF6C7685),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${entry.scorePercent.toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontSize: rowScoreSize,
                                              fontWeight: FontWeight.w700,
                                              color: scoreColor,
                                            ),
                                          ),
                                          Text(
                                            entry.scoreDetail,
                                            style: TextStyle(
                                              fontSize: rowDateSize,
                                              color: const Color(0xFF6C7685),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: Color(0xFFE4E8F2),
                          ),
                          itemCount: entries.length,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 12 * scale),
          ],
        );
      },
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.label,
    required this.fontSize,
    required this.height,
  });

  final String label;
  final double fontSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1E5EF)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2A3240),
          ),
        ),
      ),
    );
  }
}

class _ExamFilterMenu extends StatefulWidget {
  const _ExamFilterMenu({
    required this.value,
    required this.options,
    required this.maxWidth,
    required this.onSelected,
  });

  final String value;
  final List<String> options;
  final double maxWidth;
  final ValueChanged<String> onSelected;

  @override
  State<_ExamFilterMenu> createState() => _ExamFilterMenuState();
}

class _ExamFilterMenuState extends State<_ExamFilterMenu> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        widget.onSelected(value);
      },
      itemBuilder: (context) => widget.options
          .map(
            (option) => PopupMenuItem<String>(
              value: option,
              child: Text(option, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E4AA8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxWidth),
              child: Text(
                widget.value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _HistoryDetailView extends StatelessWidget {
  const _HistoryDetailView({
    required this.entry,
    required this.topics,
    required this.onBack,
  });

  final _HistoryEntry entry;
  final List<_TopicBreakdown> topics;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double scale = (constraints.maxWidth / 375).clamp(0.85, 1.15);
        final double hPad = 12 * scale;
        final double titleSize = 15 * scale;
        final double captionSize = 10.5 * scale;
        final double scoreSize = 22 * scale;
        final double buttonSize = 12 * scale;
        final double sectionTitle = 14 * scale;
        final double headerSize = 9.5 * scale;
        final double rowSize = 10 * scale;
        final double cardTitle = 11 * scale;
        final double cardBody = 10 * scale;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 6 * scale, hPad, 24 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: const Color(0xFF27407C),
                  ),
                  Expanded(
                    child: Text(
                      entry.examName,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF27407C),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(left: 6 * scale),
                child: Text(
                  "Here's how you did on the '${entry.examName}'\nexam.",
                  style: TextStyle(
                    fontSize: captionSize,
                    color: const Color(0xFF6C7685),
                  ),
                ),
              ),
              SizedBox(height: 12 * scale),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Your Score.',
                      style: TextStyle(
                        fontSize: captionSize,
                        color: const Color(0xFF6C7685),
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      '${entry.scorePercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: scoreSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E6CF3),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12 * scale),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Try Again pressed.')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF20324A),
                        backgroundColor: const Color(0xFFE1E4EA),
                        side: const BorderSide(color: Color(0xFFBCC6D6)),
                        padding: EdgeInsets.symmetric(vertical: 12 * scale),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Try Again',
                        style: TextStyle(fontSize: buttonSize),
                      ),
                    ),
                  ),
                  SizedBox(width: 12 * scale),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Performance pressed.')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E4AA8),
                        padding: EdgeInsets.symmetric(vertical: 12 * scale),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Performance',
                        style: TextStyle(fontSize: buttonSize),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10 * scale),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exam regenerated.')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E4AA8),
                  side: const BorderSide(color: Color(0xFF9FB4E9)),
                  padding: EdgeInsets.symmetric(
                    vertical: 12 * scale,
                    horizontal: 16 * scale,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(
                  'Regenerate Exam (120 New Questions)',
                  style: TextStyle(fontSize: buttonSize),
                ),
              ),
              SizedBox(height: 16 * scale),
              Center(
                child: Text(
                  'Topic Breakdown',
                  style: TextStyle(
                    fontSize: sectionTitle,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              SizedBox(height: 8 * scale),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 8 * scale,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE0E5F1)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _TopicHeaderCell(
                          label: 'Category',
                          flex: 4,
                          fontSize: headerSize,
                          height: 24 * scale,
                        ),
                        _TopicHeaderCell(
                          label: 'Correct',
                          flex: 2,
                          fontSize: headerSize,
                          height: 24 * scale,
                        ),
                        _TopicHeaderCell(
                          label: 'Incorrect',
                          flex: 2,
                          fontSize: headerSize,
                          height: 24 * scale,
                        ),
                        _TopicHeaderCell(
                          label: 'Acc',
                          flex: 1,
                          fontSize: headerSize,
                          height: 24 * scale,
                        ),
                      ],
                    ),
                    SizedBox(height: 6 * scale),
                    ...topics.map(
                      (topic) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 6 * scale),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                topic.category,
                                style: TextStyle(fontSize: rowSize),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${topic.correct}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: rowSize),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${topic.incorrect}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: rowSize),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${topic.accuracy}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: rowSize),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 6 * scale),
                    Container(
                      height: 8 * scale,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E8EC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 36 * scale,
                          margin: EdgeInsets.all(1.5 * scale),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7A7F88),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16 * scale),
              Center(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 10 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE0E5F1)),
                  ),
                  child: Center(
                    child: Text(
                      'Review Your Answers',
                      style: TextStyle(
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10 * scale),
              ...List.generate(
                10,
                (index) => _ReviewCard(
                  questionNumber: index + 1,
                  question: 'When I think about my childhood, I\nfeel?',
                  userAnswer: '0.0025 inches/years',
                  isCorrect: index == 3 || index == 4 || index == 5,
                  correctAnswer: '0.010 inches/year',
                  scale: scale,
                  titleSize: cardTitle,
                  bodySize: cardBody,
                ),
              ),
              SizedBox(height: 12 * scale),
              Center(
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Disclaimer tapped.')),
                    );
                  },
                  child: Text.rich(
                    TextSpan(
                      text: 'Not affiliated with or endorsed by API. ',
                      style: TextStyle(
                        fontSize: 10 * scale,
                        color: const Color(0xFF6C7685),
                      ),
                      children: [
                        TextSpan(
                          text: 'See full\n',
                          style: TextStyle(
                            fontSize: 10 * scale,
                            color: Color(0xFF1E6CF3),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(
                          text: 'disclaimer.',
                          style: TextStyle(
                            fontSize: 10 * scale,
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
              SizedBox(height: 12 * scale),
            ],
          ),
        );
      },
    );
  }
}

class _TopicHeaderCell extends StatelessWidget {
  const _TopicHeaderCell({
    required this.label,
    required this.flex,
    required this.fontSize,
    required this.height,
  });

  final String label;
  final int flex;
  final double fontSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        height: height,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE0E5F1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.questionNumber,
    required this.question,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.scale,
    required this.titleSize,
    required this.bodySize,
  });

  final int questionNumber;
  final String question;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final double scale;
  final double titleSize;
  final double bodySize;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10 * scale),
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD5DAE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q$questionNumber. $question',
            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6 * scale),
          if (!isCorrect)
            Text(
              'Your answer : $userAnswer (Incorrect)',
              style: TextStyle(fontSize: bodySize, color: Colors.red),
            ),
          SizedBox(height: 4 * scale),
          Text(
            'Correct answer : $correctAnswer',
            style: TextStyle(fontSize: bodySize, color: Colors.green),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.examName,
    required this.date,
    required this.scorePercent,
    required this.scoreDetail,
  });

  final String examName;
  final String date;
  final double scorePercent;
  final String scoreDetail;
}

class _TopicBreakdown {
  const _TopicBreakdown({
    required this.category,
    required this.correct,
    required this.incorrect,
    required this.accuracy,
  });

  final String category;
  final int correct;
  final int incorrect;
  final int accuracy;
}
