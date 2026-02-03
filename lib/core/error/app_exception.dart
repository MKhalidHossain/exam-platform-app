/// Application exception with user-friendly message (MVC - Model/Error layer).
/// Never expose raw stack traces or technical errors to the UI.
class AppException implements Exception {
  final String userMessage;
  final String? code;
  final int? statusCode;

  const AppException({
    required this.userMessage,
    this.code,
    this.statusCode,
  });

  @override
  String toString() => userMessage;
}
