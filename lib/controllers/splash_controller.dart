import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';

class SplashController extends GetxController {
  final StorageService _storage = StorageService();
  final UserService _userService = UserService();

  Future<void> start(BuildContext context) async {
    // keep splash visible
    await Future.delayed(const Duration(seconds: 2));
    if (!context.mounted) return;

    final hasSession = await _storage.hasValidSessionArtifacts();
    if (!hasSession) {
      await _storage.clearSessionData();
      if (!context.mounted) return;
      context.go('/onboarding');
      return;
    }

    final profileResponse = await _userService.getProfile();
    if (!context.mounted) return;

    if (profileResponse.success && profileResponse.data != null) {
      if (profileResponse.data!.mustChangePassword) {
        context.go('/change-password', extra: {'forceChange': true});
        return;
      }
      context.go('/home');
    } else {
      await _storage.clearSessionData();
      if (!context.mounted) return;
      context.go('/login');
    }
  }
}
