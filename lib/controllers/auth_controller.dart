import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../controllers/user_controller.dart';

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
        await userController.clearState();
        await userController.refreshProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Login successful!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Login failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Registration successful!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Registration failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'OTP sent to your email successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/verify-otp', extra: {
          'email': email,
          'isForPasswordReset': true,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Failed to send OTP. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Password reset successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Failed to reset password. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }
}
