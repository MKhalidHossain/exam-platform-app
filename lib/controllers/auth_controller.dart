import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import '../core/error/error_handler.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../controllers/user_controller.dart';
import '../controllers/home_controller.dart';
import '../utils/app_constants.dart';
import '../views/widgets/force_change_password_dialog.dart';

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
        final UserController userController = Get.isRegistered<UserController>()
            ? Get.find<UserController>()
            : Get.put(UserController());
        final HomeController? homeController =
            Get.isRegistered<HomeController>()
            ? Get.find<HomeController>()
            : null;
        await userController.clearState();
        homeController?.clearState();
        if (!context.mounted) return;

        if (response.data?.mustChangePassword ?? false) {
          await _storageService.clearRememberedLogin();
          if (!context.mounted) return;

          final newPassword = await _showForceChangePasswordDialog(
            context,
            currentPassword: password,
          );
          if (!context.mounted) return;

          if (newPassword == null) {
            await _storageService.clearSessionData();
            return;
          }

          await _saveRememberedLoginChoice(
            email: email,
            password: newPassword,
            rememberMe: rememberMe,
          );
          await userController.refreshProfile();
          if (homeController != null) {
            await homeController.fetchActiveExams();
          }
          final postAuthRoute = await _resolvePostAuthRoute();
          if (!context.mounted) return;
          ErrorHandler.showSnackBar(
            'Password updated successfully.',
            isError: false,
            context: context,
          );
          context.go(postAuthRoute);
          return;
        }

        await _saveRememberedLoginChoice(
          email: email,
          password: password,
          rememberMe: rememberMe,
        );
        await userController.refreshProfile();
        if (homeController != null) {
          await homeController.fetchActiveExams();
        }
        final postAuthRoute = await _resolvePostAuthRoute();
        if (!context.mounted) return;
        ErrorHandler.showSnackBar(
          ErrorHandler.getMessageFromResponse(
            response,
            successFallback: 'Login successful!',
          ),
          isError: false,
          context: context,
        );
        context.go(postAuthRoute);
      } else {
        final message = ErrorHandler.getMessageFromResponse(
          response,
          failureFallback: 'Login failed. Please try again.',
        );
        if (_isDeviceMismatchResponse(
          response.code,
          response.rawData,
          message,
        )) {
          isLoading.value = false;
          await _showDeviceRelinkDialog(
            context,
            email: email,
            password: password,
          );
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

  Future<void> _saveRememberedLoginChoice({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    if (rememberMe) {
      await _storageService.saveRememberedLogin(
        email: email,
        password: password,
      );
    } else {
      await _storageService.clearRememberedLogin();
    }
  }

  Future<String?> _showForceChangePasswordDialog(
    BuildContext context, {
    required String currentPassword,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ForceChangePasswordDialog(currentPassword: currentPassword),
    );
  }

  Future<void> register(
    BuildContext context, {
    String? phone,
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

  Future<void> requestDeviceReset(
    BuildContext context, {
    required String email,
    required String password,
  }) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final response = await _apiService.requestDeviceReset(
        email: email,
        password: password,
      );
      if (!context.mounted) return;

      if (response.success) {
        ErrorHandler.showSnackBar(
          ErrorHandler.getMessageFromResponse(
            response,
            successFallback: 'Device verification OTP sent to your email',
          ),
          isError: false,
          context: context,
        );
        context.go(
          '/verify-otp',
          extra: {
            'email': email,
            'password': password,
            'isForDeviceReset': true,
          },
        );
      } else {
        ErrorHandler.showFromResponse(
          response,
          context: context,
          failureFallback: 'Unable to request device verification OTP.',
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

  Future<void> verifyDeviceResetWithOtp(
    BuildContext context, {
    required String email,
    required String otp,
    required String password,
  }) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final response = await _apiService.verifyDeviceReset(
        email: email,
        otp: otp,
      );
      if (!context.mounted) return;

      if (response.success) {
        ErrorHandler.showSnackBar(
          ErrorHandler.getMessageFromResponse(
            response,
            successFallback: 'Device re-linked successfully.',
          ),
          isError: false,
          context: context,
        );
        isLoading.value = false;
        await login(context, email: email, password: password);
      } else {
        ErrorHandler.showFromResponse(
          response,
          context: context,
          failureFallback: 'Device verification failed. Please try again.',
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

  bool _isDeviceMismatchResponse(
    String? responseCode,
    dynamic rawData,
    String message,
  ) {
    if (responseCode == 'DEVICE_MISMATCH') return true;
    if (rawData is Map) {
      final code = rawData['code']?.toString();
      if (code == 'DEVICE_MISMATCH') return true;
      if (rawData['can_request_device_reset'] == true) return true;
    }
    final lower = message.toLowerCase();
    return lower.contains('already linked to another installation') ||
        lower.contains('already logged in on another installation') ||
        lower.contains('locked to another installation') ||
        (lower.contains('already logged in') &&
            lower.contains('another installation'));
  }

  Future<void> _showDeviceRelinkDialog(
    BuildContext context, {
    required String email,
    required String password,
  }) async {
    final shouldVerify = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New installation detected'),
        content: const Text(
          'This account is already linked to another app installation. '
          'Please verify your account to re-link this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Verify & Relink'),
          ),
        ],
      ),
    );

    if (shouldVerify == true && context.mounted) {
      await requestDeviceReset(context, email: email, password: password);
    }
  }
}
