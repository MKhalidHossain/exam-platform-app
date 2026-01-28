import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/gradient_background.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import 'home_screen.dart';

class ProfileScreen extends StatefulWidget {
  final PlanTier planTier;

  const ProfileScreen({
    super.key,
    this.planTier = PlanTier.starter,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Load user data from storage or API
    // For now, using mock data
    setState(() {
      _user = UserModel(
        id: '1',
        name: 'Madiha Lata',
        email: 'madiha@example.com',
        phone: '+1234567890',
        avatar: null,
      );
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Hi, Good Morning';
    } else if (hour < 17) {
      return 'Hi, Good Afternoon';
    } else {
      return 'Hi, Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        useImage: true,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Profile Header Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Profile Picture
                      Stack(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[300],
                              image: _user?.avatar != null
                                  ? DecorationImage(
                                      image: NetworkImage(_user!.avatar!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _user?.avatar == null
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Name and Greeting
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _user?.name ?? 'User',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getGreeting(),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Plan Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D4F88),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.planTier == PlanTier.professional
                                  ? 'Professional'
                                  : 'Starter',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Settings Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.settings,
                            color: Color(0xFF2D4F88),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Setting',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D4F88),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Settings Items
                      _SettingItem(
                        icon: Icons.edit_outlined,
                        title: 'Edit Profile',
                        subtitle: 'Update your personal information',
                        onTap: () {
                          context.push('/edit-profile');
                        },
                      ),
                      const SizedBox(height: 12),
                      _SettingItem(
                        icon: Icons.dashboard_outlined,
                        title: 'Performance Dashboard',
                        subtitle: 'Manage your Performance Dashboard',
                        onTap: () {
                          // Navigate to performance dashboard
                        },
                      ),
                      const SizedBox(height: 12),
                      _SettingItem(
                        icon: Icons.lock_outline,
                        title: 'Change Password',
                        subtitle: 'Update your personal information',
                        onTap: () {
                          context.push('/change-password');
                        },
                      ),
                      const SizedBox(height: 12),
                      _SettingItem(
                        icon: Icons.receipt_long_outlined,
                        title: 'Subscription',
                        subtitle: 'Manage your plan and billing',
                        onTap: () {
                          context.push('/subscribe');
                        },
                      ),
                      const SizedBox(height: 12),
                      _SettingItem(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy policy',
                        subtitle: 'How we handle your data',
                        onTap: () {
                          context.push('/privacy-policy');
                        },
                      ),
                      const SizedBox(height: 12),
                      _SettingItem(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        subtitle: 'App usage terms and conditions',
                        onTap: () {
                          context.push('/terms-of-service');
                        },
                      ),
                      const SizedBox(height: 12),
                      _SettingItem(
                        icon: Icons.help_outline,
                        title: 'FAQ',
                        subtitle: 'Get the information you need',
                        onTap: () {
                          context.push('/faq');
                        },
                      ),
                      const SizedBox(height: 12),
                      _SettingItem(
                        icon: Icons.headset_mic_outlined,
                        title: 'Contact Us',
                        subtitle: 'Help and support you need',
                        onTap: () {
                          context.push('/contact-us');
                        },
                      ),
                      const SizedBox(height: 24),
                      // Log Out Button
                      _SettingItem(
                        icon: Icons.logout,
                        title: 'Log Out',
                        subtitle: '',
                        isLogout: true,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Log Out'),
                              content: const Text(
                                'Are you sure you want to log out?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Log Out'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            // Show loading indicator
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            // Clear all user data and cache
                            await _storageService.logout();

                            if (context.mounted) {
                              // Close loading dialog
                              Navigator.of(context, rootNavigator: true).pop();
                              // Navigate to onboarding screen
                              context.go('/onboarding');
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLogout;

  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isLogout
                    ? Colors.red[50]
                    : const Color(0xFF2D4F88).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isLogout ? Colors.red : const Color(0xFF2D4F88),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isLogout ? Colors.red : const Color(0xFF111827),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
