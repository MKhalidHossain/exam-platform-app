import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import '../services/storage_service.dart';

class SplashController extends GetxController {
  final StorageService _storage = StorageService();

  Future<void> start(BuildContext context) async {
    // keep splash visible
    await Future.delayed(const Duration(seconds: 2));
    if (!context.mounted) return;

    final token = await _storage.getToken();
    final isLoggedIn = await _storage.isLoggedIn();

    if (token != null && token.isNotEmpty && isLoggedIn) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }
}

