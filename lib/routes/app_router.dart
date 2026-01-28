import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../views/screens/splash_screen.dart';
import '../views/screens/login_screen.dart';
import '../views/screens/navbar_screen.dart';
import '../views/screens/quiz_settings_screen.dart';
import '../views/screens/exam_session_screen.dart';
import '../views/screens/onboarding_screen.dart';
import '../views/screens/sign_up_screen.dart';
import '../views/screens/forget_password_screen.dart';
import '../views/screens/verify_otp_screen.dart';
import '../views/screens/reset_password_screen.dart';
import '../views/screens/edit_profile_screen.dart';
import '../views/screens/change_password_screen.dart';
import '../views/screens/privacy_policy_screen.dart';
import '../views/screens/terms_of_service_screen.dart';
import '../views/screens/faq_screen.dart';
import '../views/screens/subscribe_screen.dart';
import '../views/screens/contact_us_screen.dart';
import '../views/screens/professional_plan_screen.dart';

GoRouter getRouter() {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {


     
 

  

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
     

      GoRoute(
        path: '/sign-up',
        name: 'sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/forget-password',
        name: 'forget-password',
        builder: (context, state) => const ForgetPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        name: 'verify-otp',
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final data = state.extra as Map<String, dynamic>;
            return VerifyOtpScreen(
              email: data['email'] as String?,
              isForPasswordReset: data['isForPasswordReset'] as bool? ?? false,
            );
          } else {
            final email = state.extra as String?;
            return VerifyOtpScreen(email: email);
          }
        },
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final data = state.extra as Map<String, dynamic>;
            return ResetPasswordScreen(
              email: data['email'],
              otp: data['otp'],
            );
          } else {
            final email = state.extra as String?;
            return ResetPasswordScreen(email: email);
          }
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const NavbarScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/change-password',
        name: 'change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        name: 'privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/terms-of-service',
        name: 'terms-of-service',
        builder: (context, state) => const TermsOfServiceScreen(),
      ),
      GoRoute(
        path: '/faq',
        name: 'faq',
        builder: (context, state) => const FaqScreen(),
      ),
      GoRoute(
        path: '/subscribe',
        name: 'subscribe',
        builder: (context, state) => const SubscribeScreen(),
      ),
      GoRoute(
        path: '/contact-us',
        name: 'contact-us',
        builder: (context, state) => const ContactUsScreen(),
      ),
      GoRoute(
        path: '/professional-plan',
        name: 'professional-plan',
        builder: (context, state) => const ProfessionalPlanScreen(),
      ),
      GoRoute(
        path: '/quiz-settings',
        name: 'quiz-settings',
        builder: (context, state) {
          final extra = state.extra;
          String title = 'API 570 - Piping Inspector';
          if (extra is Map) {
            title = extra['courseTitle']?.toString() ?? title;
          }
          return QuizSettingsScreen(courseTitle: title);
        },
      ),
      GoRoute(
        path: '/exam-session',
        name: 'exam-session',
        builder: (context, state) {
          final extra = state.extra;
          String title = 'API 570 - Piping Inspector';
          if (extra is Map) {
            title = extra['courseTitle']?.toString() ?? title;
          }
          return ExamSessionScreen(courseTitle: title);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
}
