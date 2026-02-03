import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_exception.dart';
import '../../models/api_response.dart';

/// Centralized API & user error handling (MVC - used by Controllers and Services).
/// All UI error messages go through this class so users never see raw errors.
class ErrorHandler {
  ErrorHandler._();

  /// User-friendly message from [ApiResponse]. Never returns raw API/stack text.
  static String getMessageFromResponse<T>(ApiResponse<T> response, {
    String? successFallback,
    String? failureFallback,
  }) {
    final msg = response.message?.trim();
    if (response.success) {
      return _sanitizeForUi(msg) ?? successFallback ?? 'Success';
    }
    return _sanitizeForUi(msg) ?? failureFallback ?? 'Something went wrong. Please try again.';
  }

  /// User-friendly message from an [Exception] or [Object]. Never exposes raw error.
  static String getMessageFromException(Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is AppException) return error.userMessage;
    final str = error.toString();
    if (str.isEmpty) return fallback;
    // Map known technical phrases to user messages only
    if (str.contains('SocketException') || str.contains('Connection refused')) {
      return 'Unable to connect. Please check your internet and try again.';
    }
    if (str.contains('TimeoutException') || str.contains('timeout')) {
      return 'Request took too long. Please try again.';
    }
    if (str.contains('FormatException') || str.contains('parse')) {
      return 'Invalid response from server. Please try again later.';
    }
    return fallback;
  }

  /// User-friendly message from HTTP status code (for use when body is not JSON).
  static String getMessageFromStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Session expired. Please sign in again.';
      case 403:
        return 'You do not have permission to do this.';
      case 404:
        return 'Requested resource was not found.';
      case 422:
        return 'Invalid data. Please check your input and try again.';
      case 429:
        return 'Too many requests. Please try again in a moment.';
      case 500:
      case 502:
      case 503:
        return 'Server is temporarily unavailable. Please try again later.';
      default:
        if (statusCode >= 500) return 'Server error. Please try again later.';
        if (statusCode >= 400) return 'Request failed. Please try again.';
        return 'Something went wrong. Please try again.';
    }
  }

  /// Parse API error body (JSON) and return a single user message.
  static String getMessageFromErrorBody(String body, {int? statusCode}) {
    if (body.trim().isEmpty) {
      return statusCode != null
          ? getMessageFromStatusCode(statusCode)
          : 'Something went wrong. Please try again.';
    }
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        return statusCode != null
            ? getMessageFromStatusCode(statusCode)
            : 'Something went wrong. Please try again.';
      }
      final message = json['message'];
      if (message is String && message.trim().isNotEmpty) {
        return _sanitizeForUi(message) ?? getMessageFromStatusCode(statusCode ?? 0);
      }
      final error = json['error'];
      if (error is String && error.trim().isNotEmpty) {
        return _sanitizeForUi(error) ?? getMessageFromStatusCode(statusCode ?? 0);
      }
      final errors = json['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty && first.first is String) {
          return _sanitizeForUi(first.first as String) ?? 'Invalid input. Please check and try again.';
        }
        if (first is String) return _sanitizeForUi(first) ?? 'Invalid input. Please check and try again.';
      }
    } catch (_) {
      // Ignore parse errors; use status message
    }
    return statusCode != null
        ? getMessageFromStatusCode(statusCode)
        : 'Something went wrong. Please try again.';
  }

  static String? _sanitizeForUi(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final t = text.trim();
    // Avoid exposing stack traces or file paths
    if (t.contains('#') && t.contains('dart:') || t.contains('.dart:')) return null;
    if (t.length > 500) return '${t.substring(0, 500).trim()}…';
    return t;
  }

  /// Show error or success message in UI (SnackBar). Use this everywhere so messages are consistent.
  static void showSnackBar(
    String message, {
    bool isError = true,
    BuildContext? context,
    Duration duration = const Duration(seconds: 4),
  }) {
    final display = _sanitizeForUi(message) ?? (isError ? 'Something went wrong. Please try again.' : 'Done.');
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(display),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          duration: duration,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      Get.snackbar(
        isError ? 'Error' : 'Success',
        display,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        colorText: Colors.white,
        duration: duration,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  /// Show error SnackBar from ApiResponse (Controller layer).
  static void showFromResponse<T>(
    ApiResponse<T> response, {
    BuildContext? context,
    String? successFallback,
    String? failureFallback,
  }) {
    final msg = getMessageFromResponse<T>(
      response,
      successFallback: successFallback,
      failureFallback: failureFallback,
    );
    showSnackBar(msg, isError: !response.success, context: context);
  }

  /// Show error SnackBar from Exception (Controller layer).
  static void showFromException(Object error, {BuildContext? context, String? fallback}) {
    final msg = getMessageFromException(error, fallback: fallback ?? 'Something went wrong. Please try again.');
    showSnackBar(msg, isError: true, context: context);
  }
}
