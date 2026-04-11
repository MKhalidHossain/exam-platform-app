import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_navigation.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'history_tab.dart';
import 'ebook_tab_screen.dart';
import '../../models/plan_tier.dart';
import '../../services/user_service.dart';

class NavbarScreen extends StatefulWidget {
  final PlanTier planTier;
  final Set<String> unlockedCourseIds;
  final int initialIndex;
  final String initialReferralCode;
  final String initialProductId;

  const NavbarScreen({
    super.key,
    this.planTier = PlanTier.starter,
    this.unlockedCourseIds = const {},
    this.initialIndex = 0,
    this.initialReferralCode = '',
    this.initialProductId = '',
  });

  @override
  State<NavbarScreen> createState() => _NavbarScreenState();
}

class _NavbarScreenState extends State<NavbarScreen> {
  final UserService _userService = UserService();
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    appTabNavigationController.addListener(_handleOpenResourcesTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectIfPasswordChangeRequired();
    });
  }

  Future<void> _redirectIfPasswordChangeRequired() async {
    final response = await _userService.getProfile();
    if (!mounted) return;
    if (response.success && response.data?.mustChangePassword == true) {
      context.go('/change-password', extra: {'forceChange': true});
    }
  }

  @override
  void didUpdateWidget(covariant NavbarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = widget.initialIndex.clamp(0, 3);
    if (oldWidget.initialIndex != widget.initialIndex &&
        _currentIndex != nextIndex) {
      setState(() {
        _currentIndex = nextIndex;
      });
    }
  }

  @override
  void dispose() {
    appTabNavigationController.removeListener(_handleOpenResourcesTab);
    super.dispose();
  }

  void _handleOpenResourcesTab() {
    if (!mounted || _currentIndex == 1) return;
    setState(() {
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF2F5FF),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/splash_background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
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
                    EbookTabScreen(
                      initialReferralCode: widget.initialReferralCode,
                      initialProductId: widget.initialProductId,
                    ),
                    const HistoryTab(),
                    ProfileScreen(planTier: widget.planTier),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: _BottomNavBar(
                  currentIndex: _currentIndex,
                  onTap: (index) => setState(() => _currentIndex = index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

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
            icon: Icons.menu_book_rounded,
            label: 'Resources',
            onTap: onTap,
          ),
          _NavItem(
            index: 2,
            currentIndex: currentIndex,
            icon: Icons.history,
            label: 'History',
            onTap: onTap,
          ),
          _NavItem(
            index: 3,
            currentIndex: currentIndex,
            icon: currentIndex == 3 ? Icons.person : Icons.person_outline,
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
