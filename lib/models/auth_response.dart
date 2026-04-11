import 'package:flutter/foundation.dart';
import 'user_model.dart';

class AuthResponse {
  final String? accessToken;
  final String? refreshToken;
  final String? role;
  final String? userId;
  final UserModel? user;
  final bool mustChangePassword;

  AuthResponse({
    this.accessToken,
    this.refreshToken,
    this.role,
    this.userId,
    this.user,
    this.mustChangePassword = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    try {
      // Handle both registration (user data at top level) and login (nested user) responses
      // The backend returns user data with accessToken at the top level
      final userData =
          json['user'] ??
          json; // If no 'user' key, use the entire json as user data

      // Safely extract string fields, handling cases where they might be null or different types
      String? getStringValue(dynamic value) {
        if (value == null) return null;
        if (value is String) return value;
        return value.toString();
      }

      bool getBoolValue(dynamic value) {
        if (value is bool) return value;
        if (value is num) return value != 0;
        if (value is String) {
          final normalized = value.toLowerCase().trim();
          return normalized == 'true' || normalized == '1';
        }
        return false;
      }

      // Safely extract userId
      String? extractUserId(Map<String, dynamic> data) {
        if (data['_id'] != null) {
          return getStringValue(data['_id']);
        }
        if (data['userId'] != null) {
          return getStringValue(data['userId']);
        }
        if (data['id'] != null) {
          return getStringValue(data['id']);
        }
        return null;
      }

      // Parse user model safely
      UserModel? parsedUser;
      if (userData is Map<String, dynamic>) {
        try {
          parsedUser = UserModel.fromJson(userData);
        } catch (e) {
          // If user parsing fails, continue without user data
          debugPrint('Warning: Failed to parse user data: $e');
        }
      }

      return AuthResponse(
        accessToken: getStringValue(json['accessToken']),
        refreshToken: getStringValue(json['refreshToken']),
        role: getStringValue(json['role']),
        userId: extractUserId(json),
        user: parsedUser,
        mustChangePassword:
            getBoolValue(json['mustChangePassword']) ||
            getBoolValue(
              userData is Map ? userData['mustChangePassword'] : null,
            ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing AuthResponse: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'role': role,
      '_id': userId,
      'mustChangePassword': mustChangePassword,
      'user': user?.toJson(),
    };
  }
}
