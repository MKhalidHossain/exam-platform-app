import 'package:get/get.dart';
import '../core/error/error_handler.dart';
import '../models/api_response.dart';
import '../models/performance_model.dart';
import '../services/api_service.dart';
import '../utils/api_endpoints.dart';

class PerformanceController extends GetxController {
  final ApiService _apiService = ApiService();

  final RxMap<String, PerformanceData> performanceByExam =
      <String, PerformanceData>{}.obs;
  final RxMap<String, bool> loadingByExam = <String, bool>{}.obs;
  final RxMap<String, String> errorByExam = <String, String>{}.obs;

  Future<void> fetchPerformance(String examId) async {
    if (examId.trim().isEmpty) return;
    if (loadingByExam[examId] == true) return;

    loadingByExam[examId] = true;
    errorByExam.remove(examId);

    final ApiResponse<PerformanceData> response =
        await _apiService.get<PerformanceData>(
      ApiEndpoints.performanceMe,
      queryParams: {'examId': examId},
      fromJson: (json) =>
          PerformanceData.fromJson(Map<String, dynamic>.from(json as Map)),
    );

    if (response.success && response.data != null) {
      performanceByExam[examId] = response.data!;
    } else {
      errorByExam[examId] =
          ErrorHandler.getMessageFromResponse(response, failureFallback: 'Failed to load performance');
    }

    loadingByExam[examId] = false;
  }
}
