import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/ebook_store_model.dart';
import '../../services/ebook_service.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/gradient_background.dart';

class EbookCategoryScreen extends StatefulWidget {
  final String categoryId;
  final EbookCategory? initialCategory;
  final String initialReferralCode;
  final String initialProductId;

  const EbookCategoryScreen({
    super.key,
    required this.categoryId,
    this.initialCategory,
    this.initialReferralCode = '',
    this.initialProductId = '',
  });

  @override
  State<EbookCategoryScreen> createState() => _EbookCategoryScreenState();
}

class _EbookCategoryScreenState extends State<EbookCategoryScreen> {
  final EbookService _ebookService = EbookService();

  bool _isLoading = true;
  String? _error;
  EbookCategory? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    if (_category != null) {
      _isLoading = false;
    } else {
      _loadCategory();
    }
  }

  Future<void> _loadCategory() async {
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

    final category = _findCategoryById(store, widget.categoryId);

    setState(() {
      _isLoading = false;
      _category = category;
      if (category == null) {
        _error = 'Unable to find this resource category.';
      }
    });
  }

  bool _storeHasProducts(EbookStoreData store) {
    for (final category in store.categories) {
      if (category.products.isNotEmpty) return true;
    }
    return false;
  }

  EbookCategory? _findCategoryById(EbookStoreData? store, String categoryId) {
    if (store == null) return null;
    final normalizedId = categoryId.trim();
    if (normalizedId.isEmpty) return null;

    for (final category in store.categories) {
      if (category.id == normalizedId) {
        return category;
      }
    }
    return null;
  }

  void _openProduct(EbookProduct product) {
    context.push(
      Uri(
        path: '/ebook-detail',
        queryParameters: {'productId': product.id},
      ).toString(),
    );
  }

  String _currencyText(double amount, String currency) {
    final symbol = currency.toUpperCase() == 'USD'
        ? r'$'
        : '${currency.toUpperCase()} ';
    final hasFraction = amount % 1 != 0;
    return '$symbol${amount.toStringAsFixed(hasFraction ? 2 : 0)}';
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: const Color(0xFF10213F),
                    ),
                    Expanded(
                      child: Text(
                        _category?.title ?? 'Resource Category',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF10213F),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
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
    if (_isLoading) {
      return const Center(child: AppShimmerCircle(size: 42));
    }

    if (_error != null || _category == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Unable to load category.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _loadCategory,
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

    final category = _category!;

    return RefreshIndicator(
      onRefresh: _loadCategory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10213F), Color(0xFF2D4F88)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1FFFFFFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    category.shortCode.trim().isEmpty
                        ? 'CATEGORY'
                        : category.shortCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  category.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                if (category.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    category.description,
                    style: const TextStyle(
                      color: Color(0xFFD6E4FF),
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  '${category.products.length} resource${category.products.length == 1 ? '' : 's'} in this certification',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...category.products.map(_buildProductCard),
        ],
      ),
    );
  }

  Widget _buildProductCard(EbookProduct product) {
    final isUnlocked = product.unlocked || product.contentUrl.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openProduct(product),
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDCE7F7)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 78,
                    height: 104,
                    child: product.coverImageUrl.trim().isNotEmpty
                        ? Image.network(
                            product.coverImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _coverFallback(product),
                          )
                        : _coverFallback(product),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (product.isBundle)
                            _tag(
                              'Bundle',
                              const Color(0xFFFFEDD5),
                              const Color(0xFFB45309),
                            ),
                          _tag(
                            isUnlocked ? 'Unlocked' : 'View details',
                            isUnlocked
                                ? const Color(0xFFE7F8EF)
                                : const Color(0xFFE0EDFF),
                            isUnlocked
                                ? const Color(0xFF166534)
                                : const Color(0xFF20437C),
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
                      const SizedBox(height: 12),
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
                              color: Color(0xFF10213F),
                              fontSize: 18,
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
                ),
              ],
            ),
          ),
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
                  ? 'RESOURCE'
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
        ],
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
}
