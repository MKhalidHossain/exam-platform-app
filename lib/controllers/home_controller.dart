import 'package:get/get.dart';
import '../models/api_response.dart';
import '../models/exam_model.dart';
import '../services/api_service.dart';
import '../utils/api_endpoints.dart';

class HomeController extends GetxController {
  final ApiService _apiService = ApiService();

  final RxList<Exam> exams = <Exam>[].obs;
  final Rx<ExamsMeta?> meta = Rx<ExamsMeta?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchActiveExams();
  }

  void clearState() {
    exams.clear();
    meta.value = null;
    isLoading.value = false;
    errorMessage.value = '';
  }

  Future<void> fetchActiveExams() async {
    isLoading.value = true;
    errorMessage.value = '';

    final ApiResponse<ActiveExamsData> response =
        await _apiService.get<ActiveExamsData>(
      ApiEndpoints.exams,
      fromJson: (json) => ActiveExamsData.fromJson(json),
    );

    if (response.success && response.data != null) {
      exams.assignAll(response.data!.exams);
      meta.value = response.data!.meta;
    } else {
      errorMessage.value = response.message ?? 'Failed to load exams';
    }

    isLoading.value = false;
  }
}
