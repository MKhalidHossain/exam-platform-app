import 'package:ej_flutter/views/screens/exam_session_screen.dart';
import 'package:ej_flutter/views/screens/quiz_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../views/screens/splash_screen.dart';
import '../views/screens/login_screen.dart';
import '../views/screens/navbar_screen.dart';

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
import '../views/screens/performance_screen.dart';
import '../views/screens/history_models.dart';
import '../views/screens/exam_loading_screen.dart';
import '../views/screens/mcq_screen.dart';
import '../views/screens/exam_review_screen.dart';

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
        path: '/performance',
        name: 'performance',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is PerformanceArgs) {
            return PerformanceScreen(
              entry: extra.entry,
              history: extra.history,
            );
          }
          return const PerformanceScreen(
            entry: HistoryEntry(
              examName: 'API 570 - Piping Inspector',
              date: '1/10/2020, 10:45:37 AM',
              scorePercent: 40.0,
              scoreDetail: '4/10',
            ),
            history: [],
          );
        },
      ),
      GoRoute(
        path: '/quiz-settings',
        name: 'quiz-settings',
        builder: (context, state) {
          final extra = state.extra;
          String title = 'API 570 - Piping Inspector';
          String? examId;
          int? questionCount;
          String? effectivitySheetContent;
          String? bodyOfKnowledgeContent;

          int? parseInt(dynamic value) {
            if (value == null) return null;
            if (value is int) return value;
            if (value is num) return value.toInt();
            return int.tryParse(value.toString());
          }

          if (extra is Map) {
            title = extra['courseTitle']?.toString() ?? title;
            examId = extra['examId']?.toString();
            questionCount = parseInt(extra['questionCount']);
            effectivitySheetContent =
                extra['effectivitySheetContent']?.toString();
            bodyOfKnowledgeContent =
                extra['bodyOfKnowledgeContent']?.toString();
          }
          return QuizSettingsScreen(
            courseTitle: title,
            examId: examId,
            questionCount: questionCount,
            effectivitySheetContent: effectivitySheetContent,
            bodyOfKnowledgeContent: bodyOfKnowledgeContent,
          );
        },
      ),
      GoRoute(
        path: '/exam-session',
        name: 'exam-session',
        builder: (context, state) {
          final extra = state.extra;
          String title = 'API 570 - Piping Inspector';
          String? examId;
          int? questionCount;
          String? effectivitySheetContent;
          String? bodyOfKnowledgeContent;

          int? parseInt(dynamic value) {
            if (value == null) return null;
            if (value is int) return value;
            if (value is num) return value.toInt();
            return int.tryParse(value.toString());
          }

          if (extra is Map) {
            title = extra['courseTitle']?.toString() ?? title;
            examId = extra['examId']?.toString();
            questionCount = parseInt(extra['questionCount']);
            effectivitySheetContent =
                extra['effectivitySheetContent']?.toString();
            bodyOfKnowledgeContent =
                extra['bodyOfKnowledgeContent']?.toString();
          }
          return ExamSessionScreen(
            courseTitle: title,
            examId: examId,
            questionCount: questionCount,
            effectivitySheetContent: effectivitySheetContent,
            bodyOfKnowledgeContent: bodyOfKnowledgeContent,
          );
        },
      ),
      GoRoute(
        path: '/exam-loading',
        name: 'exam-loading',
        builder: (context, state) {
          final extra = state.extra;
          String title = 'API 570 - Piping Inspector';
          String? examId;
          int? questionCount;
          String? examType;

          int? parseInt(dynamic value) {
            if (value == null) return null;
            if (value is int) return value;
            if (value is num) return value.toInt();
            return int.tryParse(value.toString());
          }

          if (extra is Map) {
            title = extra['courseTitle']?.toString() ?? title;
            examId = extra['examId']?.toString();
            questionCount = parseInt(extra['questionCount']);
            examType = extra['examType']?.toString();
          }
          return ExamLoadingScreen(
            courseTitle: title,
            examId: examId,
            questionCount: questionCount,
            examType: examType,
          );
        },
      ),
      GoRoute(
        path: '/mcq',
        name: 'mcq',
        builder: (context, state) {
          final extra = state.extra;
          String title = 'API 570 - Piping Inspector';
          List<dynamic>? questions;
          DateTime? startTime;
          DateTime? endTime;
          int? durationMinutes;

          int? parseInt(dynamic value) {
            if (value == null) return null;
            if (value is int) return value;
            if (value is num) return value.toInt();
            return int.tryParse(value.toString());
          }

          DateTime? parseDate(dynamic value) {
            if (value == null) return null;
            if (value is DateTime) return value;
            return DateTime.tryParse(value.toString());
          }

          if (extra is Map) {
            title = extra['courseTitle']?.toString() ?? title;
            final rawQuestions = extra['questions'];
            if (rawQuestions is List) {
              questions = rawQuestions;
            }
            startTime = parseDate(extra['startTime']);
            endTime = parseDate(extra['endTime']);
            durationMinutes = parseInt(extra['durationMinutes']);
          }
          return McqScreen(
            courseTitle: title,
            questions: questions,
            startTime: startTime,
            endTime: endTime,
            durationMinutes: durationMinutes,
          );
        },
      ),
      GoRoute(
        path: '/exam-review',
        name: 'exam-review',
        builder: (context, state) {
          final extra = state.extra;
          String title = 'API 570 - Piping Inspector';
          List<dynamic> questions = const [];
          Map<int, int> selected = const {};
          Set<int> flagged = const {};
          if (extra is Map) {
            title = extra['courseTitle']?.toString() ?? title;
            questions = (extra['questions'] as List<dynamic>?) ?? const [];
            final rawSelected = extra['selected'];
            if (rawSelected is Map) {
              selected = rawSelected.map(
                (key, value) => MapEntry(
                  int.tryParse(key.toString()) ?? 0,
                  int.tryParse(value.toString()) ?? 0,
                ),
              );
            }
            final rawFlagged = extra['flagged'];
            if (rawFlagged is Set) {
              flagged = rawFlagged.map((e) => int.tryParse(e.toString()) ?? 0).toSet();
            } else if (rawFlagged is List) {
              flagged = rawFlagged.map((e) => int.tryParse(e.toString()) ?? 0).toSet();
            }
          }
          return ExamReviewScreen(
            courseTitle: title,
            questions: questions,
            selected: selected,
            flagged: flagged,
          );
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
