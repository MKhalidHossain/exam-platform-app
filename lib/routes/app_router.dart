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
     
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
}
