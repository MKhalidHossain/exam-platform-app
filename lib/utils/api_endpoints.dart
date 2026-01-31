class ApiEndpoints {
  // Base paths
  static const String auth = '/auth';
  static const String user = '/user';

  // Auth Endpoints
  static const String register = '$auth/register';
  static const String login = '$auth/login';
  static const String verifyEmail = '$auth/verify';
  static const String forgetPassword = '$auth/forget';
  static const String resetPassword = '$auth/reset-password';
  static const String changePassword = '$auth/change-password';
  static const String refreshToken = '$auth/refresh-token';
  static const String logout = '$auth/logout';

  // User Endpoints
  static const String getUsers = user;
  static const String getProfile = '$user/profile';
  static const String updateProfile = '$user/profile';
  static const String updateUserPassword = '$user/password';
  static String getUserDetails(String id) => '$user/$id';
  static String updateUserStatus(String id) => '$user/$id/status';
  static String deleteUser(String id) => '$user/$id';

  // Exam Endpoints
  static const String exams = '/exam';

  // Analytics Endpoints
  static const String historyAttempts = '/analytics/history/attempts';

  // Support Endpoints
  static const String support = '/support';

  // Payment Endpoints (payments base is /payments)
  static const String payments = '/payments';
  static const String professionalPlan = '$payments/plan/professional';
  static String examStripeCreate(String examId) => '$payments/exam/$examId/stripe/create';
  static String examStripeConfirm(String examId) => '$payments/exam/$examId/stripe/confirm';
  static String professionalPlanStripeCreate() => '$payments/plan/professional/stripe/create';
  static String professionalPlanStripeConfirm() => '$payments/plan/professional/stripe/confirm';
}
