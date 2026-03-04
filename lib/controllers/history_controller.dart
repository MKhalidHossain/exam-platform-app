import 'package:get/get.dart';
import '../core/error/error_handler.dart';
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
      errorMessage.value = ErrorHandler.getMessageFromResponse(response, failureFallback: 'Failed to load attempts');
    }

    isLoading.value = false;
  }

  Future<void> fetchAllAttempts({int limit = 20}) async {
    isLoading.value = true;
    errorMessage.value = '';

    final List<HistoryAttempt> allAttempts = <HistoryAttempt>[];
    AttemptsMeta? latestMeta;
    int page = 1;

    while (true) {
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

      if (!response.success || response.data == null) {
        errorMessage.value = ErrorHandler.getMessageFromResponse(
          response,
          failureFallback: 'Failed to load attempts',
        );
        break;
      }

      allAttempts.addAll(response.data!.attempts);
      latestMeta = response.data!.meta;

      final totalPages = latestMeta?.totalPages;
      if (totalPages == null || page >= totalPages) {
        break;
      }
      page += 1;
    }

    if (errorMessage.value.isEmpty) {
      attempts.assignAll(allAttempts);
      meta.value = latestMeta;
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
          ErrorHandler.getMessageFromResponse(response, failureFallback: 'Failed to load attempt details');
    }

    attemptDetailLoading[attemptId] = false;
  }
}
