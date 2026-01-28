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
}
