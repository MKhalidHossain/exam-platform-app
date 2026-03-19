import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error/error_handler.dart';
import '../../models/ebook_store_model.dart';
import '../../services/ebook_service.dart';
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
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  String? _error;
  EbookStoreData? _store;
  EbookProduct? _product;
  String _productId = '';
  bool _isBuying = false;

  @override
  void initState() {
    super.initState();
    _primeSharedContext().then((_) => _loadData());
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

  Future<void> _loadData() async {
    if (_productId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Shared resource is missing a product id.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

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
      _store = store;
      _product = product;
      if (product == null) {
        _error = 'Unable to find this resource.';
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
          child: _isLoading
              ? _buildLoading()
              : _error != null
              ? _buildError()
              : product == null
              ? _buildError(message: 'Unable to load resource.')
              : _buildBody(product),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 170),
            child: Center(child: AppShimmerCircle(size: 42)),
          ),
        ],
      ),
    );
  }

  Widget _buildError({String? message}) {
    return RefreshIndicator(
      onRefresh: _loadData,
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
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                  'Resource Details',
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
                                : 'Professional resource from the EJ store.',
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
                                        product.pricing.current,
                                        product.pricing.currency,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (product.pricing.original >
                                        product.pricing.current)
                                      Text(
                                        _currencyText(
                                          product.pricing.original,
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
            title: product.isBundle
                ? 'About This Bundle'
                : 'About This Resource',
            child: Text(
              product.fullDescription.trim().isNotEmpty
                  ? product.fullDescription
                  : product.shortDescription.trim().isNotEmpty
                  ? product.shortDescription
                  : product.isBundle
                  ? 'This bundle groups multiple study guides into one purchase so every included resource unlocks together.'
                  : 'This resource gives you practical study material, structured explanations, and a focused buying flow for certification preparation.',
              style: const TextStyle(color: Color(0xFF475569), height: 1.65),
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
                    if (!product.isBundle && product.previewAvailable) ...[
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
                    if (product.previewAvailable) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _openPreview(product),
                        icon: const Icon(Icons.visibility_outlined, size: 17),
                        label: const Text('Preview'),
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
