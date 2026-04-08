import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/error/error_handler.dart';
import '../../models/ebook_store_model.dart';
import '../../services/ebook_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_constants.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/animated_refresh_button.dart';
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

class _CachedEbookDetailData {
  final EbookStoreData store;
  final EbookProduct product;

  const _CachedEbookDetailData({required this.store, required this.product});
}

class _EbookDetailScreenState extends State<EbookDetailScreen> {
  static final Map<String, _CachedEbookDetailData> _detailCache = {};

  final EbookService _ebookService = EbookService();
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isFetching = false;
  String? _error;
  EbookStoreData? _store;
  EbookProduct? _product;
  String _productId = '';
  bool _isBuying = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _primeSharedContext();
    if (!mounted) return;
    _restoreCachedData();
    await _loadData(showLoader: _product == null);
  }

  Future<void> _primeSharedContext() async {
    final pendingProductId = await _storageService.getString(
      AppConstants.pendingReferralProductIdKey,
    );

    _productId = widget.productId.trim().isNotEmpty
        ? widget.productId.trim()
        : pendingProductId?.trim() ?? '';
    await _storageService.remove(AppConstants.pendingReferralProductIdKey);
  }

  void _restoreCachedData() {
    if (_productId.isEmpty) return;

    final cached = _detailCache[_productId];
    if (cached == null) return;

    setState(() {
      _store = cached.store;
      _product = cached.product;
      _isLoading = false;
      _isRefreshing = false;
      _error = null;
    });
  }

  void _cacheCurrentData(EbookStoreData store, EbookProduct product) {
    if (_productId.isEmpty) return;
    _detailCache[_productId] = _CachedEbookDetailData(
      store: store,
      product: product,
    );
  }

  Future<void> _loadData({
    bool showLoader = false,
    bool showRefreshIndicator = false,
  }) async {
    if (_isFetching) return;

    if (_productId.isEmpty) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _error = 'Shared resource is missing a product id.';
      });
      return;
    }

    final hasExistingContent = _store != null && _product != null;
    _isFetching = true;

    if (mounted) {
      setState(() {
        if (showLoader || !hasExistingContent) {
          _isLoading = true;
          _error = null;
        } else if (showRefreshIndicator) {
          _isRefreshing = true;
        }
      });
    }

    try {
      final storeRes = await _ebookService.getEbookStore();
      final upgradeOptionsRes = await _ebookService.getUpgradeAddOnOptions();

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
        _isRefreshing = false;

        if (product != null) {
          _store = store;
          _product = product;
          _error = null;
          _cacheCurrentData(store!, product);
          return;
        }

        if (!hasExistingContent) {
          _store = store;
          _product = null;
          _error = 'Unable to find this resource.';
        }
      });
    } finally {
      _isFetching = false;
    }
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

  List<EbookProduct> _findProductsByCodes(
    EbookStoreData? store,
    List<String> codes, {
    String excludeProductId = '',
  }) {
    if (store == null || codes.isEmpty) return const <EbookProduct>[];

    final normalizedCodes = codes
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    final products = <EbookProduct>[];

    for (final category in store.categories) {
      for (final product in category.products) {
        final normalizedCode = product.code.trim().toLowerCase();
        if (product.id == excludeProductId) continue;
        if (normalizedCodes.contains(normalizedCode)) {
          products.add(product);
        }
      }
    }

    products.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return products;
  }

  Future<void> _openPreview(EbookProduct product) async {
    final isUnlocked = product.unlocked || product.contentUrl.trim().isNotEmpty;
    if (isUnlocked) {
      await _openReader(product);
      return;
    }

    var previewTitle = product.previewTitle.trim();
    var previewContent = product.previewContent.trim();
    var previewUrl = product.previewUrl.trim();

    final previewRes = await _ebookService.getResourcePreview(
      productId: product.id,
    );
    if (!mounted) return;

    if (previewRes.success && previewRes.data != null) {
      previewTitle = previewRes.data!.title.trim();
      previewContent = previewRes.data!.previewContent.trim();
      previewUrl = previewRes.data!.previewUrl.trim();
    }

    final url = previewUrl;
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

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EbookPdfViewerScreen(
            title: previewTitle.isNotEmpty ? previewTitle : product.title,
            pdfUrl: uri.toString(),
            isPreview: true,
            onUnlockRequested: () => _startCheckout(product),
          ),
        ),
      );
      return;
    }

    if (previewContent.isEmpty) {
      if (!previewRes.success) {
        ErrorHandler.showFromResponse(
          previewRes,
          context: context,
          failureFallback: 'Preview is not available.',
        );
      } else {
        ErrorHandler.showSnackBar(
          'Preview is not available.',
          isError: true,
          context: context,
        );
      }
      return;
    }

    ErrorHandler.showSnackBar(
      'Preview PDF is not available for this resource.',
      isError: true,
      context: context,
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
          failureFallback: 'You need to purchase this resource first.',
        );
        return;
      }
      contentUrl = contentRes.data!.contentUrl;
    }

    if (contentUrl.trim().isEmpty) {
      ErrorHandler.showSnackBar(
        'PDF URL is not available for this resource.',
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

  Future<bool?> _showCheckoutSheet(EbookProduct product) async {
    return showModalBottomSheet<bool>(
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
                    const Divider(color: Color(0x33FFFFFF), height: 22),
                    _summaryRow(
                      'Pay now',
                      _currencyText(
                        product.pricing.current,
                        product.pricing.currency,
                      ),
                      valueColor: Colors.white,
                      isEmphasis: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10213F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Continue to Payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buyWithStripe(EbookProduct product) async {
    if (_isBuying) return;
    setState(() => _isBuying = true);

    try {
      final createRes = await _ebookService.createStripePaymentIntent(
        productId: product.id,
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
          merchantDisplayName: 'EJ Resource Store',
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
        'Purchase completed. Resource unlocked.',
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
    final shouldContinue = await _showCheckoutSheet(product);
    if (!mounted || shouldContinue != true) return;
    await _buyWithStripe(product);
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    return Scaffold(
      body: GradientBackground(
        useImage: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _buildHeader(),
              ),
              if (_isRefreshing)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Color(0x1A10213F),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF2D4F88),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? _buildLoading()
                    : _error != null
                    ? _buildError()
                    : product == null
                    ? _buildError(message: 'Unable to load resource.')
                    : _buildBody(product),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: const Color(0xFF10213F),
        ),
        const Expanded(
          child: Text(
            'Resource Details',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF10213F),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        AnimatedRefreshButton(
          onPressed: () => _loadData(showRefreshIndicator: true),
          tooltip: 'Refresh resource details',
          backgroundColor: const Color(0xFFF8FAFC),
          borderColor: const Color(0x1F10213F),
          shadowColor: const Color(0x1A10213F),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return RefreshIndicator(
      onRefresh: () => _loadData(showRefreshIndicator: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          _buildLoadingHeroCard(),
          const SizedBox(height: 18),
          _buildLoadingSectionCard(
            lineWidths: const [220, double.infinity, 240],
          ),
          const SizedBox(height: 16),
          _buildLoadingSectionCard(
            lineWidths: const [180, double.infinity, double.infinity, 210],
          ),
          const SizedBox(height: 16),
          _buildLoadingActionsCard(),
        ],
      ),
    );
  }

  Widget _buildError({String? message}) {
    return RefreshIndicator(
      onRefresh: () => _loadData(showRefreshIndicator: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 120),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message ?? _error ?? 'Unable to load resource.',
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10213F), Color(0xFF1C3867), Color(0xFF355B97)],
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
        children: const [
          AppShimmerBox(height: 190, radius: 24),
          SizedBox(height: 14),
          Row(
            children: [
              AppShimmerBox(width: 108, height: 32, radius: 999),
              SizedBox(width: 8),
              AppShimmerBox(width: 96, height: 32, radius: 999),
              Spacer(),
              AppShimmerBox(width: 56, height: 30, radius: 999),
            ],
          ),
          SizedBox(height: 14),
          AppShimmerBox(width: double.infinity, height: 24, radius: 8),
          SizedBox(height: 8),
          AppShimmerBox(width: 220, height: 24, radius: 8),
          SizedBox(height: 10),
          AppShimmerBox(width: double.infinity, height: 14, radius: 6),
          SizedBox(height: 8),
          AppShimmerBox(width: 250, height: 14, radius: 6),
          SizedBox(height: 14),
          AppShimmerBox(width: double.infinity, height: 70, radius: 20),
        ],
      ),
    );
  }

  Widget _buildLoadingSectionCard({required List<double> lineWidths}) {
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
          const AppShimmerBox(width: 170, height: 24, radius: 8),
          const SizedBox(height: 18),
          ...lineWidths.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == lineWidths.length - 1 ? 0 : 10,
              ),
              child: AppShimmerBox(
                width: entry.value == double.infinity
                    ? double.infinity
                    : entry.value,
                height: 14,
                radius: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingActionsCard() {
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmerBox(width: 180, height: 24, radius: 8),
          SizedBox(height: 18),
          AppShimmerBox(width: double.infinity, height: 52, radius: 20),
          SizedBox(height: 12),
          AppShimmerBox(width: double.infinity, height: 52, radius: 18),
        ],
      ),
    );
  }

  Widget _buildBody(EbookProduct product) {
    final isUnlocked = product.unlocked || product.contentUrl.trim().isNotEmpty;
    final bundledProducts = product.isBundle
        ? _findProductsByCodes(
            _store,
            product.bundleIncludes,
            excludeProductId: product.id,
          )
        : const <EbookProduct>[];
    final bundleIsResolved = bundledProducts.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () => _loadData(showRefreshIndicator: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
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
                _buildHeroCover(product),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _detailPill(
                            product.isBundle ? 'Bundle' : 'Single Resource',
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _heroCurrencyBadge(product.pricing.currency),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  product.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 14),
                _buildHeroPriceCard(product, isUnlocked: isUnlocked),
              ],
            ),
          ),
          if (product.bundleIncludes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionCard(
              title: product.isBundle ? 'Bundle Resources' : 'What You Get',
              child: bundleIsResolved
                  ? Column(
                      children: bundledProducts
                          .map(
                            (bundleProduct) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildBundleProductCard(bundleProduct),
                            ),
                          )
                          .toList(growable: false),
                    )
                  : Wrap(
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
          if (product.isBundle && bundleIsResolved) ...[
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Bundle Access',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? const Color(0xFFE7F8EF)
                      : const Color(0xFFF8FAFF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isUnlocked
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFDCE7F7),
                  ),
                ),
                child: Text(
                  isUnlocked
                      ? 'This bundle purchase unlocks all ${bundledProducts.length} included resource${bundledProducts.length == 1 ? '' : 's'}. Open each one from the list above.'
                      : 'Buying this bundle will unlock all ${bundledProducts.length} included resource${bundledProducts.length == 1 ? '' : 's'} together.',
                  style: TextStyle(
                    color: isUnlocked
                        ? const Color(0xFF166534)
                        : const Color(0xFF334155),
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Purchase Actions',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isBuying
                            ? null
                            : product.isBundle
                            ? isUnlocked
                                  ? null
                                  : () => _startCheckout(product)
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
                                product.isBundle
                                    ? isUnlocked
                                          ? Icons.collections_bookmark_rounded
                                          : Icons.shopping_bag_outlined
                                    : isUnlocked
                                    ? Icons.menu_book_rounded
                                    : Icons.shopping_bag_outlined,
                                size: 18,
                              ),
                        label: Text(
                          product.isBundle
                              ? isUnlocked
                                    ? 'Bundle Unlocked'
                                    : 'Purchase Bundle'
                              : isUnlocked
                              ? 'Open Resource'
                              : 'Purchase Resource',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isUnlocked
                              ? const Color(0xFF1F8A5B)
                              : const Color(0xFF10213F),
                          disabledBackgroundColor: const Color(0xFF1F8A5B),
                          disabledForegroundColor: Colors.white,
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
                    if (!product.isBundle &&
                        product.previewAvailable &&
                        !isUnlocked) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openPreview(product),
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('Preview 5 Pages'),
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

  Widget _buildBundleProductCard(EbookProduct product) {
    final isUnlocked = product.unlocked || product.contentUrl.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE7F7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 72,
              height: 92,
              child: product.coverImageUrl.trim().isNotEmpty
                  ? Image.network(
                      product.coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _bundleCoverFallback(product),
                    )
                  : _bundleCoverFallback(product),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _detailPill(
                      isUnlocked ? 'Unlocked' : 'Included in bundle',
                      isUnlocked
                          ? const Color(0xFFE7F8EF)
                          : const Color(0xFFE0EDFF),
                      isUnlocked
                          ? const Color(0xFF166534)
                          : const Color(0xFF20437C),
                    ),
                    if (product.previewAvailable)
                      _detailPill(
                        'Preview',
                        const Color(0xFFF1F5F9),
                        const Color(0xFF475569),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  product.title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                if (product.shortDescription.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    product.shortDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isUnlocked
                            ? () => _openReader(product)
                            : null,
                        icon: const Icon(Icons.menu_book_rounded, size: 17),
                        label: const Text('Open'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F8A5B),
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          disabledForegroundColor: const Color(0xFF64748B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    if (product.previewAvailable && !isUnlocked) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _openPreview(product),
                        icon: const Icon(Icons.visibility_outlined, size: 17),
                        label: const Text('Preview 5 Pages'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2D4F88),
                          side: const BorderSide(color: Color(0xFFD8E3F5)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
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

  Widget _buildHeroCover(EbookProduct product) {
    return Container(
      width: double.infinity,
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x2EFFFFFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000F2E),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: product.coverImageUrl.trim().isNotEmpty
            ? Image.network(
                product.coverImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _heroCoverFallback(),
              )
            : _heroCoverFallback(),
      ),
    );
  }

  Widget _heroCoverFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 58,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _heroCurrencyBadge(String currency) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        border: Border.all(color: const Color(0x22FFFFFF)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        currency,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildHeroPriceCard(EbookProduct product, {required bool isUnlocked}) {
    final displayAmount = product.pricing.current;
    final originalAmount = product.pricing.original > 0
        ? product.pricing.original
        : product.pricing.current;
    final showOriginalPrice = originalAmount > displayAmount;
    final currentPrice = _currencyText(displayAmount, product.pricing.currency);
    final originalPrice = _currencyText(
      originalAmount,
      product.pricing.currency,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x16FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total price',
                  style: TextStyle(
                    color: Color(0xFFD9E5FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isUnlocked
                      ? 'Already unlocked for your account'
                      : 'One-time purchase with instant access',
                  style: const TextStyle(
                    color: Color(0xFFB8C7E6),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: showOriginalPrice
                      ? const Color(0x1AF59E0B)
                      : const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  showOriginalPrice ? 'Offer' : 'Regular Price',
                  style: TextStyle(
                    color: showOriginalPrice
                        ? const Color(0xFFFFE0A3)
                        : const Color(0xFFE2E8F0),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                currentPrice,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              if (showOriginalPrice)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    originalPrice,
                    style: const TextStyle(
                      color: Color(0xFFB8C7E6),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Color(0xFFB8C7E6),
                      decorationThickness: 2,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bundleCoverFallback(EbookProduct product) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF183153), Color(0xFF355B97)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              product.code.trim().isEmpty
                  ? 'EBOOK'
                  : product.code.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          Text(
            product.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1.15,
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
