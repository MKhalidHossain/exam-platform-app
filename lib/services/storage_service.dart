import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_constants.dart';
import 'installation_id_service.dart';

class StorageService {
  final InstallationIdService _installationIdService = InstallationIdService();

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  // Token Management
  Future<void> saveToken(String token) async {
    final prefs = await _prefs;
    await prefs.setString(AppConstants.tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await _prefs;
    return prefs.getString(AppConstants.tokenKey);
  }

  Future<void> removeToken() async {
    final prefs = await _prefs;
    await prefs.remove(AppConstants.tokenKey);
  }

  // Refresh Token Management
  Future<void> saveRefreshToken(String refreshToken) async {
    final prefs = await _prefs;
    await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await _prefs;
    return prefs.getString(AppConstants.refreshTokenKey);
  }

  Future<void> removeRefreshToken() async {
    final prefs = await _prefs;
    await prefs.remove(AppConstants.refreshTokenKey);
  }

  // User ID Management
  Future<void> saveUserId(String userId) async {
    final prefs = await _prefs;
    await prefs.setString(AppConstants.userIdKey, userId);
  }

  Future<String?> getUserId() async {
    final prefs = await _prefs;
    return prefs.getString(AppConstants.userIdKey);
  }

  Future<void> removeUserId() async {
    final prefs = await _prefs;
    await prefs.remove(AppConstants.userIdKey);
  }

  // Installation ID Management
  Future<String> getOrCreateInstallationId() async {
    return _installationIdService.getOrCreateInstallationId();
  }

  Future<String?> getInstallationId() async {
    return _installationIdService.getInstallationId();
  }

  // Login Status
  Future<void> setLoggedIn(bool isLoggedIn) async {
    final prefs = await _prefs;
    await prefs.setBool(AppConstants.isLoggedInKey, isLoggedIn);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await _prefs;
    return prefs.getBool(AppConstants.isLoggedInKey) ?? false;
  }

  Future<bool> hasValidSessionArtifacts() async {
    final token = await getToken();
    final refreshToken = await getRefreshToken();
    final isLoggedInFlag = await isLoggedIn();

    return token != null &&
        token.isNotEmpty &&
        refreshToken != null &&
        refreshToken.isNotEmpty &&
        isLoggedInFlag;
  }

  // Generic Methods
  Future<void> saveString(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }

  Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }

  Future<void> savePendingReferralCode(String referralCode) async {
    final normalizedCode = referralCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      await clearPendingReferralCode();
      return;
    }
    await saveString(AppConstants.pendingReferralCodeKey, normalizedCode);
  }

  Future<String?> getPendingReferralCode() async {
    final code = await getString(AppConstants.pendingReferralCodeKey);
    final normalizedCode = code?.trim().toUpperCase() ?? '';
    return normalizedCode.isEmpty ? null : normalizedCode;
  }

  Future<void> clearPendingReferralCode() async {
    await remove(AppConstants.pendingReferralCodeKey);
  }

  Future<void> saveStringList(String key, List<String> value) async {
    final prefs = await _prefs;
    await prefs.setStringList(key, value);
  }

  Future<List<String>?> getStringList(String key) async {
    final prefs = await _prefs;
    return prefs.getStringList(key);
  }

  Future<void> saveBool(String key, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await _prefs;
    return prefs.getBool(key);
  }

  Future<void> saveRememberedLogin({
    required String email,
    required String password,
  }) async {
    final prefs = await _prefs;
    await prefs.setBool(AppConstants.rememberMeKey, true);
    await prefs.setString(AppConstants.rememberedEmailKey, email);
    await prefs.setString(AppConstants.rememberedPasswordKey, password);
  }

  Future<Map<String, String>?> getRememberedLogin() async {
    final prefs = await _prefs;
    final rememberMe = prefs.getBool(AppConstants.rememberMeKey) ?? false;
    if (!rememberMe) return null;

    final email =
        prefs.getString(AppConstants.rememberedEmailKey)?.trim() ?? '';
    final password = prefs.getString(AppConstants.rememberedPasswordKey) ?? '';

    if (email.isEmpty || password.isEmpty) {
      return null;
    }

    return {'email': email, 'password': password};
  }

  Future<void> clearRememberedLogin() async {
    final prefs = await _prefs;
    await prefs.remove(AppConstants.rememberMeKey);
    await prefs.remove(AppConstants.rememberedEmailKey);
    await prefs.remove(AppConstants.rememberedPasswordKey);
  }

  Future<void> saveInt(String key, int value) async {
    final prefs = await _prefs;
    await prefs.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    final prefs = await _prefs;
    return prefs.getInt(key);
  }

  // Clear all data
  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.clear();
  }

  // Clear cache directories
  Future<void> clearCache() async {
    try {
      // Clear Flutter image cache
      imageCache.clear();
      imageCache.clearLiveImages();

      // Clear temporary directory
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }

      // Clear cache directory
      final cacheDir = await getApplicationCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }

      // Clear image cache (if using image_picker)
      try {
        final imageCacheDir = Directory('${tempDir.path}/image_picker');
        if (await imageCacheDir.exists()) {
          await imageCacheDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore if image cache doesn't exist
      }
    } catch (e) {
      // Handle errors silently - cache clearing is not critical
      // Errors are ignored to ensure logout process completes
    }
  }

  Future<void> clearSessionData() async {
    final prefs = await _prefs;
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.userIdKey);
    await prefs.remove(AppConstants.isLoggedInKey);
    await prefs.remove(AppConstants.userDataKey);
    await prefs.remove(AppConstants.userRoleKey);
    await prefs.remove(AppConstants.unlockedExamIdsKey);
  }

  // Complete logout for auth/session state.
  Future<void> logout() async {
    await clearSessionData();
    // Clear all cache
    await clearCache();
  }
}
