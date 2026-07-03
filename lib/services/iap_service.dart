import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../controllers/user_controller.dart';
import '../models/payment_success_details.dart';
import 'api_service.dart';
import 'exam_service.dart';

const Map<String, String> examIapProductIds = {
  'API_1184': 'com.inspectorspath.exam.api1184.unlock',
  'API_510': 'com.inspectorspath.exam.api510.unlock',
  'API_570': 'com.inspectorspath.exam.api570.unlock',
  'API_653': 'com.inspectorspath.exam.api653.unlock',
  'API_936': 'com.inspectorspath.exam.api936.unlock',
  'API_1169': 'com.inspectorspath.exam.api1169.unlock',
  'API_SIEE': 'com.inspectorspath.exam.siee.unlock',
  'API_SIFE': 'com.inspectorspath.exam.sife.unlock',
  'API_SIRE': 'com.inspectorspath.exam.sire.unlock',
};

const String professionalSubscriptionProductId = 'six_month_subscriptions';

enum IapPurchaseKind { exam, professional }

class IapCompletedPurchase {
  final IapPurchaseKind kind;
  final String productId;
  final String? examId;
  final Map<String, dynamic>? payload;
  final PaymentSuccessDetails? paymentDetails;

  const IapCompletedPurchase({
    required this.kind,
    required this.productId,
    this.examId,
    this.payload,
    this.paymentDetails,
  });
}

class _PendingIapIntent {
  final IapPurchaseKind kind;
  final String productId;
  final String? examId;
  final String? examCode;

  const _PendingIapIntent({
    required this.kind,
    required this.productId,
    this.examId,
    this.examCode,
  });
}

class IapService extends GetxService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final ApiService _apiService = ApiService();
  final ExamService _examService = ExamService();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final Map<String, _PendingIapIntent> _pendingIntents = {};

  final RxBool isStoreAvailable = false.obs;
  final RxBool isLoadingProducts = false.obs;
  final RxBool isRestoring = false.obs;
  final RxString errorMessage = ''.obs;
  final RxMap<String, ProductDetails> products = <String, ProductDetails>{}.obs;
  final RxSet<String> missingProductIds = <String>{}.obs;
  final RxSet<String> inFlightProductIds = <String>{}.obs;
  final Rx<IapCompletedPurchase?> lastCompletedPurchase =
      Rx<IapCompletedPurchase?>(null);

  bool get shouldUseAppleIap => Platform.isIOS;
  bool get hasLoadedProducts => products.isNotEmpty;

  Set<String> get allProductIds => <String>{
    ...examIapProductIds.values,
    professionalSubscriptionProductId,
  };

  Future<IapService> init() async {
    if (!shouldUseAppleIap) {
      debugPrint('IAP: Apple IAP disabled on this platform.');
      return this;
    }

    _purchaseSubscription ??= _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('IAP: purchase stream error: $error');
        errorMessage.value =
            'Purchases are currently unavailable. Please try again later.';
      },
      onDone: () {
        debugPrint('IAP: purchase stream closed.');
        _purchaseSubscription?.cancel();
        _purchaseSubscription = null;
      },
    );

    await loadProducts();
    return this;
  }

  @override
  void onClose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    super.onClose();
  }

  Future<void> loadProducts() async {
    if (!shouldUseAppleIap || isLoadingProducts.value) return;

    isLoadingProducts.value = true;
    errorMessage.value = '';

    final ids = allProductIds;
    debugPrint('IAP: querying product IDs: ${ids.join(', ')}');

    try {
      final available = await _iap.isAvailable();
      isStoreAvailable.value = available;
      if (!available) {
        debugPrint('IAP: store not available.');
        errorMessage.value =
            'Purchases are currently unavailable. Please try again later.';
        return;
      }

      final response = await _iap.queryProductDetails(ids);
      debugPrint(
        'IAP: products returned: '
        '${response.productDetails.map((p) => '${p.id}=${p.price}').join(', ')}',
      );
      if (response.error != null) {
        debugPrint('IAP: product query error: ${response.error}');
        errorMessage.value =
            'Purchases are currently unavailable. Please try again later.';
      }

      products.assignAll({
        for (final product in response.productDetails) product.id: product,
      });
      missingProductIds.assignAll(response.notFoundIDs.toSet());
      if (missingProductIds.isNotEmpty) {
        debugPrint('IAP: missing product IDs: ${missingProductIds.join(', ')}');
      }
    } catch (e, stackTrace) {
      debugPrint('IAP: failed to load products: $e');
      debugPrint('$stackTrace');
      errorMessage.value =
          'Purchases are currently unavailable. Please try again later.';
    } finally {
      isLoadingProducts.value = false;
    }
  }

  ProductDetails? productForExam({
    required String? examCode,
    required String? examName,
  }) {
    final code = resolveExamCode(code: examCode, name: examName);
    if (code == null) return null;
    final productId = examIapProductIds[code];
    if (productId == null) return null;
    return products[productId];
  }

  String? priceForExam({required String? examCode, required String? examName}) {
    return productForExam(examCode: examCode, examName: examName)?.price;
  }

  ProductDetails? get professionalProduct =>
      products[professionalSubscriptionProductId];

  String? get professionalPrice => professionalProduct?.price;

  String? resolveExamCode({String? code, String? name}) {
    final rawCode = (code ?? '').trim();
    final candidates = <String>[
      rawCode,
      rawCode.replaceAll('-', '_'),
      rawCode.replaceAll(' ', '_'),
      (name ?? '').trim(),
    ];

    for (final candidate in candidates) {
      final normalized = candidate
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      if (examIapProductIds.containsKey(normalized)) return normalized;

      final apiMatch = RegExp(
        r'API_?(1184|510|570|653|936|1169|SIEE|SIFE|SIRE)',
      ).firstMatch(normalized);
      if (apiMatch != null) {
        return 'API_${apiMatch.group(1)}';
      }
    }
    return null;
  }

  Future<bool> buyExamUnlock({
    required String examId,
    required String? examCode,
    required String examName,
  }) async {
    if (!shouldUseAppleIap) return false;
    final resolvedCode = resolveExamCode(code: examCode, name: examName);
    final productId = resolvedCode == null
        ? null
        : examIapProductIds[resolvedCode];
    if (productId == null) {
      errorMessage.value = 'Purchase is not available for this exam.';
      return false;
    }
    return _buyProduct(
      productId: productId,
      intent: _PendingIapIntent(
        kind: IapPurchaseKind.exam,
        productId: productId,
        examId: examId,
        examCode: resolvedCode,
      ),
    );
  }

  Future<bool> buyProfessionalSubscription({String? selectedExamId}) async {
    if (!shouldUseAppleIap) return false;
    return _buyProduct(
      productId: professionalSubscriptionProductId,
      intent: _PendingIapIntent(
        kind: IapPurchaseKind.professional,
        productId: professionalSubscriptionProductId,
        examId: selectedExamId,
      ),
    );
  }

  Future<bool> _buyProduct({
    required String productId,
    required _PendingIapIntent intent,
  }) async {
    if (inFlightProductIds.contains(productId)) {
      errorMessage.value = 'A purchase is already in progress.';
      return false;
    }

    if (!isStoreAvailable.value || products[productId] == null) {
      await loadProducts();
    }

    final product = products[productId];
    if (!isStoreAvailable.value || product == null) {
      debugPrint('IAP: product not found or store unavailable: $productId');
      errorMessage.value =
          'Purchases are currently unavailable. Please try again later.';
      return false;
    }

    debugPrint('IAP: purchase started: $productId');
    _pendingIntents[productId] = intent;
    inFlightProductIds.add(productId);
    errorMessage.value = '';

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e, stackTrace) {
      debugPrint('IAP: purchase start failed for $productId: $e');
      debugPrint('$stackTrace');
      inFlightProductIds.remove(productId);
      _pendingIntents.remove(productId);
      errorMessage.value = 'Purchase failed. Please try again.';
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!shouldUseAppleIap) return;
    if (isRestoring.value) return;
    isRestoring.value = true;
    errorMessage.value = '';
    debugPrint('IAP: restore started.');
    try {
      if (!isStoreAvailable.value) {
        await loadProducts();
      }
      await _iap.restorePurchases();
    } catch (e, stackTrace) {
      debugPrint('IAP: restore failed: $e');
      debugPrint('$stackTrace');
      errorMessage.value = 'Restore failed. Please try again.';
    } finally {
      isRestoring.value = false;
      debugPrint('IAP: restore request finished.');
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      debugPrint(
        'IAP: purchase update product=${purchase.productID} '
        'status=${purchase.status} id=${purchase.purchaseID}',
      );

      switch (purchase.status) {
        case PurchaseStatus.pending:
          inFlightProductIds.add(purchase.productID);
          errorMessage.value = 'Purchase is pending.';
          break;
        case PurchaseStatus.error:
          debugPrint('IAP: purchase error: ${purchase.error}');
          inFlightProductIds.remove(purchase.productID);
          _pendingIntents.remove(purchase.productID);
          errorMessage.value =
              purchase.error?.message ?? 'Purchase failed. Please try again.';
          await _completeIfNeeded(purchase);
          break;
        case PurchaseStatus.canceled:
          inFlightProductIds.remove(purchase.productID);
          _pendingIntents.remove(purchase.productID);
          errorMessage.value = 'Purchase cancelled.';
          await _completeIfNeeded(purchase);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndDeliver(purchase);
          break;
      }
    }
  }

  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    final intent =
        _pendingIntents[purchase.productID] ??
        _intentFromRestoredProduct(purchase.productID);
    if (intent == null) {
      debugPrint('IAP: no intent for product ${purchase.productID}');
      await _completeIfNeeded(purchase);
      inFlightProductIds.remove(purchase.productID);
      return;
    }

    var effectiveIntent = intent;
    if (effectiveIntent.kind == IapPurchaseKind.exam &&
        (effectiveIntent.examId == null || effectiveIntent.examId!.isEmpty)) {
      final restoredExamId = await _resolveExamIdForCode(
        effectiveIntent.examCode,
      );
      if (restoredExamId == null) {
        errorMessage.value =
            'Unable to restore this exam purchase. Please refresh and try again.';
        await _completeIfNeeded(purchase);
        inFlightProductIds.remove(purchase.productID);
        return;
      }
      effectiveIntent = _PendingIapIntent(
        kind: effectiveIntent.kind,
        productId: effectiveIntent.productId,
        examId: restoredExamId,
        examCode: effectiveIntent.examCode,
      );
    }

    final payload = _purchasePayload(purchase, effectiveIntent);
    try {
      final response = effectiveIntent.kind == IapPurchaseKind.exam
          ? await _apiService.verifyAppleExamPurchase(
              examId: effectiveIntent.examId ?? '',
              purchasePayload: payload,
            )
          : await _apiService.verifyAppleProfessionalPurchase(
              purchasePayload: payload,
            );

      debugPrint(
        'IAP: backend verification result for ${purchase.productID}: '
        '${response.success} ${response.message}',
      );

      if (!response.success) {
        errorMessage.value =
            response.message ?? 'Purchase verification failed.';
        return;
      }

      final paymentDetails = PaymentSuccessDetails.fromPayload(
        response.data,
        purchaseType: effectiveIntent.kind == IapPurchaseKind.exam
            ? 'exam'
            : 'plan',
        fallbackAmount: 0,
        fallbackTitle: effectiveIntent.kind == IapPurchaseKind.exam
            ? 'Exam Unlock'
            : 'Professional Plan',
        fallbackProvider: 'apple',
        fallbackPaymentMethodLabel: 'Apple In-App Purchase',
        fallbackReceiptNumber: purchase.purchaseID,
        fallbackTransactionReference: purchase.purchaseID,
        fallbackPaidAt: DateTime.now(),
        fallbackStatus: 'successful',
      );

      if (Get.isRegistered<UserController>()) {
        final userController = Get.find<UserController>();
        if (effectiveIntent.kind == IapPurchaseKind.exam &&
            effectiveIntent.examId != null) {
          await userController.addUnlockedExamId(effectiveIntent.examId!);
        }
        await userController.refreshProfile();
      }

      debugPrint('IAP: unlock result success for ${purchase.productID}');
      lastCompletedPurchase.value = IapCompletedPurchase(
        kind: effectiveIntent.kind,
        productId: purchase.productID,
        examId: effectiveIntent.examId,
        payload: response.data,
        paymentDetails: paymentDetails,
      );
      errorMessage.value = purchase.status == PurchaseStatus.restored
          ? 'Purchases restored successfully.'
          : '';
      await _completeIfNeeded(purchase);
    } catch (e, stackTrace) {
      debugPrint('IAP: verification failed for ${purchase.productID}: $e');
      debugPrint('$stackTrace');
      errorMessage.value =
          'Purchase verification failed. Please try again later.';
    } finally {
      inFlightProductIds.remove(purchase.productID);
      _pendingIntents.remove(purchase.productID);
    }
  }

  Future<String?> _resolveExamIdForCode(String? examCode) async {
    if (examCode == null || examCode.isEmpty) return null;
    final response = await _examService.getActiveExams();
    if (!response.success) {
      debugPrint('IAP: unable to load exams for restore: ${response.message}');
      return null;
    }
    for (final exam in response.data ?? const []) {
      final resolved = resolveExamCode(code: exam.code, name: exam.name);
      if (resolved == examCode) return exam.id;
    }
    debugPrint('IAP: no exam found for restored product code $examCode');
    return null;
  }

  _PendingIapIntent? _intentFromRestoredProduct(String productId) {
    if (productId == professionalSubscriptionProductId) {
      return const _PendingIapIntent(
        kind: IapPurchaseKind.professional,
        productId: professionalSubscriptionProductId,
      );
    }

    String? examCode;
    for (final entry in examIapProductIds.entries) {
      if (entry.value == productId) {
        examCode = entry.key;
        break;
      }
    }
    if (examCode == null) return null;

    return _PendingIapIntent(
      kind: IapPurchaseKind.exam,
      productId: productId,
      examCode: examCode,
    );
  }

  Map<String, dynamic> _purchasePayload(
    PurchaseDetails purchase,
    _PendingIapIntent intent,
  ) {
    return <String, dynamic>{
      'productId': purchase.productID,
      'purchaseID': purchase.purchaseID,
      'transactionId': purchase.purchaseID,
      'purchaseStatus': purchase.status.name,
      'examId': intent.examId,
      'examCode': intent.examCode,
      'verificationData': {
        'serverVerificationData':
            purchase.verificationData.serverVerificationData,
        'localVerificationData':
            purchase.verificationData.localVerificationData,
        'source': purchase.verificationData.source,
      },
    };
  }

  Future<void> _completeIfNeeded(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(purchase);
      debugPrint('IAP: completed transaction for ${purchase.productID}');
    } catch (e) {
      debugPrint('IAP: completePurchase failed for ${purchase.productID}: $e');
    }
  }
}
