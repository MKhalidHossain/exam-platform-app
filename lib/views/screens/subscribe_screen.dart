import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/user_controller.dart';
import '../../core/error/error_handler.dart';
import '../../models/api_response.dart';
import '../../models/exam_model.dart';
import '../../models/payment_success_details.dart';
import '../../models/plan_tier.dart';
import '../../models/professional_plan_model.dart';
import '../../models/referral_model.dart';
import '../../services/api_service.dart';
import '../../services/exam_service.dart';
import '../../services/storage_service.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/gradient_background.dart';
import '../widgets/unlock_exam_dialog.dart';

class SubscribeScreen extends StatefulWidget {
  const SubscribeScreen({super.key});

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  final ExamService _examService = ExamService();
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  late final UserController _userController;
  bool _isPaymentLoading = false;

  ProfessionalPlanModel? professionalPlan;
  bool planLoading = true;
  String? planError;

  @override
  void initState() {
    super.initState();
    _userController = Get.isRegistered<UserController>()
        ? Get.find<UserController>()
        : Get.put(UserController());
    _loadProfessionalPlan();
  }

  Future<void> _loadProfessionalPlan() async {
    setState(() {
      planLoading = true;
      planError = null;
    });
    final res = await _apiService.getProfessionalPlan();
    if (!mounted) return;
    setState(() {
      planLoading = false;
      if (res.success && res.data != null) {
        professionalPlan = res.data;
      } else {
        planError = ErrorHandler.getMessageFromResponse(
          res,
          failureFallback: 'Failed to load plan',
        );
      }
    });
  }

  num? _parseCheckoutAmount(dynamic value) {
    if (value is num) return value;
    if (value == null) return null;
    return num.tryParse(value.toString());
  }

  num _roundCheckoutAmount(num value) {
    return (value * 100).round() / 100;
  }

  String _normalizeAddonSelection(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  List<String> _normalizeAddonSelections(List<String>? values) {
    return (values ?? const [])
        .map(_normalizeAddonSelection)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  bool _didServerMissSelectedAddon({
    required Map<String, dynamic> paymentData,
    required List<String> addonProductIds,
    required List<String> addonProductCodes,
    required num? expectedTotalAmount,
  }) {
    final normalizedAddonProductIds = _normalizeAddonSelections(
      addonProductIds,
    );
    final normalizedAddonProductCodes = _normalizeAddonSelections(
      addonProductCodes,
    );
    final hasAddonSelection =
        normalizedAddonProductIds.isNotEmpty ||
        normalizedAddonProductCodes.isNotEmpty;
    if (!hasAddonSelection) return false;

    final breakdownRaw = paymentData['breakdown'];
    final breakdown = breakdownRaw is Map<String, dynamic>
        ? breakdownRaw
        : (breakdownRaw is Map
              ? Map<String, dynamic>.from(breakdownRaw)
              : const <String, dynamic>{});

    final returnedAddonProductCodes = <String>[
      ..._normalizeAddonSelections(
        (breakdown['addonProductCodes'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList(),
      ),
      ..._normalizeAddonSelections(
        (paymentData['addonProductCodes'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList(),
      ),
      _normalizeAddonSelection(
        breakdown['addonProductCode']?.toString() ??
            paymentData['addonProductCode']?.toString(),
      ),
    ].where((value) => value.isNotEmpty).toSet().toList(growable: false);
    final addonFinalPrice = _parseCheckoutAmount(breakdown['addonFinalPrice']);
    final returnedTotalAmount =
        _parseCheckoutAmount(breakdown['totalAmount']) ??
        _parseCheckoutAmount(paymentData['amount']) ??
        0;

    final selectionMatched = normalizedAddonProductCodes.isNotEmpty
        ? normalizedAddonProductCodes.every(
                returnedAddonProductCodes.contains,
              ) &&
              returnedAddonProductCodes.length ==
                  normalizedAddonProductCodes.length
        : returnedAddonProductCodes.length == normalizedAddonProductIds.length;

    if (!selectionMatched && (addonFinalPrice ?? 0) <= 0) {
      return true;
    }

    if (expectedTotalAmount == null) return false;
    return _roundCheckoutAmount(returnedTotalAmount) !=
        _roundCheckoutAmount(expectedTotalAmount);
  }

  Future<bool> _ensureCheckoutSession() async {
    final hasValidSession = await _storageService.hasValidSessionArtifacts();
    if (hasValidSession) return true;
    if (!mounted) return false;

    ErrorHandler.showSnackBar(
      'Session expired. Please sign in again.',
      isError: true,
      context: context,
    );
    context.go('/login');
    return false;
  }

  bool _handleCheckoutUnauthorized<T>(ApiResponse<T> response) {
    if (response.statusCode != 401) return false;
    if (!mounted) return true;

    ErrorHandler.showSnackBar(
      'Session expired. Please sign in again.',
      isError: true,
      context: context,
    );
    context.go('/login');
    return true;
  }

  bool _isDuplicateResourcePurchaseResponse<T>(ApiResponse<T> response) {
    final message = response.message?.toLowerCase() ?? '';
    return message.contains('resource purchase id already exists');
  }

  Future<void> _completeProfessionalUpgradeSuccess(
    ExamModel exam, {
    required String examId,
    required PaymentSuccessDetails paymentDetails,
  }) async {
    await _storageService.clearPendingReferralCode();
    await _userController.applyProfessionalUpgrade(examId: examId);
    await _userController.refreshProfile();
    await _loadProfessionalPlan();
    if (!mounted) return;
    context.push(
      '/exam-unlock-success',
      extra: {
        'courseTitle': exam.name,
        'examId': examId,
        'questionCount': exam.questionCount,
        'effectivitySheetContent': exam.effectivitySheetContent,
        'bodyOfKnowledgeContent': exam.bodyOfKnowledgeContent,
        'paymentSummary': paymentDetails.toJson(),
      },
    );
  }

  Future<bool> _recoverProfessionalUpgradeFromDuplicateConfirm({
    required String examId,
  }) async {
    await _userController.refreshProfile();
    await _loadProfessionalPlan();
    if (!mounted) return false;

    final subscriptionTier =
        _userController.user.value?.subscriptionTier?.trim().toLowerCase() ??
        '';
    final recovered =
        _userController.planTier.value == PlanTier.professional ||
        subscriptionTier == 'professional';
    if (!recovered) return false;

    await _storageService.clearPendingReferralCode();
    await _userController.applyProfessionalUpgrade(examId: examId);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentPlan = _userController.planTier.value;
      final isProfessionalActive = currentPlan == PlanTier.professional;

      return Scaffold(
        body: GradientBackground(
          useImage: true,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.go('/home'),
                        color: const Color(0xFF2D4F88),
                      ),
                      const Expanded(
                        child: Text(
                          'Subscribe',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D4F88),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: _buildBody(isProfessionalActive),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildBody(bool isProfessionalActive) {
    if (planLoading && professionalPlan == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: Column(
            children: [
              AppShimmerCircle(size: 34),
              SizedBox(height: 12),
              Text(
                'Loading subscription details...',
                style: TextStyle(color: Color(0xFF374151)),
              ),
            ],
          ),
        ),
      );
    }

    if (planError != null && professionalPlan == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              planError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _loadProfessionalPlan,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2D4F88),
                  side: const BorderSide(color: Color(0xFF2D4F88)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final List<Widget> children = [];
    final referralOffer =
        !isProfessionalActive && (professionalPlan?.referralEligible ?? false)
        ? professionalPlan?.referralOffer
        : null;

    if (referralOffer != null) {
      children.add(_buildReferralReadyBanner(referralOffer));
      children.add(const SizedBox(height: 20));
    }

    children.add(
      _buildPlanCard(
        planTier: PlanTier.starter,
        isActive: !isProfessionalActive,
      ),
    );
    children.add(const SizedBox(height: 24));
    children.add(
      _buildPlanCard(
        planTier: PlanTier.professional,
        isActive: isProfessionalActive,
        professionalPlan: professionalPlan,
        onUpgrade: !_isPaymentLoading
            ? () => _openUnlockExamDialog(
                isProfessionalActive: isProfessionalActive,
              )
            : null,
      ),
    );

    if (_isPaymentLoading) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Column(
            children: [
              AppShimmerCircle(size: 28),
              SizedBox(height: 12),
              Text('Processing payment...'),
            ],
          ),
        ),
      );
    }

    if (planError != null && professionalPlan != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            planError!,
            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
          ),
        ),
      );
    }

    children.add(const SizedBox(height: 32));
    return Column(children: children);
  }

  Widget _buildReferralReadyBanner(ReferralPublicCode referralOffer) {
    final percentText =
        referralOffer.discountPercent.truncateToDouble() ==
            referralOffer.discountPercent
        ? referralOffer.discountPercent.toStringAsFixed(0)
        : referralOffer.discountPercent.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF6D87A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$percentText% referral discount ready',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF7C4A03),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Code ${referralOffer.referralCode} from ${referralOffer.referrerName} will be applied automatically when you buy your first Professional Plan, including any add-on selected before checkout.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUnlockExamDialog({
    required bool isProfessionalActive,
  }) async {
    final result = await showDialog<UnlockExamDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UnlockExamDialog(
        examService: _examService,
        maxSelect: 1,
        unlockedIds: _userController.unlockedExamIds.value,
      ),
    );

    if (!mounted || result == null) return;

    if (result.alreadyUnlocked) {
      context.push(
        '/quiz-settings',
        extra: {
          'courseTitle': result.exam.name,
          'examId': result.exam.id,
          'questionCount': result.exam.questionCount,
          'effectivitySheetContent': result.exam.effectivitySheetContent,
          'bodyOfKnowledgeContent': result.exam.bodyOfKnowledgeContent,
        },
      );
      return;
    }

    if (isProfessionalActive) {
      final selection = await _showUpgradeAddOnSelectionDialog(
        showReferralDiscount: false,
      );
      if (!mounted || selection == null) return;
      await _payForExamUnlockWithStripe(
        result.exam,
        addonProductIds: selection.addonProductIds,
        addonProductCodes: selection.addonProductCodes,
        expectedTotalAmount: selection.expectedTotalAmount,
      );
    } else {
      final selection = await _showUpgradeAddOnSelectionDialog(
        showReferralDiscount: true,
      );
      if (!mounted || selection == null) return;
      await _payForProfessionalUpgradeWithStripe(
        result.exam,
        addonProductIds: selection.addonProductIds,
        addonProductCodes: selection.addonProductCodes,
        expectedTotalAmount: selection.expectedTotalAmount,
      );
    }
  }

  Future<_UpgradeCheckoutSelection?> _showUpgradeAddOnSelectionDialog({
    required bool showReferralDiscount,
  }) async {
    final options = professionalPlan?.prePurchaseAddOnOptions ?? const [];
    final referralOffer =
        showReferralDiscount && (professionalPlan?.referralEligible ?? false)
        ? professionalPlan?.referralOffer
        : null;
    if (options.isEmpty) {
      return const _UpgradeCheckoutSelection(
        addonProductIds: <String>[],
        addonProductCodes: <String>[],
        expectedTotalAmount: null,
      );
    }

    return showModalBottomSheet<_UpgradeCheckoutSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpgradeAddOnSheet(
        options: options,
        baseLabel: showReferralDiscount ? 'Professional plan' : 'Exam unlock',
        basePrice: showReferralDiscount
            ? professionalPlan?.price ?? 0
            : professionalPlan?.unlockExamPrice ?? 0,
        currency: professionalPlan?.currency ?? 'USD',
        referralOffer: referralOffer,
        continueLabel: showReferralDiscount
            ? 'Continue With Plan Only'
            : 'Continue With Exam Only',
      ),
    );
  }

  Future<void> _payForProfessionalUpgradeWithStripe(
    ExamModel exam, {
    List<String> addonProductIds = const [],
    List<String> addonProductCodes = const [],
    num? expectedTotalAmount,
  }) async {
    if (!await _ensureCheckoutSession()) return;

    final examId = exam.id;
    setState(() => _isPaymentLoading = true);

    try {
      final createRes = await _apiService
          .createProfessionalPlanStripePaymentIntent(
            examId,
            addonProductIds: addonProductIds,
            addonProductCodes: addonProductCodes,
          );
      if (!mounted) return;
      if (!createRes.success || createRes.data == null) {
        setState(() => _isPaymentLoading = false);
        if (_handleCheckoutUnauthorized(createRes)) return;
        ErrorHandler.showFromResponse(
          createRes,
          context: context,
          failureFallback: 'Failed to create payment',
        );
        return;
      }

      final clientSecret = createRes.data!['clientSecret'] as String?;
      final paymentIntentId = createRes.data!['paymentIntentId'] as String?;
      if (clientSecret == null ||
          clientSecret.isEmpty ||
          paymentIntentId == null) {
        setState(() => _isPaymentLoading = false);
        ErrorHandler.showSnackBar(
          'Invalid payment response',
          isError: true,
          context: context,
        );
        return;
      }
      final num amountPaid =
          _parseCheckoutAmount(createRes.data!['amount']) ?? 180;
      if (_didServerMissSelectedAddon(
        paymentData: createRes.data!,
        addonProductIds: addonProductIds,
        addonProductCodes: addonProductCodes,
        expectedTotalAmount: expectedTotalAmount,
      )) {
        setState(() => _isPaymentLoading = false);
        ErrorHandler.showSnackBar(
          'The payment server returned plan-only pricing. Deploy the updated backend, then try again.',
          isError: true,
          context: context,
        );
        return;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'EJ Exam Access',
          returnURL: 'flutterstripe://redirect',
        ),
      );
      if (!mounted) return;

      await Stripe.instance.presentPaymentSheet();
      if (!mounted) return;

      final confirmRes = await _apiService.confirmProfessionalPlanStripePayment(
        paymentIntentId,
      );
      if (!mounted) return;
      setState(() => _isPaymentLoading = false);

      if (confirmRes.success) {
        final PaymentSuccessDetails paymentDetails =
            PaymentSuccessDetails.fromPayload(
              confirmRes.data,
              purchaseType: 'plan',
              fallbackAmount: amountPaid,
              fallbackTitle: professionalPlan?.name ?? 'Professional Plan',
              fallbackCurrency:
                  (createRes.data?['currency']?.toString() ??
                          professionalPlan?.currency ??
                          'USD')
                      .toUpperCase(),
              fallbackBillingCycleLabel:
                  professionalPlan?.subscription?.billingCycle?.label ??
                  professionalPlan?.interval.label,
              fallbackNextBillingDate:
                  _userController.user.value?.subscriptionExpiresAt ??
                  professionalPlan?.subscription?.nextBillingDate,
              fallbackPaymentMethodLabel: 'Card',
              fallbackPaidAt: DateTime.now(),
              fallbackProvider: 'stripe',
              fallbackSubscriptionStartedAt:
                  _userController.user.value?.subscriptionStartedAt,
              fallbackStatus: 'successful',
            );
        await _completeProfessionalUpgradeSuccess(
          exam,
          examId: examId,
          paymentDetails: paymentDetails,
        );
      } else {
        if (_handleCheckoutUnauthorized(confirmRes)) return;
        if (_isDuplicateResourcePurchaseResponse(confirmRes)) {
          final recovered =
              await _recoverProfessionalUpgradeFromDuplicateConfirm(
                examId: examId,
              );
          if (!mounted) return;
          if (recovered) {
            final PaymentSuccessDetails paymentDetails =
                PaymentSuccessDetails.fromPayload(
                  confirmRes.data,
                  purchaseType: 'plan',
                  fallbackAmount: amountPaid,
                  fallbackTitle: professionalPlan?.name ?? 'Professional Plan',
                  fallbackCurrency:
                      (createRes.data?['currency']?.toString() ??
                              professionalPlan?.currency ??
                              'USD')
                          .toUpperCase(),
                  fallbackBillingCycleLabel:
                      professionalPlan?.subscription?.billingCycle?.label ??
                      professionalPlan?.interval.label,
                  fallbackNextBillingDate:
                      _userController.user.value?.subscriptionExpiresAt ??
                      professionalPlan?.subscription?.nextBillingDate,
                  fallbackPaymentMethodLabel: 'Card',
                  fallbackPaidAt: DateTime.now(),
                  fallbackProvider: 'stripe',
                  fallbackSubscriptionStartedAt:
                      _userController.user.value?.subscriptionStartedAt,
                  fallbackStatus: 'successful',
                );
            await _completeProfessionalUpgradeSuccess(
              exam,
              examId: examId,
              paymentDetails: paymentDetails,
            );
            return;
          }

          ErrorHandler.showSnackBar(
            'Payment appears to have succeeded, but the server reported a duplicate purchase record. Please refresh once, and if your plan is still not upgraded contact support with your payment reference.',
            isError: true,
            context: context,
          );
          return;
        }
        ErrorHandler.showFromResponse(
          confirmRes,
          context: context,
          failureFallback: 'Failed to confirm payment',
        );
      }
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() => _isPaymentLoading = false);
      ErrorHandler.showSnackBar(
        e.error.message ?? 'Payment was cancelled or failed.',
        isError: true,
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPaymentLoading = false);
      ErrorHandler.showFromException(
        e,
        context: context,
        fallback: 'Payment failed. Please try again.',
      );
    }
  }

  Future<void> _payForExamUnlockWithStripe(
    ExamModel exam, {
    List<String> addonProductIds = const [],
    List<String> addonProductCodes = const [],
    num? expectedTotalAmount,
  }) async {
    if (!await _ensureCheckoutSession()) return;

    final examId = exam.id;
    setState(() => _isPaymentLoading = true);

    try {
      final createRes = await _apiService.createExamStripePaymentIntent(
        examId,
        addonProductIds: addonProductIds,
        addonProductCodes: addonProductCodes,
      );
      if (!mounted) return;
      if (!createRes.success || createRes.data == null) {
        setState(() => _isPaymentLoading = false);
        if (_handleCheckoutUnauthorized(createRes)) return;
        ErrorHandler.showFromResponse(
          createRes,
          context: context,
          failureFallback: 'Failed to create payment',
        );
        return;
      }

      final bool alreadyUnlocked =
          createRes.data?['unlocked'] == true ||
          createRes.data?['alreadyUnlocked'] == true;
      if (alreadyUnlocked) {
        setState(() => _isPaymentLoading = false);
        await _userController.addUnlockedExamId(examId);
        await _userController.refreshProfile();
        if (!mounted) return;
        context.push(
          '/quiz-settings',
          extra: {
            'courseTitle': exam.name,
            'examId': exam.id,
            'questionCount': exam.questionCount,
            'effectivitySheetContent': exam.effectivitySheetContent,
            'bodyOfKnowledgeContent': exam.bodyOfKnowledgeContent,
          },
        );
        return;
      }

      final clientSecret = createRes.data!['clientSecret'] as String?;
      final paymentIntentId = createRes.data!['paymentIntentId'] as String?;
      if (clientSecret == null ||
          clientSecret.isEmpty ||
          paymentIntentId == null) {
        setState(() => _isPaymentLoading = false);
        ErrorHandler.showSnackBar(
          'Invalid payment response',
          isError: true,
          context: context,
        );
        return;
      }

      final num fallbackAmount = professionalPlan?.unlockExamPrice ?? 150;
      final num amountPaid =
          _parseCheckoutAmount(createRes.data!['amount']) ?? fallbackAmount;
      if (_didServerMissSelectedAddon(
        paymentData: createRes.data!,
        addonProductIds: addonProductIds,
        addonProductCodes: addonProductCodes,
        expectedTotalAmount: expectedTotalAmount,
      )) {
        setState(() => _isPaymentLoading = false);
        ErrorHandler.showSnackBar(
          'The payment server returned exam-only pricing. Deploy the updated backend, then try again.',
          isError: true,
          context: context,
        );
        return;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'EJ Exam Access',
          returnURL: 'flutterstripe://redirect',
        ),
      );
      if (!mounted) return;

      await Stripe.instance.presentPaymentSheet();
      if (!mounted) return;

      final confirmRes = await _apiService.confirmExamStripePayment(
        examId,
        paymentIntentId,
      );
      if (!mounted) return;
      setState(() => _isPaymentLoading = false);

      if (confirmRes.success) {
        await _userController.addUnlockedExamId(examId);
        await _userController.refreshProfile();
        await _loadProfessionalPlan();
        if (!mounted) return;
        final PaymentSuccessDetails paymentDetails =
            PaymentSuccessDetails.fromPayload(
              confirmRes.data,
              purchaseType: 'exam',
              fallbackAmount: amountPaid,
              fallbackTitle: exam.name,
              fallbackCurrency:
                  (createRes.data?['currency']?.toString() ?? 'USD')
                      .toUpperCase(),
              fallbackPaymentMethodLabel: 'Card',
              fallbackPaidAt: DateTime.now(),
              fallbackProvider: 'stripe',
              fallbackStatus: 'successful',
            );
        context.push(
          '/exam-unlock-success',
          extra: {
            'courseTitle': exam.name,
            'examId': examId,
            'questionCount': exam.questionCount,
            'effectivitySheetContent': exam.effectivitySheetContent,
            'bodyOfKnowledgeContent': exam.bodyOfKnowledgeContent,
            'paymentSummary': paymentDetails.toJson(),
          },
        );
      } else {
        if (_handleCheckoutUnauthorized(confirmRes)) return;
        ErrorHandler.showFromResponse(
          confirmRes,
          context: context,
          failureFallback: 'Failed to confirm payment',
        );
      }
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() => _isPaymentLoading = false);
      ErrorHandler.showSnackBar(
        e.error.message ?? 'Payment was cancelled or failed.',
        isError: true,
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPaymentLoading = false);
      ErrorHandler.showFromException(
        e,
        context: context,
        fallback: 'Payment failed. Please try again.',
      );
    }
  }

  Widget _buildPlanCard({
    required PlanTier planTier,
    required bool isActive,
    ProfessionalPlanModel? professionalPlan,
    VoidCallback? onUpgrade,
  }) {
    final bool isStarter = planTier == PlanTier.starter;
    final plan = professionalPlan;

    if (!isStarter && isActive) {
      return _buildActiveProfessionalPlanCard(
        plan: plan,
        onUnlockAnotherExam: onUpgrade,
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: const Color(0xFF2D4F88), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isStarter
                      ? const Color(0xFF2D4F88)
                      : const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  isStarter
                      ? 'assets/icons/starter_plan.png'
                      : 'assets/icons/professional_plan.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      isStarter ? Icons.star : Icons.bolt,
                      color: Colors.white,
                      size: 24,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isStarter
                                ? 'Starter Plan'
                                : (plan?.name ?? 'Professional Plan'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isStarter) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Popular',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isStarter) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Free',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/forever',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan?.priceFormatted ?? '\$180.00',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/${plan?.interval.label ?? '3 months'}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 20),
          Text(
            isStarter
                ? 'What\'s Included in Your Plan'
                : (plan?.description ?? 'What\'s Included in Your Plan'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          ..._buildFeaturesList(isStarter, professionalPlan: plan),
          const SizedBox(height: 24),
          if (isStarter)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: isActive
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        side: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      child: const Text(
                        'Your Current Plan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: onUpgrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.grey[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Free Plan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D4F88),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  plan != null
                      ? 'Subscribe - ${plan.priceFormatted}'
                      : 'Subscribe - \$180.00',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveProfessionalPlanCard({
    required ProfessionalPlanModel? plan,
    VoidCallback? onUnlockAnotherExam,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmallScreen = screenWidth < 380;
    final double primaryButtonHeight = isSmallScreen ? 68 : 56;
    final double secondaryButtonHeight = isSmallScreen ? 52 : 56;
    final double primaryButtonFontSize = isSmallScreen ? 13 : 15;
    final double secondaryButtonFontSize = isSmallScreen ? 14 : 16;
    final subscription = plan?.subscription;
    final profileUser = _userController.user.value;
    final billingCycle =
        subscription?.billingCycle?.label ?? plan?.interval.label ?? '3 months';
    final nextBillingDate = _formatDate(
      profileUser?.subscriptionExpiresAt ?? subscription?.nextBillingDate,
    );
    final planPrice = plan?.priceFormatted ?? '\$180.00';
    final intervalLabel = '/${plan?.interval.label ?? billingCycle}';
    final unlockLabel = plan?.unlockExamPriceFormatted ?? '\$250.00';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCED7F2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D4F88),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Image.asset(
                    'assets/icons/professional_plan.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.bolt, color: Colors.white, size: 32),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  plan?.name ?? 'Professional Plan',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                    height: 1.12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFD9F7DC),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF13AF2C), width: 2),
            ),
            child: const Text(
              'Active',
              style: TextStyle(
                color: Color(0xFF0F9E25),
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 26),
          _buildInfoRow(title: 'Billing Cycle', value: billingCycle),
          const SizedBox(height: 16),
          _buildInfoRow(title: 'Next Billing Date', value: nextBillingDate),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                planPrice,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  intervalLabel,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(thickness: 1, color: Color(0xFF1F2937)),
          const SizedBox(height: 22),
          Text(
            plan?.description ?? 'What\'s Included in Your Plan',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          ..._buildFeaturesList(false, professionalPlan: plan),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: primaryButtonHeight,
            child: ElevatedButton(
              onPressed: onUnlockAnotherExam,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF184A99),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 18,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                'Unlock another exam for $unlockLabel',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: primaryButtonFontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: secondaryButtonHeight,
            child: OutlinedButton(
              onPressed: _onCancelSubscriptionTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF184A99),
                side: const BorderSide(color: Color(0xFF184A99), width: 2),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 18,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                'Cancel Subscription',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: secondaryButtonFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required String title, required String value}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  void _onCancelSubscriptionTap() {
    ErrorHandler.showSnackBar(
      'Cancellation flow is not available yet.',
      isError: false,
      context: context,
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    final local = date.toLocal();
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final month = months[local.month - 1];
    return '$month ${local.day}, ${local.year}';
  }

  List<Widget> _buildFeaturesList(
    bool isStarter, {
    ProfessionalPlanModel? professionalPlan,
  }) {
    if (isStarter) {
      return [
        _buildFeatureItem('16 free practice questions per month'),
        _buildFeatureItem('Explore all certifications'),
        _buildFeatureItem('Up to 2 practice questions per certification'),
        _buildFeatureItem('Upgrade anytime for full access'),
      ];
    }
    if (professionalPlan != null && professionalPlan.features.isNotEmpty) {
      return professionalPlan.features
          .map((f) => _buildFeatureItem(f))
          .toList();
    }
    return [
      _buildFeatureItem('Access to selected API exams'),
      _buildFeatureItem('Full-length mock exams'),
      _buildFeatureItem('Timed & Full Simulation Modes'),
      _buildFeatureItem('Interactive study mode'),
      _buildFeatureItem(
        'Progress tracking, Performance Dashboard & exam history',
      ),
      _buildFeatureItem('Detailed explanations with code references'),
      _buildFeatureItem('All Smart Study Tools'),
    ];
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, color: Color(0xFF111827), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF111827),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeCheckoutSelection {
  final List<String> addonProductIds;
  final List<String> addonProductCodes;
  final num? expectedTotalAmount;

  const _UpgradeCheckoutSelection({
    required this.addonProductIds,
    required this.addonProductCodes,
    required this.expectedTotalAmount,
  });
}

class _UpgradeAddOnSheet extends StatefulWidget {
  final List<PlanAddOnOption> options;
  final String baseLabel;
  final num basePrice;
  final String currency;
  final ReferralPublicCode? referralOffer;
  final String continueLabel;

  const _UpgradeAddOnSheet({
    required this.options,
    required this.baseLabel,
    required this.basePrice,
    required this.currency,
    required this.referralOffer,
    required this.continueLabel,
  });

  @override
  State<_UpgradeAddOnSheet> createState() => _UpgradeAddOnSheetState();
}

class _UpgradeAddOnSheetState extends State<_UpgradeAddOnSheet> {
  String? _selectedValue;

  List<PlanAddOnOption> get _selectedOptions => widget.options
      .where((option) => option.selectionValue == _selectedValue)
      .toList(growable: false);

  String _formatMoney(num amount) {
    if (widget.currency.toUpperCase() == 'USD') {
      return '\$${amount.toStringAsFixed(2)}';
    }
    return '${widget.currency.toUpperCase()} ${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedOptions = _selectedOptions;
    final num addonPrice = selectedOptions.fold<num>(
      0,
      (sum, option) => sum + option.effectiveUpgradePrice,
    );
    final subtotalBeforeReferral = widget.basePrice + addonPrice;
    final referralDiscount = widget.referralOffer == null
        ? 0
        : subtotalBeforeReferral *
              (widget.referralOffer!.discountPercent / 100);
    final num totalPrice = subtotalBeforeReferral - referralDiscount;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Add a Resource Before Checkout',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                color: const Color(0xFF374151),
              ),
            ],
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Choose only 1 add-on resource, or continue without any.',
              style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDE4F8)),
            ),
            child: Column(
              children: [
                _priceRow(widget.baseLabel, _formatMoney(widget.basePrice)),
                const SizedBox(height: 6),
                _priceRow(
                  'Selected resource',
                  selectedOptions.isEmpty
                      ? 'Not added'
                      : '${selectedOptions.first.title} • ${_formatMoney(addonPrice)}',
                ),
                if (referralDiscount > 0) ...[
                  const SizedBox(height: 6),
                  _priceRow(
                    'Referral discount',
                    '-${_formatMoney(referralDiscount)}',
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
                _priceRow(
                  'Total today',
                  _formatMoney(totalPrice),
                  isTotal: true,
                ),
              ],
            ),
          ),
          if (widget.referralOffer != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF6D87A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Referral ready for your upgrade',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7C4A03),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Code ${widget.referralOffer!.referralCode} from ${widget.referralOffer!.referrerName} will be applied automatically to today\'s Professional Plan checkout, including any selected add-on.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.42,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final optionValue = option.selectionValue;
                final isSelected = _selectedValue == optionValue;

                return InkWell(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedValue = null;
                    } else {
                      _selectedValue = optionValue;
                    }
                  }),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2D4F88)
                            : const Color(0xFFDDE4F8),
                        width: isSelected ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 58,
                            height: 78,
                            child: option.coverImageUrl.trim().isNotEmpty
                                ? Image.network(
                                    option.coverImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _imageFallback(),
                                  )
                                : _imageFallback(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              if (option.isBundle) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Bundle',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFB91C1C),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  Text(
                                    option.effectiveUpgradePriceFormatted,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  if (option.basePrice >
                                      option.effectiveUpgradePrice)
                                    Text(
                                      option.basePriceFormatted,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF),
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected
                              ? const Color(0xFF2D4F88)
                              : const Color(0xFF6B7280),
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(
                const _UpgradeCheckoutSelection(
                  addonProductIds: <String>[],
                  addonProductCodes: <String>[],
                  expectedTotalAmount: null,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2D4F88),
                side: const BorderSide(color: Color(0xFF2D4F88)),
              ),
              child: Text(
                widget.continueLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: selectedOptions.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      _UpgradeCheckoutSelection(
                        addonProductIds: selectedOptions
                            .map((option) => option.id.trim())
                            .where((id) => id.isNotEmpty)
                            .toSet()
                            .toList(growable: false),
                        addonProductCodes: selectedOptions
                            .map((option) => option.code.trim())
                            .where((code) => code.isNotEmpty)
                            .toSet()
                            .toList(growable: false),
                        expectedTotalAmount: totalPrice,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D4F88),
                foregroundColor: Colors.white,
              ),
              child: Text(
                selectedOptions.isEmpty
                    ? 'Proceed With 1 Add-On • ${_formatMoney(totalPrice)}'
                    : 'Proceed With Add-On • ${_formatMoney(totalPrice)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: const Icon(Icons.menu_book_rounded, color: Color(0xFF6B7280)),
    );
  }

  Widget _priceRow(String label, String value, {bool isTotal = false}) {
    final textStyle = TextStyle(
      fontSize: isTotal ? 15 : 13.5,
      fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
      color: const Color(0xFF111827),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: textStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Text(
            value,
            style: textStyle,
            textAlign: TextAlign.right,
            maxLines: isTotal ? 1 : 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
