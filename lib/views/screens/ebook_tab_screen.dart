import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error/error_handler.dart';
import '../../models/ebook_store_model.dart';
import '../../models/referral_model.dart';
import '../../services/ebook_service.dart';
import '../../services/referral_service.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/gradient_background.dart';
import 'ebook_pdf_viewer_screen.dart';

class EbookTabScreen extends StatefulWidget {
  const EbookTabScreen({super.key});

  @override
  State<EbookTabScreen> createState() => _EbookTabScreenState();
}

class _EbookTabScreenState extends State<EbookTabScreen> {
  final EbookService _ebookService = EbookService();
  final ReferralService _referralService = ReferralService();

  bool _isLoading = true;
  String? _error;
  EbookStoreData? _store;
  ReferralProfile? _referralProfile;
  String? _activeProductId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final storeRes = await _ebookService.getEbookStore();
    final referralRes = await _referralService.getMyReferralProfile();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (storeRes.success && storeRes.data != null) {
        _store = storeRes.data;
      } else {
        _error = ErrorHandler.getMessageFromResponse(
          storeRes,
          failureFallback: 'Failed to load eBook store.',
        );
      }

      if (referralRes.success && referralRes.data != null) {
        _referralProfile = referralRes.data;
      }
    });
  }

  Future<void> _buyWithStripe(EbookProduct product) async {
    if (_activeProductId != null) return;

    setState(() => _activeProductId = product.id);

    try {
      final createRes = await _ebookService.createStripePaymentIntent(
        productId: product.id,
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

  Future<void> _openReader(EbookProduct product) async {
    var contentUrl = product.contentUrl;

    if (contentUrl.trim().isEmpty) {
      final contentRes = await _ebookService.getPurchasedContent(productId: product.id);
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
        builder: (_) => EbookPdfViewerScreen(
          title: product.title,
          pdfUrl: contentUrl,
        ),
      ),
    );
  }

  Future<void> _shareEbook(EbookProduct product) async {
    final String link = product.previewUrl.trim().isNotEmpty
        ? product.previewUrl.trim()
        : product.contentUrl.trim();

    final String referralLink = _referralProfile?.referralLink.trim() ?? '';

    final buffer = StringBuffer();
    buffer.writeln('Check this eBook: ${product.title}');
    if (product.shortDescription.trim().isNotEmpty) {
      buffer.writeln(product.shortDescription.trim());
    }
    if (link.isNotEmpty) {
      buffer.writeln('eBook link: $link');
    }
    if (referralLink.isNotEmpty) {
      buffer.writeln('Use my referral link for 10% discount: $referralLink');
    }

    await Share.share(
      buffer.toString().trim(),
      subject: 'eBook recommendation',
    );
  }

  Future<void> _openPreview(EbookProduct product) async {
    final url = product.previewUrl.trim();
    if (url.isEmpty) {
      ErrorHandler.showSnackBar(
        'Preview is not available.',
        isError: true,
        context: context,
      );
      return;
    }

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
  }

  List<_EbookListItem> _flattenProducts(EbookStoreData store) {
    final List<_EbookListItem> items = [];
    for (final category in store.categories) {
      for (final product in category.products) {
        items.add(_EbookListItem(category: category, product: product));
      }
    }
    items.sort((a, b) {
      final byCategory = a.category.sortOrder.compareTo(b.category.sortOrder);
      if (byCategory != 0) return byCategory;
      return a.product.sortOrder.compareTo(b.product.sortOrder);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;

    return Scaffold(
      body: GradientBackground(
        useImage: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFF2D4F88),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'eBook Store',
                        style: TextStyle(
                          color: Color(0xFF2D4F88),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh_rounded),
                      color: const Color(0xFF2D4F88),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildBody(store),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(EbookStoreData? store) {
    if (_isLoading && store == null) {
      return const Center(
        child: AppShimmerCircle(size: 40),
      );
    }

    if (_error != null && store == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
              const SizedBox(height: 12),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _buildRewardBanner(),
          const SizedBox(height: 14),
          if (_referralProfile != null) _buildReferralLinkCard(_referralProfile!),
          if (_referralProfile != null) const SizedBox(height: 14),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'No eBooks available right now.',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            ...products.map(_buildProductCard),
        ],
      ),
    );
  }

  Widget _buildRewardBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFD0F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Referral Program',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A8A),
            ),
          ),
          SizedBox(height: 8),
          _OfferTag(text: 'Referrer Reward 10% commission'),
          SizedBox(height: 8),
          _OfferTag(text: 'New User Reward 10% discount'),
        ],
      ),
    );
  }

  Widget _buildReferralLinkCard(ReferralProfile profile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E3FB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share your referral link',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D4F88),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.referralLink,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {
                Share.share(
                  'Join using my referral link and get 10% discount: ${profile.referralLink}',
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2D4F88),
                side: const BorderSide(color: Color(0xFF2D4F88)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(_EbookListItem item) {
    final product = item.product;
    final category = item.category;
    final isBusy = _activeProductId == product.id;
    final isUnlocked = product.unlocked || product.contentUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 70,
              height: 95,
              child: product.coverImageUrl.trim().isNotEmpty
                  ? Image.network(
                      product.coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverFallback(),
                    )
                  : _coverFallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (product.shortDescription.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    product.shortDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _currencyText(
                        product.pricing.current,
                        product.pricing.currency,
                      ),
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (product.pricing.original > product.pricing.current) ...[
                      const SizedBox(width: 8),
                      Text(
                        _currencyText(
                          product.pricing.original,
                          product.pricing.currency,
                        ),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          decoration: TextDecoration.lineThrough,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isBusy
                            ? null
                            : isUnlocked
                                ? () => _openReader(product)
                                : () => _buyWithStripe(product),
                        icon: isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(isUnlocked ? Icons.menu_book_rounded : Icons.shopping_cart_checkout_rounded),
                        label: Text(isUnlocked ? 'Read PDF' : 'Buy Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D4F88),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _shareEbook(product),
                      icon: const Icon(Icons.share_outlined),
                      color: const Color(0xFF2D4F88),
                      tooltip: 'Share',
                    ),
                    if (product.previewAvailable && product.previewUrl.trim().isNotEmpty)
                      IconButton(
                        onPressed: () => _openPreview(product),
                        icon: const Icon(Icons.visibility_outlined),
                        color: const Color(0xFF2D4F88),
                        tooltip: 'Preview',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: const Icon(
        Icons.menu_book_rounded,
        color: Color(0xFF64748B),
      ),
    );
  }

  String _currencyText(double amount, String currency) {
    final symbol = currency.toUpperCase() == 'USD' ? r'$' : '${currency.toUpperCase()} ';
    final hasFraction = amount % 1 != 0;
    return '$symbol${amount.toStringAsFixed(hasFraction ? 2 : 0)}';
  }
}

class _EbookListItem {
  final EbookCategory category;
  final EbookProduct product;

  const _EbookListItem({
    required this.category,
    required this.product,
  });
}

class _OfferTag extends StatelessWidget {
  final String text;

  const _OfferTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: Color(0xFF1D4ED8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
