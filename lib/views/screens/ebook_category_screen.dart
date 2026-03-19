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
    return RefreshIndicator(
      onRefresh: _loadCategory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 170),
              child: Center(child: AppShimmerCircle(size: 42)),
            )
          else if (_error != null || _category == null)
            Padding(
              padding: const EdgeInsets.only(top: 120),
              child: Center(
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
              ),
            )
          else ...[
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
                      _category!.shortCode.trim().isEmpty
                          ? 'CATEGORY'
                          : _category!.shortCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _category!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  if (_category!.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _category!.description,
                      style: const TextStyle(
                        color: Color(0xFFD6E4FF),
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    '${_category!.products.length} resource${_category!.products.length == 1 ? '' : 's'} in this certification',
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
            ..._category!.products.map(_buildProductCard),
          ],
        ],
      ),
    );
  }

  Widget _buildProductCard(EbookProduct product) {
    final isUnlocked = product.unlocked || product.contentUrl.trim().isNotEmpty;
    final subtitle = product.shortDescription.trim().isNotEmpty
        ? product.shortDescription
        : (product.isBundle ? 'Bundle resource' : 'Digital resource');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openProduct(product),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD9D9E3), width: 1),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: product.coverImageUrl.trim().isNotEmpty
                      ? Image.network(
                          product.coverImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _coverFallback(),
                        )
                      : _coverFallback(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.isBundle) ...[
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
                      const SizedBox(height: 6),
                    ],
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildProductStatus(product, isUnlocked),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductStatus(EbookProduct product, bool isUnlocked) {
    if (isUnlocked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _StatusDot(color: Color(0xFF2DBD67), icon: Icons.check),
          SizedBox(width: 6),
          Text(
            'Unlocked',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2DBD67),
            ),
          ),
        ],
      );
    }

    final currentPrice = product.pricing.current;
    final actionLabel = currentPrice > 0
        ? _formatUnlockLabel(currentPrice, product.pricing.currency)
        : 'View details';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2DBD67),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        actionLabel,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  String _formatUnlockLabel(double price, String currency) {
    return 'Unlock for ${_currencyText(price, currency)}';
  }

  Widget _coverFallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: const Icon(
        Icons.menu_book_rounded,
        color: Color(0xFF64748B),
        size: 24,
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _StatusDot({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}
