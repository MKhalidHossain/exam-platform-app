import 'package:get/get.dart';
import '../models/api_response.dart';
import '../models/history_attempt_model.dart';
import '../models/history_attempt_detail_model.dart';
import '../services/api_service.dart';
import '../utils/api_endpoints.dart';

class HistoryController extends GetxController {
  final ApiService _apiService = ApiService();

  final RxList<HistoryAttempt> attempts = <HistoryAttempt>[].obs;
  final Rx<AttemptsMeta?> meta = Rx<AttemptsMeta?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  final RxMap<String, HistoryAttemptDetail> attemptDetails =
      <String, HistoryAttemptDetail>{}.obs;
  final RxMap<String, bool> attemptDetailLoading = <String, bool>{}.obs;
  final RxMap<String, String> attemptDetailErrors = <String, String>{}.obs;

  Future<void> fetchAttempts({int page = 1, int limit = 10}) async {
    isLoading.value = true;
    errorMessage.value = '';

    final ApiResponse<HistoryAttemptsData> response =
        await _apiService.get<HistoryAttemptsData>(
      ApiEndpoints.historyAttempts,
      queryParams: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
      fromJson: (json) => HistoryAttemptsData.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );

    if (response.success && response.data != null) {
      attempts.assignAll(response.data!.attempts);
      meta.value = response.data!.meta;
    } else {
      errorMessage.value = response.message ?? 'Failed to load attempts';
    }

    isLoading.value = false;
  }

  Future<void> fetchAttemptDetail(String attemptId) async {
    if (attemptId.trim().isEmpty) return;
    attemptDetailLoading[attemptId] = true;
    attemptDetailErrors.remove(attemptId);

    final ApiResponse<HistoryAttemptDetail> response =
        await _apiService.get<HistoryAttemptDetail>(
      ApiEndpoints.historyAttemptDetail(attemptId),
      fromJson: (json) => HistoryAttemptDetail.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );

    if (response.success && response.data != null) {
      attemptDetails[attemptId] = response.data!;
    } else {
      attemptDetailErrors[attemptId] =
          response.message ?? 'Failed to load attempt details';
    }

    attemptDetailLoading[attemptId] = false;
  }
}
