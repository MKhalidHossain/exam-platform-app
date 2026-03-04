import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import '../widgets/gradient_background.dart';
import '../widgets/app_shimmer.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/home_controller.dart';
import '../../models/plan_tier.dart';

class ProfileScreen extends StatefulWidget {
  final PlanTier planTier;

  const ProfileScreen({super.key, this.planTier = PlanTier.starter});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StorageService _storageService = StorageService();
  late final UserController _userController;

  @override
  void initState() {
    super.initState();
    _userController = Get.isRegistered<UserController>()
        ? Get.find<UserController>()
        : Get.put(UserController());
    if (_userController.user.value == null) {
      _userController.refreshProfile();
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) {
      return 'Hi, Good Night';
    } else if (hour < 12) {
      return 'Hi, Good Morning';
    } else if (hour < 17) {
      return 'Hi, Good Afternoon';
    } else if (hour < 21) {
      return 'Hi, Good Evening';
    } else {
      return 'Hi, Good Night';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final UserModel? user = _userController.user.value;
      final PlanTier planTier = _userController.planTier.value;
      final String primaryName = (user?.name ?? '').trim();
      final String fallbackName =
          '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();
      final String userName = fallbackName.isNotEmpty
          ? fallbackName
          : (primaryName.isNotEmpty ? primaryName : 'User');
      final String? avatarUrl = user?.avatar != null && user!.avatar!.isNotEmpty
          ? user.avatar
          : null;
      final String email = (user?.email ?? '').trim();
      final int? avatarStamp = user?.updatedAt?.millisecondsSinceEpoch;
      final String? avatarDisplayUrl = avatarUrl != null && avatarStamp != null
          ? '$avatarUrl${avatarUrl.contains('?') ? '&' : '?'}v=$avatarStamp'
          : avatarUrl;

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
                                image: avatarDisplayUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(avatarDisplayUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: avatarDisplayUrl == null
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
                                userName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              if (email.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
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
                            color: planTier == PlanTier.professional
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF2D4F88),
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
                                planTier.label,
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
                          title: 'Performance',
                          subtitle: 'Manage your Performance',
                          onTap: () {
                            context.push('/performance');
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
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
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
                                    child: AppShimmerCircle(size: 36),
                                  ),
                                );
                              }

                              // Clear all user data and cache
                              await _storageService.logout();
                              await _userController.clearState();
                              if (Get.isRegistered<HomeController>()) {
                                Get.find<HomeController>().clearState();
                              }

                              if (context.mounted) {
                                // Close loading dialog
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop();
                                // Navigate to onboarding screen
                                context.go('/onboarding');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      );
    });
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
          border: Border.all(color: Colors.grey[200]!, width: 1),
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
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
