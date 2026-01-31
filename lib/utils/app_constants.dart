// Conditional import: dart:io on mobile/desktop, stub on web
import 'app_constants_io.dart' if (dart.library.html) 'app_constants_web.dart'
    as platform;

class AppConstants {
  // App Info
  static const String appName = 'EJ Flutter App';
  static const String appVersion = '1.0.0';

  // API Constants - platform-aware for emulator/simulator
  /// Override to force a specific URL (e.g. for physical device: set to your machine's LAN IP)
  static String? baseUrlOverride;

  static String get baseUrl {
    if (baseUrlOverride != null && baseUrlOverride!.isNotEmpty) {
      return baseUrlOverride!;
    }
    return platform.getBaseUrl(_defaultBaseUrl);
  }

  /// Default URL for physical devices - update this to your machine's LAN IP
  static const String _defaultBaseUrl = 'http://10.10.5.94:5001/api/v1';

  static const Duration apiTimeout = Duration(seconds: 30);

  // Stripe (use env or build config in production)
  static const String stripePublishableKey =
      'pk_test_51S6pMbRZVOYD6qjBukBi2VyPiTtIhzAyYzmfyAo4izzIwemOo7I3fUYELhxmTJeNln7zMiztFA4CKihsybqrJlo800nWzvIXZY';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String isLoggedInKey = 'is_logged_in';
  static const String userDataKey = 'user_data';
  static const String userRoleKey = 'user_role';
  static const String unlockedExamIdsKey = 'unlocked_exam_ids';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 50;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 30;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
}
