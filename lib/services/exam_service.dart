import '../models/api_response.dart';
import '../models/exam_model.dart';
import '../models/start_exam_model.dart';
import '../utils/api_endpoints.dart';
import 'api_service.dart';

class ExamService {
  final ApiService _apiService = ApiService();

  List<String?> _examTypeCandidates(String? examType) {
    final trimmed = examType?.trim();
    if (trimmed == null || trimmed.isEmpty) return const [null];

    final candidates = <String>[];
    final seen = <String>{};

    void add(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty) return;
      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        candidates.add(normalized);
      }
    }

    final lower = trimmed.toLowerCase();
    add(trimmed);
    if (lower.contains('_')) {
      add(lower.replaceAll('_', ' '));
    }
    if (lower.contains(' ')) {
      add(lower.replaceAll(' ', '_'));
    }

    switch (lower) {
      case 'full_exam':
        add('full exam');
        add('open_book');
        add('closed_book');
        add('open book');
        add('closed book');
        break;
      case 'standard':
        add('open_book');
        add('closed_book');
        add('open book');
        add('closed book');
        break;
      case 'open_book':
        add('open book');
        break;
      case 'closed_book':
        add('closed book');
        break;
      case 'open book':
        add('open_book');
        break;
      case 'closed book':
        add('closed_book');
        break;
    }

    return candidates;
  }

  bool _shouldRetryStartExam(String? message) {
    final lowered = message?.toLowerCase() ?? '';
    return lowered.contains('question service error');
  }

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
    bool recreate = false,
    String? examType,
  }) async {
    final candidates = _examTypeCandidates(examType);
    ApiResponse<StartExamData>? lastResponse;

    for (final candidate in candidates) {
      final body = <String, dynamic>{
        'n_question': questionCount,
        'recreate': recreate,
      };
      if (candidate != null && candidate.trim().isNotEmpty) {
        body['exam_type'] = candidate.trim();
      }

      lastResponse = await _apiService.post<StartExamData>(
        ApiEndpoints.examStart(examId),
        body: body,
        fromJson: (json) {
          if (json is Map<String, dynamic>) {
            return StartExamData.fromJson(json);
          }
          return StartExamData.fromJson(const <String, dynamic>{});
        },
      );

      if (lastResponse.success) {
        return lastResponse;
      }
      if (!_shouldRetryStartExam(lastResponse.message)) {
        break;
      }
    }

    return lastResponse ??
        ApiResponse<StartExamData>(
          success: false,
          message: 'Failed to start the exam.',
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
