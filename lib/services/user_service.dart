import 'dart:io';
import '../models/user_model.dart';
import '../models/api_response.dart';
import '../models/user_unlocks_model.dart';
import '../models/users_response.dart';
import 'api_service.dart';
import '../utils/api_endpoints.dart';

class UserService {
  final ApiService _apiService = ApiService();

  /// Get current user profile
  Future<ApiResponse<UserModel>> getProfile() async {
    return await _apiService.get<UserModel>(
      ApiEndpoints.getProfile,
      fromJson: (json) => UserModel.fromJson(json),
    );
  }

  /// Get current user unlocked exams and resources
  Future<ApiResponse<UserUnlocksData>> getMyUnlocks() async {
    return await _apiService.get<UserUnlocksData>(
      ApiEndpoints.getMyUnlocks,
      fromJson: (json) => UserUnlocksData.fromJson(json),
    );
  }

  /// Get all users (design only - no API call)
  Future<ApiResponse<UsersResponse>> getUsers({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    // Mock response for design only
    await Future.delayed(const Duration(milliseconds: 500));
    return ApiResponse<UsersResponse>(
      success: false,
      message: 'Design mode - no API calls',
    );
  }

  /// Get user details by ID (design only - no API call)
  Future<ApiResponse<UserModel>> getUserDetails(String id) async {
    // Mock response for design only
    await Future.delayed(const Duration(milliseconds: 500));
    return ApiResponse<UserModel>(
      success: false,
      message: 'Design mode - no API calls',
    );
  }

  /// Update profile with name, phone, and avatar
  Future<ApiResponse<UserModel>> updateProfile({
    String? name,
    String? phone,
    File? avatarFile,
  }) async {
    // Prepare fields
    final fields = <String, String>{};
    if (name != null && name.isNotEmpty) {
      fields['name'] = name;
    }
    if (phone != null && phone.isNotEmpty) {
      fields['phone'] = phone;
    }

    // Use multipart request if file is provided, otherwise use regular PUT
    if (avatarFile != null) {
      return await _apiService.putMultipart<UserModel>(
        ApiEndpoints.updateProfile,
        fields: fields.isNotEmpty ? fields : null,
        file: avatarFile,
        fileField: 'avatar',
        fromJson: (json) => UserModel.fromJson(json),
      );
    } else {
      // Regular PUT request without file
      return await _apiService.put<UserModel>(
        ApiEndpoints.updateProfile,
        body: fields.isNotEmpty ? fields : null,
        fromJson: (json) => UserModel.fromJson(json),
      );
    }
  }

  /// Change user password
  Future<ApiResponse<void>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final body = {'oldPassword': oldPassword, 'newPassword': newPassword};

    return await _apiService.post<void>(
      ApiEndpoints.changePassword,
      body: body,
    );
  }

  /// Update user status (design only - no API call)
  Future<ApiResponse<UserModel>> updateUserStatus({
    required String id,
    required String status,
  }) async {
    // Mock response for design only
    await Future.delayed(const Duration(milliseconds: 500));
    return ApiResponse<UserModel>(
      success: false,
      message: 'Design mode - no API calls',
    );
  }

  /// Delete user by ID
  Future<ApiResponse<void>> deleteUser(String id) async {
    return await _apiService.delete<void>(ApiEndpoints.deleteUser(id));
  }
}
