import '../models/api_response.dart';
import '../models/exam_model.dart';
import '../models/start_exam_model.dart';
import '../utils/api_endpoints.dart';
import '../utils/app_constants.dart';
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

  Future<ApiResponse<StartExamData>> startExam({
    required String examId,
    required int questionCount,
    bool regenerate = false,
  }) async {
    final body = <String, dynamic>{
      'n_question': questionCount,
      'regenerate': regenerate,
    };

    return _apiService.post<StartExamData>(
      ApiEndpoints.examStart(examId),
      body: body,
      fromJson: (json) {
        if (json is Map<String, dynamic>) {
          return StartExamData.fromJson(json);
        }
        return StartExamData.fromJson(const <String, dynamic>{});
      },
      timeout: AppConstants.examGenerationTimeout,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> submitExam({
    required String examId,
    required List<dynamic> answers,
    List<String>? flaggedQuestionIds,
    List<int>? timeSpentSec,
  }) async {
    final body = <String, dynamic>{
      'answers': answers,
    };
    if (flaggedQuestionIds != null) {
      body['flaggedQuestionIds'] = flaggedQuestionIds;
    }
    if (timeSpentSec != null) {
      body['timeSpent'] = timeSpentSec;
    }

    return _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.examSubmit(examId),
      body: body,
      fromJson: (json) => json is Map<String, dynamic>
          ? json
          : Map<String, dynamic>.from(json as Map),
    );
  }
}
