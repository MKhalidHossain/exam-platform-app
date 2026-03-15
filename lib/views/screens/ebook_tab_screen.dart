import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:share_plus/share_plus.dart';
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

class EbookTabScreen extends StatefulWidget {
  final String initialReferralCode;
  final String initialProductId;

  const EbookTabScreen({
    super.key,
    this.initialReferralCode = '',
    this.initialProductId = '',
  });

  @override
  State<EbookTabScreen> createState() => _EbookTabScreenState();
}

class _EbookTabScreenState extends State<EbookTabScreen> {
  final EbookService _ebookService = EbookService();
  final ReferralService _referralService = ReferralService();
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  String? _error;
  EbookStoreData? _store;
  ReferralProfile? _referralProfile;
  String? _activeProductId;
  String? _selectedCategoryId;
  String _sharedReferralCode = '';
  String _sharedProductId = '';

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

    _sharedReferralCode = widget.initialReferralCode.trim().isNotEmpty
        ? widget.initialReferralCode.trim()
        : pendingReferralCode?.trim() ?? '';
    _sharedProductId = widget.initialProductId.trim().isNotEmpty
        ? widget.initialProductId.trim()
        : pendingProductId?.trim() ?? '';

    await _storageService.remove(AppConstants.pendingReferralCodeKey);
    await _storageService.remove(AppConstants.pendingReferralProductIdKey);
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final storeRes = await _ebookService.getEbookStore();
    final upgradeOptionsRes = await _ebookService.getUpgradeAddOnOptions();
    final referralRes = await _referralService.getMyReferralProfile();

    if (!mounted) return;

    final hasStoreProducts =
        storeRes.success &&
        storeRes.data != null &&
        _storeHasProducts(storeRes.data!);

    setState(() {
      _isLoading = false;
      if (hasStoreProducts) {
        _store = storeRes.data;
      } else if (upgradeOptionsRes.success &&
          upgradeOptionsRes.data != null &&
          upgradeOptionsRes.data!.isNotEmpty) {
        _store = EbookStoreData.fromUpgradeAddOnOptions(
          upgradeOptionsRes.data!,
          storeRes.data?.userAccess ??
              const EbookUserAccess(
                hasApi510InspectionGuide: false,
                hasApi510ReportGuide: false,
                hasApi510Bundle: false,
                resourceUnlocks: [],
              ),
        );
      } else {
        _error = ErrorHandler.getMessageFromResponse(
          storeRes,
          failureFallback: 'Failed to load eBook store data.',
        );
      }

      if (referralRes.success && referralRes.data != null) {
        _referralProfile = referralRes.data;
      }
    });
  }

  bool _storeHasProducts(EbookStoreData store) {
    for (final category in store.categories) {
      if (category.products.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> _buyWithStripe(
    EbookProduct product, {
    String referralCode = '',
  }) async {
    if (_activeProductId != null) return;

    setState(() => _activeProductId = product.id);

    try {
      final createRes = await _ebookService.createStripePaymentIntent(
        productId: product.id,
        referralCode: referralCode,
      );

      if (!mounted) return;

      if (!createRes.success || createRes.data == null) {
        setState(() => _activeProductId = null);
        ErrorHandler.showFromResponse(
          createRes,
          context: context,
          failureFallback: 'Unable to start payment.',
        );
        return;
      }

      final data = createRes.data!;
      if (data['unlocked'] == true) {
        setState(() => _activeProductId = null);
        await _loadData();
        await _openReader(product);
        return;
      }

      final clientSecret = data['clientSecret']?.toString() ?? '';
      final paymentIntentId = data['paymentIntentId']?.toString() ?? '';

      if (clientSecret.isEmpty || paymentIntentId.isEmpty) {
        setState(() => _activeProductId = null);
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
      setState(() => _activeProductId = null);

      if (!confirmRes.success) {
        ErrorHandler.showFromResponse(
          confirmRes,
          context: context,
          failureFallback: 'Payment confirmation failed.',
        );
        return;
      }

      if (referralCode.trim().isNotEmpty) {
        _sharedReferralCode = referralCode.trim();
      }
      _sharedProductId = product.id;

      ErrorHandler.showSnackBar(
        'Purchase completed. eBook unlocked.',
        isError: false,
        context: context,
      );

      await _loadData();
      await _openReader(product);
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() => _activeProductId = null);
      ErrorHandler.showSnackBar(
        e.error.message ?? 'Payment cancelled or failed.',
        isError: true,
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _activeProductId = null);
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
    await _buyWithStripe(product, referralCode: decision.referralCode);
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

  String _buildSharedDeepLink(EbookProduct product) {
    final params = Uri(
      queryParameters: {
        'productId': product.id,
        if (_referralProfile != null) 'ref': _referralProfile!.referralCode,
      },
    ).query;

    return 'ejflutter:///shared-ebook${params.isEmpty ? '' : '?$params'}';
  }

  Future<void> _shareEbook(EbookProduct product) async {
    final previewUrl = product.previewUrl.trim();
    final referralCode = _referralProfile?.referralCode.trim() ?? '';
    final referralLink = _referralProfile?.referralLink.trim() ?? '';

    final buffer = StringBuffer()
      ..writeln(product.title)
      ..writeln()
      ..writeln(
        product.shortDescription.trim().isNotEmpty
            ? product.shortDescription.trim()
            : 'Recommended from the EJ eBook Store.',
      );

    if (previewUrl.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Preview: $previewUrl');
    }

    if (referralCode.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Use referral code $referralCode for 10% off this ebook.');
    }

    buffer.writeln();
    buffer.writeln('Open in app: ${_buildSharedDeepLink(product)}');

    if (referralLink.isNotEmpty) {
      buffer.writeln('Referral link: $referralLink');
    }

    await Share.share(
      buffer.toString().trim(),
      subject: 'Check out ${product.title}',
    );
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

    if (!mounted) return;
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

  Future<_CheckoutDecision?> _showCheckoutSheet(EbookProduct product) async {
    final initialCode = _sharedReferralCode.trim();

    return showModalBottomSheet<_CheckoutDecision>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF8FAFF),
      builder: (context) {
        final referralController = TextEditingController(text: initialCode);
        ReferralPublicCode? referralPreview;
        bool isValidating = false;
        String? referralError;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final enteredCode = referralController.text.trim();
            final hasValidReferral =
                referralPreview != null &&
                referralPreview!.referralCode.toUpperCase() ==
                    enteredCode.toUpperCase();
            final referralDiscount = hasValidReferral
                ? product.pricing.current *
                      (referralPreview!.discountPercent / 100)
                : 0.0;
            final payableAmount = product.pricing.current - referralDiscount;

            Future<void> validateReferral() async {
              final code = referralController.text.trim();
              if (code.isEmpty) {
                setModalState(() {
                  referralPreview = null;
                  referralError = null;
                });
                return;
              }

              setModalState(() {
                isValidating = true;
                referralError = null;
              });

              final response = await _referralService.getPublicReferralCode(
                code,
              );
              if (!mounted) return;

              setModalState(() {
                isValidating = false;
                if (response.success && response.data != null) {
                  referralPreview = response.data;
                  referralError = null;
                } else {
                  referralPreview = null;
                  referralError = ErrorHandler.getMessageFromResponse(
                    response,
                    failureFallback: 'Referral code is not valid.',
                  );
                }
              });
            }

            Future<void> continueCheckout() async {
              final code = referralController.text.trim();
              if (code.isNotEmpty && !hasValidReferral) {
                await validateReferral();
                if (referralPreview == null) {
                  return;
                }
              }

              if (!context.mounted) return;
              Navigator.of(context).pop(_CheckoutDecision(referralCode: code));
            }

            return Padding(
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF475569),
                      ),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Price summary',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
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
                            _currencyText(
                              payableAmount,
                              product.pricing.currency,
                            ),
                            valueColor: Colors.white,
                            isEmphasis: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Referral code',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: referralController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Optional code for 10% off',
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: isValidating
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : TextButton(
                                onPressed: validateReferral,
                                child: const Text('Apply'),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFD8E3F5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFD8E3F5),
                          ),
                        ),
                      ),
                    ),
                    if (hasValidReferral) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F8EF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFB9E5C7)),
                        ),
                        child: Text(
                          'Referral applied from ${referralPreview!.referrerName}. '
                          'You save ${referralPreview!.discountPercent.toStringAsFixed(0)}%.',
                          style: const TextStyle(
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (referralError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        referralError!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: continueCheckout,
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: const Text('Continue to Stripe'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D4F88),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_EbookListItem> _flattenProducts(EbookStoreData store) {
    final categoryIdFilter = _selectedCategoryId;
    final List<_EbookListItem> items = [];

    for (final category in store.categories) {
      if (categoryIdFilter != null && category.id != categoryIdFilter) {
        continue;
      }

      for (final product in category.products) {
        items.add(_EbookListItem(category: category, product: product));
      }
    }

    items.sort((a, b) {
      final aShared = a.product.id == _sharedProductId ? 0 : 1;
      final bShared = b.product.id == _sharedProductId ? 0 : 1;
      if (aShared != bShared) {
        return aShared.compareTo(bShared);
      }

      final byCategory = a.category.sortOrder.compareTo(b.category.sortOrder);
      if (byCategory != 0) return byCategory;
      return a.product.sortOrder.compareTo(b.product.sortOrder);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        useImage: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10213F), Color(0xFF2D4F88)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ebook Store',
                            style: TextStyle(
                              color: Color(0xFF10213F),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Study guides, bundles, and referral offers',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh_rounded),
                      color: const Color(0xFF10213F),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final store = _store;

    if (_isLoading && store == null) {
      return const Center(child: AppShimmerCircle(size: 42));
    }

    if (_error != null && store == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
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

    if (store == null) {
      return const SizedBox.shrink();
    }

    final products = _flattenProducts(store);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
        children: [
          _buildHeroSection(store),
          const SizedBox(height: 18),
          if (_sharedReferralCode.isNotEmpty) _buildSharedEntryCard(),
          if (_sharedReferralCode.isNotEmpty) const SizedBox(height: 18),
          _buildCategorySelector(store),
          const SizedBox(height: 18),
          if (products.isEmpty)
            _emptyState()
          else
            ...products.map(_buildProductCard),
        ],
      ),
    );
  }

  Widget _buildHeroSection(EbookStoreData store) {
    final productCount = store.categories.fold<int>(
      0,
      (sum, category) => sum + category.products.length,
    );
    final referralCode = _referralProfile?.referralCode.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173B2E), Color(0xFF245B47), Color(0xFF4C9A7D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332D4F88),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _heroStat(label: 'Titles', value: '$productCount'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroStat(label: 'Buyer discount', value: '10%'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroStat(label: 'Your commission', value: '10%'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Professional API inspection ebooks with built-in referral sales.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            referralCode.isEmpty
                ? 'Share any product from the store. Buyers can use your referral code for an instant discount.'
                : 'Share your code $referralCode with any product and earn commission when that ebook is purchased.',
            style: const TextStyle(color: Color(0xFFD6E4FF), height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _heroStat({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD6E4FF),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedEntryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF6D87A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_offer_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shared referral detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7C4A03),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Referral code $_sharedReferralCode is ready to apply at checkout for a 10% discount.',
                  style: const TextStyle(color: Color(0xFF92400E), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(EbookStoreData store) {
    final categories = store.categories
        .where((item) => item.products.isNotEmpty)
        .toList();
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Browse by category',
          style: TextStyle(
            color: Color(0xFF10213F),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _categoryChip(
                label: 'All',
                selected: _selectedCategoryId == null,
                onTap: () => setState(() => _selectedCategoryId = null),
              ),
              ...categories.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _categoryChip(
                    label: category.title,
                    selected: _selectedCategoryId == category.id,
                    onTap: () =>
                        setState(() => _selectedCategoryId = category.id),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF334155),
        fontWeight: FontWeight.w700,
      ),
      selectedColor: const Color(0xFF2D4F88),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? const Color(0xFF2D4F88) : const Color(0xFFD8E3F5),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _buildProductCard(_EbookListItem item) {
    final product = item.product;
    final category = item.category;
    final isBusy = _activeProductId == product.id;
    final isUnlocked = product.unlocked || product.contentUrl.trim().isNotEmpty;
    final isSharedProduct = product.id == _sharedProductId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isSharedProduct
              ? const Color(0xFFF6D87A)
              : const Color(0xFFDCE7F7),
          width: isSharedProduct ? 1.4 : 1,
        ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 84,
                height: 118,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A10213F),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: product.coverImageUrl.trim().isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: const Color(0xFFE2E8F0)),
                            Image.network(
                              product.coverImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stackTrace) =>
                                  _coverFallback(product),
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: const Color(0xFFE2E8F0),
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                            ),
                            Positioned(
                              left: 8,
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xAA10213F),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  product.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : _coverFallback(product),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _tag(
                          category.title,
                          const Color(0xFFE0EDFF),
                          const Color(0xFF20437C),
                        ),
                        if (product.isBundle)
                          _tag(
                            'Bundle',
                            const Color(0xFFFFEDD5),
                            const Color(0xFFB45309),
                          ),
                        if (isUnlocked)
                          _tag(
                            'Unlocked',
                            const Color(0xFFE7F8EF),
                            const Color(0xFF166534),
                          ),
                        if (isSharedProduct)
                          _tag(
                            'Shared Pick',
                            const Color(0xFFFFF7D6),
                            const Color(0xFF8A5A00),
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
                      const SizedBox(height: 8),
                      Text(
                        product.shortDescription,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (product.bundleIncludes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: product.bundleIncludes
                  .map(
                    (item) => _tag(
                      item.replaceAll('_', ' ').toUpperCase(),
                      const Color(0xFFF1F5F9),
                      const Color(0xFF475569),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Store price',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _currencyText(
                            product.pricing.current,
                            product.pricing.currency,
                          ),
                          style: const TextStyle(
                            color: Color(0xFF10213F),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (product.pricing.original > product.pricing.current)
                          Text(
                            _currencyText(
                              product.pricing.original,
                              product.pricing.currency,
                            ),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_sharedReferralCode.isNotEmpty && !isUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F8EF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '10% referral ready',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isBusy
                      ? null
                      : isUnlocked
                      ? () => _openReader(product)
                      : () => _startCheckout(product),
                  icon: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isUnlocked
                              ? Icons.menu_book_rounded
                              : Icons.shopping_bag_outlined,
                          size: 18,
                        ),
                  label: Text(isUnlocked ? 'Open eBook' : 'Stripe Buy'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUnlocked
                        ? const Color(0xFF1F8A5B)
                        : const Color(0xFF10213F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
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
              const SizedBox(width: 8),
              _actionIcon(
                tooltip: 'Share',
                icon: Icons.share_outlined,
                onTap: () => _shareEbook(product),
              ),
              if (product.previewAvailable) ...[
                const SizedBox(width: 8),
                _actionIcon(
                  tooltip: 'Preview',
                  icon: Icons.visibility_outlined,
                  onTap: () => _openPreview(product),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionIcon({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xFF2D4F88), size: 20),
        ),
      ),
    );
  }

  Widget _tag(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _coverFallback(EbookProduct product) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16304F), Color(0xFF4A79C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
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
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          const Icon(
            Icons.auto_stories_rounded,
            color: Color(0xFFDCE7F8),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE7F7)),
      ),
      child: const Column(
        children: [
          Icon(Icons.auto_stories_rounded, size: 38, color: Color(0xFF2D4F88)),
          SizedBox(height: 12),
          Text(
            'No eBooks found for this filter.',
            style: TextStyle(
              color: Color(0xFF10213F),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color valueColor = const Color(0xFF10213F),
    bool isEmphasis = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isEmphasis ? Colors.white70 : const Color(0xFFD6E4FF),
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

  String _currencyText(double amount, String currency) {
    final symbol = currency.toUpperCase() == 'USD'
        ? r'$'
        : '${currency.toUpperCase()} ';
    final hasFraction = amount % 1 != 0;
    return '$symbol${amount.toStringAsFixed(hasFraction ? 2 : 0)}';
  }
}

class _EbookListItem {
  final EbookCategory category;
  final EbookProduct product;

  const _EbookListItem({required this.category, required this.product});
}

class _CheckoutDecision {
  final String referralCode;

  const _CheckoutDecision({required this.referralCode});
}
