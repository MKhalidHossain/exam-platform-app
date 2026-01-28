import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_constants.dart';

class StorageService {
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

  // Login Status
  Future<void> setLoggedIn(bool isLoggedIn) async {
    final prefs = await _prefs;
    await prefs.setBool(AppConstants.isLoggedInKey, isLoggedIn);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await _prefs;
    return prefs.getBool(AppConstants.isLoggedInKey) ?? false;
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

  Future<void> saveBool(String key, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await _prefs;
    return prefs.getBool(key);
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

  // Complete logout - clears all data and cache
  Future<void> logout() async {
    // Clear all storage data
    await clearAll();
    // Clear all cache
    await clearCache();
  }
}
