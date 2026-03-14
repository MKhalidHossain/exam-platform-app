import '../models/api_response.dart';
import '../models/referral_model.dart';
import '../utils/api_endpoints.dart';
import 'api_service.dart';

class ReferralService {
  final ApiService _apiService = ApiService();

  Future<ApiResponse<ReferralPublicCode>> getPublicReferralCode(String code) {
    return _apiService.get<ReferralPublicCode>(
      ApiEndpoints.referralPublicCode(code),
      fromJson: (json) => ReferralPublicCode.fromJson(_asMap(json)),
    );
  }

  Future<ApiResponse<ReferralProfile>> getMyReferralProfile() {
    return _apiService.get<ReferralProfile>(
      ApiEndpoints.referralProfile,
      fromJson: (json) => ReferralProfile.fromJson(_asMap(json)),
    );
  }

  Future<ApiResponse<ReferralProgram>> getMyReferralProgram() {
    return _apiService.get<ReferralProgram>(
      ApiEndpoints.referralProgram,
      fromJson: (json) => ReferralProgram.fromJson(_asMap(json)),
    );
  }

  Future<ApiResponse<ReferralReferredUsersData>> getMyReferredUsers({
    int page = 1,
    int limit = 20,
  }) {
    return _apiService.get<ReferralReferredUsersData>(
      ApiEndpoints.referralReferredUsers,
      queryParams: {'page': page.toString(), 'limit': limit.toString()},
      fromJson: (json) => ReferralReferredUsersData.fromJson(_asMap(json)),
    );
  }

  Future<ApiResponse<ReferralLedgerData>> getMyReferralLedger({
    int page = 1,
    int limit = 20,
  }) {
    return _apiService.get<ReferralLedgerData>(
      ApiEndpoints.referralLedger,
      queryParams: {'page': page.toString(), 'limit': limit.toString()},
      fromJson: (json) => ReferralLedgerData.fromJson(_asMap(json)),
    );
  }

<<<<<<< HEAD
  Future<ApiResponse<Map<String, dynamic>>> convertToAppCredit({double? amount}) {
    return _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.referralConvertToCredit,
      body: amount != null ? {'amount': amount} : const <String, dynamic>{},
=======
  Future<ApiResponse<Map<String, dynamic>>> convertToCredit({double? amount}) {
    return _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.referralConvertToCredit,
      body: {'amount': amount},
>>>>>>> 8605f6adb60b6fa8bd5e87f729391d0a6530337f
      fromJson: (json) => _asMap(json),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> requestCashPayout({
    double? amount,
  }) {
    return _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.referralCashPayoutRequest,
<<<<<<< HEAD
      body: amount != null ? {'amount': amount} : const <String, dynamic>{},
=======
      body: {'amount': amount},
>>>>>>> 8605f6adb60b6fa8bd5e87f729391d0a6530337f
      fromJson: (json) => _asMap(json),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}
