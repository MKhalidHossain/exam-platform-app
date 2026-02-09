import 'package:get/get.dart';
import '../core/error/error_handler.dart';
import '../models/api_response.dart';
import '../models/announcement_model.dart';
import '../models/exam_model.dart';
import '../services/api_service.dart';
import '../utils/api_endpoints.dart';

class HomeController extends GetxController {
  final ApiService _apiService = ApiService();

  final RxList<Exam> exams = <Exam>[].obs;
  final Rx<ExamsMeta?> meta = Rx<ExamsMeta?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<Announcement> announcements = <Announcement>[].obs;
  final Rx<AnnouncementsMeta?> announcementsMeta =
      Rx<AnnouncementsMeta?>(null);
  final RxBool isAnnouncementLoading = false.obs;
  final RxString announcementError = ''.obs;
  final RxBool sessionExpired = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchActiveExams();
    fetchAnnouncements();
  }

  void clearState() {
    exams.clear();
    meta.value = null;
    isLoading.value = false;
    errorMessage.value = '';
    announcements.clear();
    announcementsMeta.value = null;
    isAnnouncementLoading.value = false;
    announcementError.value = '';
    sessionExpired.value = false;
  }

  Future<void> fetchActiveExams() async {
    isLoading.value = true;
    errorMessage.value = '';

    final ApiResponse<ActiveExamsData> response =
        await _apiService.get<ActiveExamsData>(
      ApiEndpoints.exams,
      fromJson: (json) => ActiveExamsData.fromJson(json),
    );

    if (response.statusCode == 401) {
      sessionExpired.value = true;
    }

    if (response.success && response.data != null) {
      exams.assignAll(response.data!.exams);
      meta.value = response.data!.meta;
    } else {
      errorMessage.value = ErrorHandler.getMessageFromResponse(response, failureFallback: 'Failed to load exams');
    }

    isLoading.value = false;
  }

  Future<void> fetchAnnouncements() async {
    isAnnouncementLoading.value = true;
    announcementError.value = '';

    final ApiResponse<AnnouncementsData> response =
        await _apiService.get<AnnouncementsData>(
      ApiEndpoints.announcement,
      fromJson: (json) => AnnouncementsData.fromJson(json),
    );

    if (response.statusCode == 401) {
      sessionExpired.value = true;
    }

    if (response.success && response.data != null) {
      announcements.assignAll(response.data!.announcements);
      announcementsMeta.value = response.data!.meta;
    } else {
      announcementError.value = ErrorHandler.getMessageFromResponse(
        response,
        failureFallback: 'Failed to load announcements',
      );
    }

    isAnnouncementLoading.value = false;
  }
}
