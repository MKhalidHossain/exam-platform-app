import 'package:get/get.dart';
import '../models/api_response.dart';
import '../models/history_attempt_model.dart';
import '../services/api_service.dart';
import '../utils/api_endpoints.dart';

class HistoryController extends GetxController {
  final ApiService _apiService = ApiService();

  final RxList<HistoryAttempt> attempts = <HistoryAttempt>[].obs;
  final Rx<AttemptsMeta?> meta = Rx<AttemptsMeta?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

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
}
