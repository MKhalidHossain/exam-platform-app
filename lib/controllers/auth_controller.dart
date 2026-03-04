import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import '../core/error/error_handler.dart';
import '../services/api_service.dart';
import '../controllers/user_controller.dart';
import '../controllers/home_controller.dart';

class AuthController extends GetxController {
  final ApiService _apiService = ApiService();

  final RxBool isLoading = false.obs;

  Future<void> login(
    BuildContext context, {
    required String email,
    required String password,
  }) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final response = await _apiService.login(email: email, password: password);
      if (!context.mounted) return;

      if (response.success) {
        final UserController userController = Get.isRegistered<UserController>()
            ? Get.find<UserController>()
            : Get.put(UserController());
        final HomeController? homeController = Get.isRegistered<HomeController>()
            ? Get.find<HomeController>()
            : null;
        await userController.clearState();
        homeController?.clearState();
        await userController.refreshProfile();
        if (homeController != null) {
          await homeController.fetchActiveExams();
        }
        ErrorHandler.showSnackBar(
          ErrorHandler.getMessageFromResponse(response, successFallback: 'Login successful!'),
          isError: false,
          context: context,
        );
        context.go('/home');
      } else {
        ErrorHandler.showFromResponse(response, context: context, failureFallback: 'Login failed. Please try again.');
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showFromException(e, context: context);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register(
    BuildContext context, {
    required String phone,
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final response = await _apiService.register(
        phone: phone,
        name: name,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );
      if (!context.mounted) return;

      if (response.success) {
        ErrorHandler.showSnackBar(
          ErrorHandler.getMessageFromResponse(response, successFallback: 'Registration successful!'),
          isError: false,
          context: context,
        );
        context.go('/login');
      } else {
        ErrorHandler.showFromResponse(response, context: context, failureFallback: 'Registration failed. Please try again.');
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showFromException(e, context: context);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> forgotPassword(
    BuildContext context, {
    required String email,
  }) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final response = await _apiService.forgotPassword(email: email);
      if (!context.mounted) return;

      if (response.success) {
        ErrorHandler.showSnackBar(
          ErrorHandler.getMessageFromResponse(response, successFallback: 'OTP sent to your email successfully'),
          isError: false,
          context: context,
        );
        context.go('/verify-otp', extra: {
          'email': email,
          'isForPasswordReset': true,
        });
      } else {
        ErrorHandler.showFromResponse(response, context: context, failureFallback: 'Failed to send OTP. Please try again.');
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showFromException(e, context: context);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resetPasswordWithOtp(
    BuildContext context, {
    required String email,
    required String otp,
    required String password,
  }) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final response = await _apiService.verifyOtp(
        email: email,
        otp: otp,
        password: password,
      );
      if (!context.mounted) return;

      if (response.success) {
        ErrorHandler.showSnackBar(
          ErrorHandler.getMessageFromResponse(response, successFallback: 'Password reset successfully'),
          isError: false,
          context: context,
        );
        context.go('/login');
      } else {
        ErrorHandler.showFromResponse(response, context: context, failureFallback: 'Failed to reset password. Please try again.');
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showFromException(e, context: context);
      }
    } finally {
      isLoading.value = false;
    }
  }
}
