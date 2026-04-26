import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../core/error/error_handler.dart';
import '../models/plan_tier.dart';
import '../models/user_unlocks_model.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../utils/app_constants.dart';

class UserController extends GetxController {
  static const Duration _profileRefreshInterval = Duration(seconds: 15);

  final UserService _userService = UserService();
  final StorageService _storageService = StorageService();

  final Rx<UserModel?> user = Rx<UserModel?>(null);
  final Rx<PlanTier> planTier = PlanTier.starter.obs;
  final Rx<Set<String>> unlockedExamIds = Rx<Set<String>>(<String>{});
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool sessionExpired = false.obs;

  Timer? _profileRefreshTimer;
  bool _isRefreshingProfile = false;

  @override
  void onInit() {
    super.onInit();
    _loadCached();
    refreshProfile();
    _startProfileRefreshTimer();
  }

  @override
  void onClose() {
    _profileRefreshTimer?.cancel();
    super.onClose();
  }

  Future<void> applyProfile(UserModel next) async {
    user.value = next;
    _syncPlanTier();
    final userJson = jsonEncode(next.toJson());
    await _storageService.saveString(AppConstants.userDataKey, userJson);
  }

  Future<void> _loadCached() async {
    try {
      final hasSession = await _storageService.hasValidSessionArtifacts();
      if (!hasSession) {
        await _storageService.remove(AppConstants.userDataKey);
        await _storageService.remove(AppConstants.unlockedExamIdsKey);
        user.value = null;
        unlockedExamIds.value = <String>{};
        return;
      }

      final cachedUser = await _storageService.getString(
        AppConstants.userDataKey,
      );
      if (cachedUser != null && cachedUser.isNotEmpty) {
        final decoded = jsonDecode(cachedUser);
        if (decoded is Map<String, dynamic>) {
          user.value = UserModel.fromJson(decoded);
        }
      }

      final cachedUnlocked = await _storageService.getStringList(
        AppConstants.unlockedExamIdsKey,
      );
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
    planTier.value = planTierFromSubscription(user.value?.subscriptionTier);
  }

  Set<String> _extractActiveUnlockedExamIds(UserUnlocksData data) {
    return data.unlockedExams
        .where((exam) => !exam.isExpired)
        .map((exam) => exam.examId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> _refreshUnlocksCache({bool silent = false}) async {
    final response = await _userService.getMyUnlocks();
    if (response.statusCode == 401) {
      sessionExpired.value = true;
      return;
    }

    if (response.success && response.data != null) {
      await setUnlockedExamIds(_extractActiveUnlockedExamIds(response.data!));
      return;
    }

    if (!silent) {
      errorMessage.value = ErrorHandler.getMessageFromResponse(
        response,
        failureFallback: 'Failed to load unlocked exams',
      );
    }
  }

  void _startProfileRefreshTimer() {
    _profileRefreshTimer?.cancel();
    _profileRefreshTimer = Timer.periodic(_profileRefreshInterval, (_) async {
      if (sessionExpired.value || _isRefreshingProfile) return;
      final hasSession = await _storageService.hasValidSessionArtifacts();
      if (!hasSession) return;
      await refreshProfile(silent: true);
    });
  }

  Future<void> refreshProfile({bool silent = false}) async {
    if (_isRefreshingProfile) return;

    final hasSession = await _storageService.hasValidSessionArtifacts();
    if (!hasSession) return;

    _isRefreshingProfile = true;
    if (!silent) {
      isLoading.value = true;
      errorMessage.value = '';
    }

    try {
      final response = await _userService.getProfile();
      if (response.statusCode == 401) {
        sessionExpired.value = true;
      }
      if (response.success && response.data != null) {
        await applyProfile(response.data!);
        await _refreshUnlocksCache(silent: true);
        errorMessage.value = '';
      } else if (!silent) {
        errorMessage.value = ErrorHandler.getMessageFromResponse(
          response,
          failureFallback: 'Failed to load profile',
        );
      }
    } finally {
      if (!silent) {
        isLoading.value = false;
      }
      _isRefreshingProfile = false;
    }
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
    sessionExpired.value = false;
  }
}
