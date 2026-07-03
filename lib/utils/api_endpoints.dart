class ApiEndpoints {
  // Base paths
  static const String auth = '/auth';
  static const String user = '/user';

  // Auth Endpoints
  static const String register = '$auth/register';
  static const String login = '$auth/login';
  static const String requestDeviceReset = '$auth/request-device-reset';
  static const String verifyDeviceReset = '$auth/verify-device-reset';
  static const String verifyEmail = '$auth/verify';
  static const String forgetPassword = '$auth/forget';
  static const String resetPassword = '$auth/reset-password';
  static const String changePassword = '$auth/change-password';
  static const String refreshToken = '$auth/refresh-token';
  static const String logout = '$auth/logout';

  // User Endpoints
  static const String getUsers = user;
  static const String getProfile = '$user/profile';
  static const String getMyUnlocks = '$user/profile/unlocks';
  static const String updateProfile = '$user/profile';
  static const String updateUserPassword = '$user/password';
  static String getUserDetails(String id) => '$user/$id';
  static String updateUserStatus(String id) => '$user/$id/status';

  static String deleteUser(String id) => '$user/$id';

  // Exam Endpoints
  static const String exams = '/exam';
  static String examStart(String examId) => '$exams/$examId/start';
  static String examProgress(String examId) => '$exams/$examId/progress';
  static String examSubmit(String examId) => '$exams/$examId/submit';
  static String examReview(String examId) => '$exams/$examId/review';

  // Analytics Endpoints
  static const String historyAttempts = '/analytics/history/attempts';
  static String historyAttemptDetail(String attemptId) =>
      '$historyAttempts/$attemptId';
  static const String performanceMe = '/analytics/me/performance';
  static const String overviewMe = '/analytics/me/overview';

  // Support Endpoints
  static const String support = '/support';
  static const String announcement = '/announcement';

  // Resource Store / eBook Endpoints
  static const String resources = '/resources';
  static const String resourceStore = '$resources/store';
  static const String resourceUpgradeAddonOptions =
      '$resources/upgrade-addon-options';
  static String resourcePreview(String productId) =>
      '$resources/products/$productId/preview';
  static String resourcePurchasedContent(String productId) =>
      '$resources/products/$productId/content';
  static const String resourcePurchaseStripeCreate =
      '$resources/purchase/stripe/create';
  static const String resourcePurchaseStripeConfirm =
      '$resources/purchase/stripe/confirm';

  // Referral Endpoints
  static const String referrals = '/referrals';
  static String referralPublicCode(String code) => '$referrals/public/$code';
  static const String referralProfile = '$referrals/me';
  static const String referralProgram = '$referrals/program';
  static const String referralReferredUsers = '$referrals/referred-users';
  static const String referralLedger = '$referrals/ledger';
  static const String referralConvertToCredit = '$referrals/convert-to-credit';
  static const String referralCashPayoutRequest =
      '$referrals/cash-payout-request';

  // Payment Endpoints (payments base is /payments)
  static const String payments = '/payments';
  static const String professionalPlan = '$payments/plan/professional';
  static String examStripeCreate(String examId) =>
      '$payments/exam/$examId/stripe/create';
  static String examStripeConfirm(String examId) =>
      '$payments/exam/$examId/stripe/confirm';
  static String professionalPlanStripeCreate() =>
      '$payments/plan/professional/stripe/create';
  static String professionalPlanStripeConfirm() =>
      '$payments/plan/professional/stripe/confirm';
  static String examAppleVerify(String examId) =>
      '$payments/apple/exam/$examId/verify';
  static String professionalPlanAppleVerify() =>
      '$payments/apple/plan/professional/verify';
}
