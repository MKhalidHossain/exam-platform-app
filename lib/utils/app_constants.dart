class AppConstants {
  // App Info
  static const String appName = 'EJ Flutter App';
  static const String appVersion = '1.0.0';

  // API Constants
  static const String apiOrigin = 'http://187.77.10.158:5001';
  // static const String apiOrigin = 'http://localhost:5001';
  static const String baseUrl = '$apiOrigin/api/v1';
  static const String publicBaseUrl = apiOrigin;
  static const Duration apiTimeout = Duration(seconds: 30);
  // null = no timeout (wait indefinitely).
  static const Duration? examGenerationTimeout = null;
  static const String appLinkScheme = 'ejflutter';
  static const String sharedEbookPath = '/shared-ebook';
  static const String sharedReferralPath = '/shared-referral';

  // Stripe (use env or build config in production)
  static const String stripePublishableKey =
      'pk_test_51S6pMbRZVOYD6qjBukBi2VyPiTtIhzAyYzmfyAo4izzIwemOo7I3fUYELhxmTJeNln7zMiztFA4CKihsybqrJlo800nWzvIXZY';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String installationIdSecureKey = 'installation_id';
  static const String installationBootstrapKey = 'installation_bootstrapped';
  static const String installationIdHeaderKey = 'X-App-Installation-Id';
  static const String isLoggedInKey = 'is_logged_in';
  static const String userDataKey = 'user_data';
  static const String userRoleKey = 'user_role';
  static const String unlockedExamIdsKey = 'unlocked_exam_ids';
  static const String pendingReferralCodeKey = 'pending_referral_code';
  static const String pendingReferralProductIdKey =
      'pending_referral_product_id';
  static const String voicePracticeDisclaimerAcceptedKey =
      'voice_practice_disclaimer_accepted';
  static const String rememberMeKey = 'remember_me';
  static const String rememberedEmailKey = 'remembered_email';
  static const String rememberedPasswordKey = 'remembered_password';

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
