// Lightweight auth helper used by UI logout/auth state checks.

import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  /// Check if user is authenticated (design only - no API call)
  Future<bool> isAuthenticated() async {
    final token = await _storageService.getToken();
    final isLoggedIn = await _storageService.isLoggedIn();
    return token != null && isLoggedIn;
  }

  /// Logout user (design only - clears local storage)
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (_) {
      // Always clear local session data, even when API logout fails.
    }
    await _storageService.logout();
  }
}
