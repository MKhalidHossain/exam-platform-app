import '../models/api_response.dart';
import '../models/exam_model.dart';
import '../utils/api_endpoints.dart';
import 'api_service.dart';

class ExamService {
  final ApiService _apiService = ApiService();

  Future<ApiResponse<List<ExamModel>>> getActiveExams() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.exams,
      fromJson: (json) => json as Map<String, dynamic>,
    );

    if (!response.success) {
      return ApiResponse<List<ExamModel>>(
        success: false,
        message: response.message,
        error: response.error,
      );
    }

    final data = response.data;
    final examsRaw = (data is Map<String, dynamic>) ? data['exams'] : null;
    final examsList = (examsRaw is List) ? examsRaw : const [];

    final exams = examsList
        .whereType<Map>()
        .map((e) => ExamModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return ApiResponse<List<ExamModel>>(
      success: true,
      message: response.message,
      data: exams,
    );
  }
}

