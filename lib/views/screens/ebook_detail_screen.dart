import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error/error_handler.dart';
import '../../models/ebook_store_model.dart';
import '../../models/referral_model.dart';
import '../../services/ebook_service.dart';
import '../../services/referral_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_constants.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/gradient_background.dart';
import 'ebook_pdf_viewer_screen.dart';

class EbookDetailScreen extends StatefulWidget {
  final String productId;
  final String initialReferralCode;

  const EbookDetailScreen({
    super.key,
    required this.productId,
    this.initialReferralCode = '',
  });

  @override
  State<EbookDetailScreen> createState() => _EbookDetailScreenState();
}

class _EbookDetailScreenState extends State<EbookDetailScreen> {
  final EbookService _ebookService = EbookService();
  final ReferralService _referralService = ReferralService();
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  String? _error;
  EbookProduct? _product;
  String _productId = '';
  String _sharedReferralCode = '';
  bool _isBuying = false;

  @override
  void initState() {
    super.initState();
    _primeSharedContext().then((_) => _loadData());
  }

  Future<void> _primeSharedContext() async {
    final pendingReferralCode = await _storageService.getString(
      AppConstants.pendingReferralCodeKey,
    );
    final pendingProductId = await _storageService.getString(
      AppConstants.pendingReferralProductIdKey,
    );

    _productId = widget.productId.trim().isNotEmpty
        ? widget.productId.trim()
        : pendingProductId?.trim() ?? '';
    _sharedReferralCode = widget.initialReferralCode.trim().isNotEmpty
        ? widget.initialReferralCode.trim()
        : pendingReferralCode?.trim() ?? '';

    await _storageService.remove(AppConstants.pendingReferralCodeKey);
    await _storageService.remove(AppConstants.pendingReferralProductIdKey);
  }

  Future<void> _loadData() async {
    if (_productId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Shared ebook is missing a product id.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final storeRes = await _ebookService.getEbookStore();
    final upgradeOptionsRes = await _ebookService.getUpgradeAddOnOptions();
    final referralRes = await _referralService.getMyReferralProfile();

    if (!mounted) return;

    EbookStoreData? store;
    if (storeRes.success &&
        storeRes.data != null &&
        _storeHasProducts(storeRes.data!)) {
      store = storeRes.data;
    } else if (upgradeOptionsRes.success &&
        upgradeOptionsRes.data != null &&
        upgradeOptionsRes.data!.isNotEmpty) {
      store = EbookStoreData.fromUpgradeAddOnOptions(
        upgradeOptionsRes.data!,
        storeRes.data?.userAccess ??
            const EbookUserAccess(
              hasApi510InspectionGuide: false,
              hasApi510ReportGuide: false,
              hasApi510Bundle: false,
              resourceUnlocks: [],
            ),
      );
    }

    final product = _findProductById(store, _productId);

    setState(() {
      _isLoading = false;
      _product = product;
      if (referralRes.success && referralRes.data != null) {
        _removeSelfReferral(referralRes.data!);
      }

      if (product == null) {
        _error = 'Unable to find this ebook.';
      }
    });
  }

  bool _storeHasProducts(EbookStoreData store) {
    for (final category in store.categories) {
      if (category.products.isNotEmpty) return true;
    }
    return false;
  }

  EbookProduct? _findProductById(EbookStoreData? store, String productId) {
    if (store == null || productId.isEmpty) return null;
    for (final category in store.categories) {
      for (final product in category.products) {
        if (product.id == productId) {
          return product;
        }
      }
    }
    return null;
  }

  void _removeSelfReferral(ReferralProfile profile) {
    if (profile.referralCode.trim().toUpperCase() ==
        _sharedReferralCode.trim().toUpperCase()) {
      _sharedReferralCode = '';
    }
  }

  String get _scopedReferralCode => _sharedReferralCode.trim();

  Future<void> _openPreview(EbookProduct product) async {
    final url = product.previewUrl.trim();
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        ErrorHandler.showSnackBar(
          'Invalid preview URL.',
          isError: true,
          context: context,
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (product.previewContent.trim().isEmpty) {
      ErrorHandler.showSnackBar(
        'Preview is not available.',
        isError: true,
        context: context,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFF),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.previewTitle.trim().isNotEmpty
                      ? product.previewTitle
                      : 'Preview',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10213F),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  product.previewContent,
                  style: const TextStyle(height: 1.5, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openReader(EbookProduct product) async {
    var contentUrl = product.contentUrl;

    if (contentUrl.trim().isEmpty) {
      final contentRes = await _ebookService.getPurchasedContent(
        productId: product.id,
      );
      if (!mounted) return;
      if (!contentRes.success || contentRes.data == null) {
        ErrorHandler.showFromResponse(
          contentRes,
          context: context,
          failureFallback: 'You need to purchase this eBook first.',
        );
        return;
      }
      contentUrl = contentRes.data!.contentUrl;
    }

    if (contentUrl.trim().isEmpty) {
      ErrorHandler.showSnackBar(
        'PDF URL is not available for this eBook.',
        isError: true,
        context: context,
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EbookPdfViewerScreen(title: product.title, pdfUrl: contentUrl),
      ),
    );
  }

  Future<_DetailCheckoutDecision?> _showCheckoutSheet(
    EbookProduct product,
  ) async {
    final scopedCode = _scopedReferralCode;
    final referralDiscount = scopedCode.isNotEmpty
        ? product.pricing.current * 0.10
        : 0.0;
    final payNow = product.pricing.current - referralDiscount;

    return showModalBottomSheet<_DetailCheckoutDecision>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF8FAFF),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete Purchase',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.title,
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF183153), Color(0xFF2D4F88)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _summaryRow(
                      'Store price',
                      _currencyText(
                        product.pricing.current,
                        product.pricing.currency,
                      ),
                      valueColor: Colors.white,
                    ),
                    if (referralDiscount > 0) ...[
                      const SizedBox(height: 8),
                      _summaryRow(
                        'Referral discount',
                        '-${_currencyText(referralDiscount, product.pricing.currency)}',
                        valueColor: const Color(0xFFB8F1D9),
                      ),
                    ],
                    const Divider(color: Color(0x33FFFFFF), height: 22),
                    _summaryRow(
                      'Pay now',
                      _currencyText(payNow, product.pricing.currency),
                      valueColor: Colors.white,
                      isEmphasis: true,
                    ),
                  ],
                ),
              ),
              if (scopedCode.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF6D87A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Referral ready for this ebook',
                        style: TextStyle(
                          color: Color(0xFF7C4A03),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Code $_sharedReferralCode is locked to this ebook and can be used only once by this user.',
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      _DetailCheckoutDecision(
                        referralCode: scopedCode,
                        referralProductId: scopedCode.isNotEmpty
                            ? product.id
                            : '',
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10213F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    scopedCode.isNotEmpty
                        ? 'Buy This Ebook with 10% Off'
                        : 'Continue to Payment',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buyWithStripe(
    EbookProduct product, {
    String referralCode = '',
    String referralProductId = '',
  }) async {
    if (_isBuying) return;
    setState(() => _isBuying = true);

    try {
      final createRes = await _ebookService.createStripePaymentIntent(
        productId: product.id,
        referralCode: referralCode,
        referralProductId: referralProductId,
      );

      if (!mounted) return;

      if (!createRes.success || createRes.data == null) {
        setState(() => _isBuying = false);
        ErrorHandler.showFromResponse(
          createRes,
          context: context,
          failureFallback: 'Unable to start payment.',
        );
        return;
      }

      final data = createRes.data!;
      if (data['unlocked'] == true) {
        setState(() => _isBuying = false);
        await _loadData();
        await _openReader(product);
        return;
      }

      final clientSecret = data['clientSecret']?.toString() ?? '';
      final paymentIntentId = data['paymentIntentId']?.toString() ?? '';
      if (clientSecret.isEmpty || paymentIntentId.isEmpty) {
        setState(() => _isBuying = false);
        ErrorHandler.showSnackBar(
          'Invalid payment response from server.',
          isError: true,
          context: context,
        );
        return;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'EJ eBook Store',
          returnURL: 'flutterstripe://redirect',
        ),
      );

      if (!mounted) return;
      await Stripe.instance.presentPaymentSheet();
      if (!mounted) return;

      final confirmRes = await _ebookService.confirmStripePayment(
        paymentIntentId: paymentIntentId,
      );

      if (!mounted) return;
      setState(() {
        _isBuying = false;
        if (referralCode.trim().isNotEmpty) {
          _sharedReferralCode = '';
        }
      });

      if (!confirmRes.success) {
        ErrorHandler.showFromResponse(
          confirmRes,
          context: context,
          failureFallback: 'Payment confirmation failed.',
        );
        return;
      }

      ErrorHandler.showSnackBar(
        'Purchase completed. eBook unlocked.',
        isError: false,
        context: context,
      );
      await _loadData();
      await _openReader(product);
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() => _isBuying = false);
      ErrorHandler.showSnackBar(
        e.error.message ?? 'Payment cancelled or failed.',
        isError: true,
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBuying = false);
      ErrorHandler.showFromException(
        e,
        context: context,
        fallback: 'Payment failed. Please try again.',
      );
    }
  }

  Future<void> _startCheckout(EbookProduct product) async {
    final decision = await _showCheckoutSheet(product);
    if (!mounted || decision == null) return;
    await _buyWithStripe(
      product,
      referralCode: decision.referralCode,
      referralProductId: decision.referralProductId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    return Scaffold(
      body: GradientBackground(
        useImage: true,
        child: SafeArea(
          child: _isLoading
              ? const Center(child: AppShimmerCircle(size: 42))
              : _error != null
              ? _buildError()
              : product == null
              ? const SizedBox.shrink()
              : _buildBody(product),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? 'Unable to load ebook.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D4F88),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(EbookProduct product) {
    final isUnlocked = product.unlocked || product.contentUrl.trim().isNotEmpty;
    final scopedReferralCode = _scopedReferralCode;
    final referralDiscount = scopedReferralCode.isNotEmpty
        ? product.pricing.current * 0.10
        : 0.0;
    final discountedPrice = product.pricing.current - referralDiscount;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: const Color(0xFF10213F),
              ),
              const Expanded(
                child: Text(
                  'Ebook Details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF10213F),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                color: const Color(0xFF10213F),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF10213F),
                  Color(0xFF1C3867),
                  Color(0xFF355B97),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(34),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332D4F88),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _detailPill(
                            product.isBundle ? 'Bundle' : 'Single Ebook',
                            const Color(0x26F59E0B),
                            const Color(0xFFFFD9A6),
                          ),
                          _detailPill(
                            isUnlocked ? 'Unlocked' : 'Locked',
                            isUnlocked
                                ? const Color(0x2610B981)
                                : const Color(0x26FFFFFF),
                            isUnlocked
                                ? const Color(0xFFCFFCEB)
                                : const Color(0xFFE2E8F0),
                          ),
                          if (scopedReferralCode.isNotEmpty)
                            _detailPill(
                              'Referral Ready',
                              const Color(0x26FACC15),
                              const Color(0xFFFDF08A),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1FFFFFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        product.pricing.currency,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 132,
                      height: 176,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000F2E),
                            blurRadius: 20,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: product.coverImageUrl.trim().isEmpty
                            ? Container(
                                color: const Color(0xFFE2E8F0),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  size: 52,
                                  color: Color(0xFF64748B),
                                ),
                              )
                            : Image.network(
                                product.coverImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: const Color(0xFFE2E8F0),
                                  child: const Icon(
                                    Icons.menu_book_rounded,
                                    size: 52,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.08,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            product.shortDescription.trim().isNotEmpty
                                ? product.shortDescription
                                : 'Professional ebook from the EJ store.',
                            style: const TextStyle(
                              color: Color(0xFFD9E5FF),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0x14FFFFFF),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0x1FFFFFFF),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Today\'s price',
                                  style: TextStyle(
                                    color: Color(0xFFD9E5FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      _currencyText(
                                        scopedReferralCode.isNotEmpty
                                            ? discountedPrice
                                            : product.pricing.current,
                                        product.pricing.currency,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (product.pricing.original >
                                            product.pricing.current ||
                                        scopedReferralCode.isNotEmpty)
                                      Text(
                                        _currencyText(
                                          product.pricing.original >
                                                  product.pricing.current
                                              ? product.pricing.original
                                              : product.pricing.current,
                                          product.pricing.currency,
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFFB8C7E6),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                  ],
                                ),
                                if (scopedReferralCode.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '10% discount is locked to this ebook only.',
                                    style: const TextStyle(
                                      color: Color(0xFFFDE68A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionCard(
            title: 'About This Ebook',
            child: Text(
              product.fullDescription.trim().isNotEmpty
                  ? product.fullDescription
                  : product.shortDescription.trim().isNotEmpty
                  ? product.shortDescription
                  : 'This ebook gives you practical study material, structured explanations, and a focused buying flow for certification preparation.',
              style: const TextStyle(color: Color(0xFF475569), height: 1.65),
            ),
          ),
          if (product.bundleIncludes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionCard(
              title: 'What You Get',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: product.bundleIncludes
                    .map(
                      (item) => _detailPill(
                        item.replaceAll('_', ' ').toUpperCase(),
                        const Color(0xFFF1F5F9),
                        const Color(0xFF334155),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Purchase Actions',
            child: Column(
              children: [
                if (scopedReferralCode.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF6D87A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Referral Applied To This Ebook',
                          style: TextStyle(
                            color: Color(0xFF7C4A03),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Code $scopedReferralCode can be used here one time only. It will not show on other ebooks.',
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (scopedReferralCode.isNotEmpty) const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isBuying
                            ? null
                            : isUnlocked
                            ? () => _openReader(product)
                            : () => _startCheckout(product),
                        icon: _isBuying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isUnlocked
                                    ? Icons.menu_book_rounded
                                    : Icons.shopping_bag_outlined,
                                size: 18,
                              ),
                        label: Text(isUnlocked ? 'Open eBook' : 'Purchase Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isUnlocked
                              ? const Color(0xFF1F8A5B)
                              : const Color(0xFF10213F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (product.previewAvailable) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openPreview(product),
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('Preview'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2D4F88),
                            side: const BorderSide(color: Color(0xFFD8E3F5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    required Color valueColor,
    bool isEmphasis = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: isEmphasis ? 13 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: isEmphasis ? 18 : 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _detailPill(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDCE7F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142D4F88),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF10213F),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  String _currencyText(double amount, String currency) {
    final normalizedCurrency = currency.trim().isEmpty
        ? 'USD'
        : currency.trim();
    return '$normalizedCurrency ${amount.toStringAsFixed(2)}';
  }
}

class _DetailCheckoutDecision {
  final String referralCode;
  final String referralProductId;

  const _DetailCheckoutDecision({
    required this.referralCode,
    required this.referralProductId,
  });
}
