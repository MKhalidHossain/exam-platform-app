import 'dart:convert';
import 'package:get/get.dart';
import '../models/plan_tier.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../utils/app_constants.dart';

class UserController extends GetxController {
  final UserService _userService = UserService();
  final StorageService _storageService = StorageService();

  final Rx<UserModel?> user = Rx<UserModel?>(null);
  final Rx<PlanTier> planTier = PlanTier.starter.obs;
  final Rx<Set<String>> unlockedExamIds = Rx<Set<String>>(<String>{});
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadCached();
    refreshProfile();
  }

  Future<void> applyProfile(UserModel next) async {
    final previousPlan = planTier.value;
    user.value = next;
    final fromProfile = planTierFromSubscription(user.value?.subscriptionTier);
    final nextPlan =
        (fromProfile == PlanTier.starter && unlockedExamIds.value.isNotEmpty)
            ? PlanTier.professional
            : fromProfile;
    if (previousPlan == PlanTier.professional && nextPlan == PlanTier.starter) {
      planTier.value = previousPlan;
    } else {
      planTier.value = nextPlan;
    }
    final userJson = jsonEncode(next.toJson());
    await _storageService.saveString(AppConstants.userDataKey, userJson);
  }

  Future<void> _loadCached() async {
    try {
      final cachedUser = await _storageService.getString(AppConstants.userDataKey);
      if (cachedUser != null && cachedUser.isNotEmpty) {
        final decoded = jsonDecode(cachedUser);
        if (decoded is Map<String, dynamic>) {
          user.value = UserModel.fromJson(decoded);
        }
      }

      final cachedUnlocked =
          await _storageService.getStringList(AppConstants.unlockedExamIdsKey);
      if (cachedUnlocked != null) {
        unlockedExamIds.value = cachedUnlocked.toSet();
      }
    } catch (_) {
      // Ignore cache errors and rely on fresh profile load.
    } finally {
      _syncPlanTier();
    }
  }

  void _syncPlanTier() {
    final fromProfile = planTierFromSubscription(user.value?.subscriptionTier);
    if (fromProfile == PlanTier.starter && unlockedExamIds.value.isNotEmpty) {
      planTier.value = PlanTier.professional;
      return;
    }
    planTier.value = fromProfile;
  }

  Future<void> refreshProfile() async {
    isLoading.value = true;
    errorMessage.value = '';

    final response = await _userService.getProfile();
    if (response.success && response.data != null) {
      await applyProfile(response.data!);
    } else {
      errorMessage.value = response.message ?? 'Failed to load profile';
    }

    isLoading.value = false;
  }

  Future<void> setUnlockedExamIds(Set<String> ids) async {
    unlockedExamIds.value = ids;
    await _storageService.saveStringList(
      AppConstants.unlockedExamIdsKey,
      ids.toList(),
    );
  }

  Future<void> addUnlockedExamId(String examId) async {
    final updated = <String>{...unlockedExamIds.value, examId};
    await setUnlockedExamIds(updated);
  }

  Future<void> applyProfessionalUpgrade({String? examId}) async {
    if (examId != null && examId.isNotEmpty) {
      await addUnlockedExamId(examId);
    }

    if (planTier.value != PlanTier.professional) {
      planTier.value = PlanTier.professional;
      if (user.value != null) {
        user.value = user.value!.copyWith(subscriptionTier: 'professional');
        final userJson = jsonEncode(user.value!.toJson());
        await _storageService.saveString(AppConstants.userDataKey, userJson);
      }
    }
  }

  Future<void> clearState() async {
    user.value = null;
    planTier.value = PlanTier.starter;
    unlockedExamIds.value = <String>{};
    isLoading.value = false;
    errorMessage.value = '';
  }
}
