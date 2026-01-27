import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_colors.dart';
import '../widgets/gradient_background.dart';
import '../widgets/page_indicator.dart';
import '../widgets/primary_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Welcome to 'Inspector's Path'",
      description:
          "Your expert guide to mastering API 510, 570, 653, 1169, 936, SIEF, SIRE, and SIEE certification exams. Let's get you certified.",
      imagePath: "assets/images/onboarding1.png",
    ),
    OnboardingPage(
      title: "Dynamic Exams, Real Results.",
      description:
          "Stop memorizing static questions. Our engine generates unique, real-time practice exams aligned with every certification codebook, ensuring you truly understand the material.",
      imagePath: "assets/images/onboarding2.png",
    ),
    OnboardingPage(
      title: "Identify Your Weaknesses. Master Every Topic.",
      description:
          "Our detailed analytics identify your exact knowledge gaps by topic, allowing you to focus your study on where it matters most and turn weaknesses into strengths.",
      imagePath: "assets/images/onboarding3.png",
    ),
    OnboardingPage(
      title: "Walk In Confident. Pass The First Time.",
      description:
          "Practice under real exam conditions with timed simulations, gain unlimited access to our question bank, and prepare for success like never before.",
      imagePath: "assets/images/onboarding4.png",
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to login screen
      context.go('/login');
    }
  }

  void _onSkip() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button and skip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48),
                    TextButton(
                      onPressed: _onSkip,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),

              // Page Indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: PageIndicator(
                  currentPage: _currentPage,
                  totalPages: _pages.length,
                ),
              ),

              // Action Buttons (Login and Registration on last page)
              if (_currentPage == _pages.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      // Login Button
                      PrimaryButton(
                        text: 'Login',
                        onPressed: () => context.go('/login'),
                        useGradient: true,
                        borderRadius: 30,
                      ),
                      const SizedBox(height: 16),
                      // Registration Button
                      PrimaryButton(
                        text: 'Registration',
                        onPressed: () => context.go('/sign-up'),
                        useGradient: true,
                        borderRadius: 30,
                      ),
                    ],
                  ),
                )
              else
                // Next Button for other pages
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: PrimaryButton(
                    text: "Next",
                    onPressed: _onNext,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          Expanded(
            flex: 3,
            child: Center(
              child: Image.asset(
                page.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Placeholder if image not found
                  return Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.image,
                      size: 100,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.onboardingBlue,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String imagePath;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}
