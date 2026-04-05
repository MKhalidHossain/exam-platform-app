import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import '../core/error/error_handler.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../controllers/user_controller.dart';
import '../controllers/home_controller.dart';
import '../utils/app_constants.dart';

class AuthController extends GetxController {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  final RxBool isLoading = false.obs;

  Future<void> login(
    BuildContext context, {
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final response = await _apiService.login(
        email: email,
        password: password,
      );
      if (!context.mounted) return;

      if (response.success) {
        if (rememberMe) {
          await _storageService.saveRememberedLogin(
            email: email,
            password: password,
          );
        } else {
          await _storageService.clearRememberedLogin();
        }

        final UserController userController = Get.isRegistered<UserController>()
            ? Get.find<UserController>()
            : Get.put(UserController());
        final HomeController? homeController =
            Get.isRegistered<HomeController>()
            ? Get.find<HomeController>()
            : null;
        await userController.clearState();
        homeController?.clearState();
        await userController.refreshProfile();
        if (homeController != null) {
          await homeController.fetchActiveExams();
        }
        if (!context.mounted) return;
        ErrorHandler.showSnackBar(
          ErrorHandler.getMessageFromResponse(
            response,
            successFallback: 'Login successful!',
          ),
          isError: false,
          context: context,
        );
        context.go(await _resolvePostAuthRoute());
      } else {
        final message = ErrorHandler.getMessageFromResponse(
          response,
          failureFallback: 'Login failed. Please try again.',
        );
        if (_isAlreadyLoggedInAnotherInstallation(message)) {
          await _showAlreadyLoggedInAlert(context, message);
        } else {
          ErrorHandler.showSnackBar(message, context: context);
        }
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
    String? referralCode,
  }) async {
    if (isLoading.value) return;
    isLoading.value = true;
    final trimmedReferralCode = referralCode?.trim().toUpperCase() ?? '';
    try {
      if (trimmedReferralCode.isNotEmpty) {
        await _storageService.savePendingReferralCode(trimmedReferralCode);
      } else {
        await _storageService.clearPendingReferralCode();
      }

      final response = await _apiService.register(
        phone: phone,
        name: name,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
        referralCode: trimmedReferralCode,
      );
      if (!context.mounted) return;

      if (response.success) {
        ErrorHandler.showSnackBar(
          ErrorHandler.getMessageFromResponse(
            response,
            successFallback: 'Registration successful!',
          ),
          isError: false,
          context: context,
        );
        final loginRoute = trimmedReferralCode.isEmpty
            ? '/login'
            : Uri(
                path: '/login',
                queryParameters: {'ref': trimmedReferralCode},
              ).toString();
        context.go(loginRoute);
      } else {
        ErrorHandler.showFromResponse(
          response,
          context: context,
          failureFallback: 'Registration failed. Please try again.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showFromException(e, context: context);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<String> _resolvePostAuthRoute() async {
    final referralCode = await _storageService.getPendingReferralCode();
    final productId = await _storageService.getString(
      AppConstants.pendingReferralProductIdKey,
    );

    final trimmedReferralCode = referralCode?.trim() ?? '';
    final trimmedProductId = productId?.trim() ?? '';
    await _storageService.remove(AppConstants.pendingReferralProductIdKey);

    if (trimmedProductId.isNotEmpty) {
      final params = <String, String>{'productId': trimmedProductId};
      return Uri(path: '/ebook-detail', queryParameters: params).toString();
    }

    if (trimmedReferralCode.isEmpty) {
      return '/home';
    }

    return '/subscribe';
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
          ErrorHandler.getMessageFromResponse(
            response,
            successFallback: 'OTP sent to your email successfully',
          ),
          isError: false,
          context: context,
        );
        context.go(
          '/verify-otp',
          extra: {'email': email, 'isForPasswordReset': true},
        );
      } else {
        ErrorHandler.showFromResponse(
          response,
          context: context,
          failureFallback: 'Failed to send OTP. Please try again.',
        );
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
          ErrorHandler.getMessageFromResponse(
            response,
            successFallback: 'Password reset successfully',
          ),
          isError: false,
          context: context,
        );
        context.go('/login');
      } else {
        ErrorHandler.showFromResponse(
          response,
          context: context,
          failureFallback: 'Failed to reset password. Please try again.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showFromException(e, context: context);
      }
    } finally {
      isLoading.value = false;
    }
  }

  bool _isAlreadyLoggedInAnotherInstallation(String message) {
    final lower = message.toLowerCase();
    return lower.contains('already logged in on another installation') ||
        lower.contains('locked to another installation') ||
        (lower.contains('already logged in') &&
            lower.contains('another installation'));
  }

  Future<void> _showAlreadyLoggedInAlert(
    BuildContext context,
    String message,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Blocked'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
