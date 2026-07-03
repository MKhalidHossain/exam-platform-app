import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../core/error/error_handler.dart';
import '../models/plan_tier.dart';
import '../models/user_model.dart';
import '../models/user_unlocks_model.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../utils/app_constants.dart';

class UserController extends GetxController with WidgetsBindingObserver {
  final UserService _userService = UserService();
  final StorageService _storageService = StorageService();

  final Rx<UserModel?> user = Rx<UserModel?>(null);
  final Rx<PlanTier> planTier = PlanTier.starter.obs;
  final Rx<Set<String>> unlockedExamIds = Rx<Set<String>>(<String>{});
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool sessionExpired = false.obs;

  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 60);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _loadCached();
    refreshProfile();
    _startPolling();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.onClose();
  }

  // Refresh profile immediately when user brings the app to foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && user.value != null) {
      refreshProfile();
    }
  }

  void _startPolling() {
    _stopPolling();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      if (user.value != null) {
        refreshProfile();
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> applyProfile(UserModel next) async {
    user.value = next;
    final fromProfile = planTierFromSubscription(user.value?.subscriptionTier);
    planTier.value = fromProfile;
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
    final fromProfile = planTierFromSubscription(user.value?.subscriptionTier);
    planTier.value = fromProfile;
  }

  Future<void> refreshProfile() async {
    isLoading.value = true;
    errorMessage.value = '';

    // Start both requests in parallel — unlock IDs must be server-fresh so
    // that an admin-forced downgrade clears stale local unlock data.
    final profileFuture = _userService.getProfile();
    final unlocksFuture = _userService.getMyUnlocks();
    final profileResponse = await profileFuture;
    final unlocksResponse = await unlocksFuture;

    if (profileResponse.statusCode == 401) {
      sessionExpired.value = true;
    }
    if (profileResponse.success && profileResponse.data != null) {
      // Sync unlock IDs from the server before computing plan tier.
      if (unlocksResponse.success && unlocksResponse.data != null) {
        final freshIds = _activeExamIds(unlocksResponse.data!);
        await setUnlockedExamIds(freshIds);
      }
      await applyProfile(profileResponse.data!);
      // Restart polling if it was stopped (e.g. after logout + re-login).
      if (_pollingTimer == null || !_pollingTimer!.isActive) {
        _startPolling();
      }
    } else {
      errorMessage.value = ErrorHandler.getMessageFromResponse(
        profileResponse,
        failureFallback: 'Failed to load profile',
      );
    }

    isLoading.value = false;
  }

  Set<String> _activeExamIds(UserUnlocksData data) {
    return data.unlockedExams
        .where((e) => !e.isExpired && e.examId.isNotEmpty)
        .map((e) => e.examId)
        .toSet();
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
    _stopPolling();
    user.value = null;
    planTier.value = PlanTier.starter;
    unlockedExamIds.value = <String>{};
    isLoading.value = false;
    errorMessage.value = '';
    sessionExpired.value = false;
  }
}
