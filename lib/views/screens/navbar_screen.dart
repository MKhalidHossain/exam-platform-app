import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class NavbarScreen extends StatefulWidget {
  final PlanTier planTier;
  final Set<String> unlockedCourseIds;

  const NavbarScreen({
    super.key,
    this.planTier = PlanTier.starter,
    this.unlockedCourseIds = const {},
  });

  @override
  State<NavbarScreen> createState() => _NavbarScreenState();
}

class _NavbarScreenState extends State<NavbarScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.zero,
                child: IndexedStack(
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
              ),
            ),
          ),
          const _HistoryTab(),
          ProfileScreen(planTier: widget.planTier),
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
        ],
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
            icon: currentIndex == 2 ? Icons.person : Icons.person_outline,
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
          'History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

