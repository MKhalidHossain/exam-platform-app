import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import '../models/auth_response.dart';
import '../models/otp_response.dart';
import '../utils/app_constants.dart';
import '../utils/api_endpoints.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService _storageService = StorageService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storageService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint')
          .replace(queryParameters: queryParams);
      
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(AppConstants.apiTimeout);

      return _handleResponse<T>(response, fromJson);
    } on SocketException catch (e) {
      debugPrint('❌ HTTP GET Error - SocketException:');
      debugPrint('   Error: $e');
      
      String errorMessage = 'Cannot connect to server. Please check:\n'
          '• Server is running\n'
          '• Network connection\n'
          '• Server address: ${AppConstants.baseUrl}';
      
      return ApiResponse<T>(
        success: false,
        message: errorMessage,
      );
    } catch (e) {
      String errorMessage = 'Network error occurred';
      if (e.toString().contains('Connection refused')) {
        errorMessage = 'Connection refused. Server may be down or unreachable at ${AppConstants.baseUrl}';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timeout. Please check your connection and try again.';
      } else {
        errorMessage = 'Network error: ${e.toString()}';
      }
      
      return ApiResponse<T>(
        success: false,
        message: errorMessage,
      );
    }
  }

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      final headers = await _getHeaders();
      final bodyJson = body != null ? jsonEncode(body) : null;
      
      debugPrint('📡 HTTP POST Request:');
      debugPrint('   URL: $uri');
      debugPrint('   Headers: $headers');
      debugPrint('   Body: $bodyJson');
      
      final response = await http
          .post(
            uri,
            headers: headers,
            body: bodyJson,
          )
          .timeout(AppConstants.apiTimeout);

      debugPrint('📡 HTTP POST Response:');
      debugPrint('   Status Code: ${response.statusCode}');
      debugPrint('   Response Body: ${response.body}');
      debugPrint('   Response Headers: ${response.headers}');

      return _handleResponse<T>(response, fromJson);
    } on SocketException catch (e) {
      debugPrint('❌ HTTP POST Error - SocketException:');
      debugPrint('   Error: $e');
      debugPrint('   Address: ${e.address}');
      debugPrint('   Port: ${e.port}');
      
      String errorMessage = 'Cannot connect to server. Please check:\n'
          '• Server is running\n'
          '• Network connection\n'
          '• Server address: ${AppConstants.baseUrl}';
      
      return ApiResponse<T>(
        success: false,
        message: errorMessage,
      );
    } on HttpException catch (e) {
      debugPrint('❌ HTTP POST Error - HttpException:');
      debugPrint('   Error: $e');
      
      return ApiResponse<T>(
        success: false,
        message: 'HTTP error: ${e.message}',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ HTTP POST Error:');
      debugPrint('   Error: $e');
      debugPrint('   Stack Trace: $stackTrace');
      
      String errorMessage = 'Network error occurred';
      if (e.toString().contains('Connection refused')) {
        errorMessage = 'Connection refused. Server may be down or unreachable at ${AppConstants.baseUrl}';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timeout. Please check your connection and try again.';
      } else {
        errorMessage = 'Network error: ${e.toString()}';
      }
      
      return ApiResponse<T>(
        success: false,
        message: errorMessage,
      );
    }
  }

  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      
      final response = await http
          .put(
            uri,
            headers: await _getHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConstants.apiTimeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<T>> putMultipart<T>(
    String endpoint, {
    Map<String, String>? fields,
    File? file,
    String fileField = 'avatar',
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      final token = await _storageService.getToken();
      
      final request = http.MultipartRequest('PUT', uri);
      
      // Add headers
      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // Add fields
      if (fields != null) {
        request.fields.addAll(fields);
      }
      
      // Add file if provided
      if (file != null && await file.exists()) {
        final fileStream = http.ByteStream(file.openRead());
        final fileLength = await file.length();
        final fileName = file.path.split('/').last;
        
        final multipartFile = http.MultipartFile(
          fileField,
          fileStream,
          fileLength,
          filename: fileName,
        );
        request.files.add(multipartFile);
      }
      
      debugPrint('📡 HTTP PUT Multipart Request:');
      debugPrint('   URL: $uri');
      debugPrint('   Fields: $fields');
      debugPrint('   File: ${file?.path}');
      
      final streamedResponse = await request.send().timeout(AppConstants.apiTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('📡 HTTP PUT Multipart Response:');
      debugPrint('   Status Code: ${response.statusCode}');
      debugPrint('   Response Body: ${response.body}');
      
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      debugPrint('❌ HTTP PUT Multipart Error:');
      debugPrint('   Error: $e');
      return ApiResponse<T>(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<T>> postMultipart<T>(
    String endpoint, {
    Map<String, String>? fields,
    File? file,
    String fileField = 'attachment',
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      final token = await _storageService.getToken();

      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (fields != null) {
        request.fields.addAll(fields);
      }

      if (file != null && await file.exists()) {
        final fileStream = http.ByteStream(file.openRead());
        final fileLength = await file.length();
        final fileName = file.path.split('/').last;

        final multipartFile = http.MultipartFile(
          fileField,
          fileStream,
          fileLength,
          filename: fileName,
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send().timeout(AppConstants.apiTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      debugPrint('❌ HTTP POST Multipart Error: $e');
      return ApiResponse<T>(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      
      final response = await http
          .delete(uri, headers: await _getHeaders())
          .timeout(AppConstants.apiTimeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic)? fromJson,
  ) {
    try {
      final jsonData = jsonDecode(response.body);
      
      debugPrint('🔍 Parsing Response:');
      debugPrint('   Status Code: ${response.statusCode}');
      debugPrint('   Response Structure: $jsonData');
      
      // Handle response structure: {success: true, message: "...", data: {...}}
      final success = jsonData['success'] ?? (response.statusCode >= 200 && response.statusCode < 300);
      final message = jsonData['message'] is String 
          ? jsonData['message'] 
          : jsonData['message']?.toString() ?? 'Request completed';
      final responseData = jsonData['data'];
      
      if (success) {
        T? parsedData;
        if (responseData != null && fromJson != null) {
          try {
            // Ensure responseData is a Map before passing to fromJson
            if (responseData is Map<String, dynamic>) {
              parsedData = fromJson(responseData);
            } else {
              debugPrint('⚠️ Response data is not a Map: ${responseData.runtimeType}');
              parsedData = fromJson(responseData);
            }
          } catch (e, stackTrace) {
            debugPrint('❌ Error parsing data with fromJson:');
            debugPrint('   Error: $e');
            debugPrint('   Stack Trace: $stackTrace');
            debugPrint('   Response Data: $responseData');
            // Return success but without parsed data
            parsedData = null;
          }
        } else {
          parsedData = responseData as T?;
        }
        
        return ApiResponse<T>(
          success: true,
          message: message,
          data: parsedData,
        );
      } else {
        return ApiResponse<T>(
          success: false,
          message: message,
          error: jsonData['error'],
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _handleResponse:');
      debugPrint('   Error: $e');
      debugPrint('   Stack Trace: $stackTrace');
      debugPrint('   Response Body: ${response.body}');
      
      return ApiResponse<T>(
        success: false,
        message: 'Failed to parse response: ${e.toString()}',
      );
    }
  }

  // User Registration
  Future<ApiResponse<AuthResponse>> register({
    required String phone,
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final body = {
      'phone': phone,
      'name': name,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
    };

    // Convert to JSON string to show exact format
    final bodyJson = jsonEncode(body);
    
    debugPrint('🌐 API Service - Register Request:');
    debugPrint('   Endpoint: ${AppConstants.baseUrl}${ApiEndpoints.register}');
    debugPrint('   Method: POST');
    debugPrint('   Content-Type: application/json');
    debugPrint('   Body (JSON): $bodyJson');
    debugPrint('   Body (Map): $body');

    final response = await post<AuthResponse>(
      ApiEndpoints.register,
      body: body,
      fromJson: (json) => AuthResponse.fromJson(json),
    );

    debugPrint('🌐 API Service - Register Response:');
    debugPrint('   Success: ${response.success}');
    debugPrint('   Message: ${response.message}');
    debugPrint('   Has Data: ${response.data != null}');

    // Store tokens if registration is successful
    if (response.success && response.data != null) {
      debugPrint('💾 Storing authentication tokens...');
      if (response.data!.accessToken != null) {
        await _storageService.saveToken(response.data!.accessToken!);
        debugPrint('   ✅ Access token saved');
      }
      if (response.data!.refreshToken != null) {
        await _storageService.saveRefreshToken(response.data!.refreshToken!);
        debugPrint('   ✅ Refresh token saved');
      }
      if (response.data!.userId != null) {
        await _storageService.saveUserId(response.data!.userId!);
        debugPrint('   ✅ User ID saved');
      }
    } else {
      debugPrint('❌ Registration failed - tokens not stored');
    }

    return response;
  }

  // Forgot Password (Request OTP)
  Future<ApiResponse<OtpResponse>> forgotPassword({
    required String email,
  }) async {
    final body = {
      'email': email,
    };

    // Convert to JSON string to show exact format
    final bodyJson = jsonEncode(body);
    
    debugPrint('🌐 API Service - Forgot Password Request:');
    debugPrint('   Endpoint: ${AppConstants.baseUrl}${ApiEndpoints.forgetPassword}');
    debugPrint('   Method: POST');
    debugPrint('   Content-Type: application/json');
    debugPrint('   Body (JSON): $bodyJson');
    debugPrint('   Body (Map): $body');

    final response = await post<OtpResponse>(
      ApiEndpoints.forgetPassword,
      body: body,
      fromJson: (json) => OtpResponse.fromJson(json),
    );

    debugPrint('🌐 API Service - Forgot Password Response:');
    debugPrint('   Success: ${response.success}');
    debugPrint('   Message: ${response.message}');
    debugPrint('   Has Data: ${response.data != null}');

    return response;
  }

  // Verify OTP and Reset Password
  Future<ApiResponse<Map<String, dynamic>>> verifyOtp({
    required String email,
    required String otp,
    required String password,
  }) async {
    final body = {
      'email': email,
      'otp': otp,
      'password': password,
    };

    // Convert to JSON string to show exact format
    final bodyJson = jsonEncode(body);
    
    debugPrint('🌐 API Service - Verify OTP & Reset Password Request:');
    debugPrint('   Endpoint: ${AppConstants.baseUrl}${ApiEndpoints.resetPassword}');
    debugPrint('   Method: POST');
    debugPrint('   Content-Type: application/json');
    debugPrint('   Body (JSON): $bodyJson');
    debugPrint('   Body (Map): $body');

    final response = await post<Map<String, dynamic>>(
      ApiEndpoints.resetPassword,
      body: body,
      fromJson: (json) => json as Map<String, dynamic>,
    );

    debugPrint('🌐 API Service - Verify OTP & Reset Password Response:');
    debugPrint('   Success: ${response.success}');
    debugPrint('   Message: ${response.message}');
    debugPrint('   Has Data: ${response.data != null}');

    return response;
  }

  // User Login
  Future<ApiResponse<AuthResponse>> login({
    required String email,
    required String password,
  }) async {
    final body = {
      'email': email,
      'password': password,
    };

    // Convert to JSON string to show exact format
    final bodyJson = jsonEncode(body);
    
    debugPrint('🌐 API Service - Login Request:');
    debugPrint('   Endpoint: ${AppConstants.baseUrl}${ApiEndpoints.login}');
    debugPrint('   Method: POST');
    debugPrint('   Content-Type: application/json');
    debugPrint('   Body (JSON): $bodyJson');
    debugPrint('   Body (Map): $body');

    final response = await post<AuthResponse>(
      ApiEndpoints.login,
      body: body,
      fromJson: (json) => AuthResponse.fromJson(json),
    );

    debugPrint('🌐 API Service - Login Response:');
    debugPrint('   Success: ${response.success}');
    debugPrint('   Message: ${response.message}');
    debugPrint('   Has Data: ${response.data != null}');

    // Store tokens and user data if login is successful
    if (response.success && response.data != null) {
      debugPrint('💾 Storing authentication data...');
      
      if (response.data!.accessToken != null) {
        await _storageService.saveToken(response.data!.accessToken!);
        debugPrint('   ✅ Access token saved');
      }
      
      if (response.data!.refreshToken != null) {
        await _storageService.saveRefreshToken(response.data!.refreshToken!);
        debugPrint('   ✅ Refresh token saved');
      }
      
      if (response.data!.userId != null) {
        await _storageService.saveUserId(response.data!.userId!);
        debugPrint('   ✅ User ID saved: ${response.data!.userId}');
      }
      
      // Store role if available
      if (response.data!.role != null) {
        await _storageService.saveString('user_role', response.data!.role!);
        debugPrint('   ✅ Role saved: ${response.data!.role}');
      }
      
      // Store user data as JSON string
      if (response.data!.user != null) {
        final userJson = jsonEncode(response.data!.user!.toJson());
        await _storageService.saveString('user_data', userJson);
        debugPrint('   ✅ User data saved');
      }
      
      // Set logged in status
      await _storageService.setLoggedIn(true);
      debugPrint('   ✅ Login status set to true');
    } else {
      debugPrint('❌ Login failed - data not stored');
    }

    return response;
  }

  /// Create Stripe Payment Intent for exam unlock. POST {{base_url}}/api/v1/payments/exam/:examId/stripe/create
  Future<ApiResponse<Map<String, dynamic>>> createExamStripePaymentIntent(
    String examId,
  ) async {
    return post<Map<String, dynamic>>(
      ApiEndpoints.examStripeCreate(examId),
      fromJson: (json) =>
          json is Map<String, dynamic> ? json : Map<String, dynamic>.from(json as Map),
    );
  }

  /// Confirm Stripe payment after PaymentSheet success. POST {{base_url}}/api/v1/payments/exam/:examId/stripe/confirm
  Future<ApiResponse<Map<String, dynamic>>> confirmExamStripePayment(
    String examId,
    String paymentIntentId,
  ) async {
    return post<Map<String, dynamic>>(
      ApiEndpoints.examStripeConfirm(examId),
      body: {'paymentIntentId': paymentIntentId},
      fromJson: (json) =>
          json is Map<String, dynamic> ? json : Map<String, dynamic>.from(json as Map),
    );
  }

  /// Create support ticket (Help & Support). POST {{base_url}}/api/v1/support
  /// Requires auth. Optional attachment field name is "attachment".
  Future<ApiResponse<Map<String, dynamic>>> createSupportTicket({
    required String email,
    required String subject,
    required String description,
    String? phone,
    File? attachment,
  }) async {
    final fields = <String, String>{
      'email': email.trim(),
      'subject': subject.trim(),
      'description': description.trim(),
    };
    if (phone != null && phone.trim().isNotEmpty) {
      fields['phone'] = phone.trim();
    }
    return postMultipart<Map<String, dynamic>>(
      ApiEndpoints.support,
      fields: fields,
      file: attachment,
      fileField: 'attachment',
      fromJson: (json) => json is Map<String, dynamic> ? json : Map<String, dynamic>.from(json as Map),
    );
  }
}
