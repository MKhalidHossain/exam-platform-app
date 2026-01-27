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

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

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
