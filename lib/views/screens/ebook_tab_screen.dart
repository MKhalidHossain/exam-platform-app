import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/error_handler.dart';
import '../../models/ebook_store_model.dart';
import '../../services/ebook_service.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/gradient_background.dart';

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
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool _isLoading = true;
  String? _error;
  EbookStoreData? _store;
  String? _selectedCategoryId;

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
    final upgradeOptionsRes = await _ebookService.getUpgradeAddOnOptions();

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
          failureFallback: 'Failed to load resources.',
        );
      }
    });
  }

  Future<void> _triggerRefreshFromButton() async {
    final refreshState = _refreshIndicatorKey.currentState;
    if (refreshState != null) {
      await refreshState.show();
      return;
    }
    await _loadData();
  }

  bool _storeHasProducts(EbookStoreData store) {
    for (final category in store.categories) {
      if (category.products.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  void _openCategoryDetails(EbookCategory category) {
    context.push(
      Uri(
        path: '/ebook-category',
        queryParameters: {'categoryId': category.id},
      ).toString(),
      extra: {'category': category},
    );
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
                        Icons.inventory_2_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resources',
                            style: TextStyle(
                              color: Color(0xFF10213F),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Study guides and reporting tools by certification',
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
                      onPressed: _triggerRefreshFromButton,
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
    final allCategories =
        store == null
              ? const <EbookCategory>[]
              : store.categories
                    .where((item) => item.products.isNotEmpty)
                    .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final categories = store == null
        ? const <EbookCategory>[]
        : (_selectedCategoryId == null
              ? allCategories
              : allCategories
                    .where((item) => item.id == _selectedCategoryId)
                    .toList(growable: false));

    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
        children: [
          _buildHeroSection(store),
          const SizedBox(height: 20),
          if (_isLoading && store == null)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: AppShimmerCircle(size: 42)),
            )
          else if (_error != null && store == null)
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Center(
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
              ),
            )
          else if (store != null) ...[
            _buildCategorySelector(allCategories),
            const SizedBox(height: 18),
            if (categories.isEmpty)
              _emptyState()
            else
              ...categories.map(_buildCategoryCard),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroSection(EbookStoreData? store) {
    final categories = store?.categories ?? const <EbookCategory>[];
    final productCount = categories.fold<int>(
      0,
      (sum, category) => sum + category.products.length,
    );
    final bundleCount = categories.fold<int>(
      0,
      (sum, category) =>
          sum + category.products.where((product) => product.isBundle).length,
    );

    return Container(
      padding: const EdgeInsets.all(18),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroStat(label: 'Resources', value: '$productCount'),
              _heroStat(label: 'Tracks', value: '${categories.length}'),
              _heroStat(label: 'Bundles', value: '$bundleCount'),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Upgrade Your Inspection Skills',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Go beyond practice. Master real inspection and reporting.',
            style: TextStyle(
              color: Color(0xFFD6E4FF),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              fontSize: 10,
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

  Widget _buildCategorySelector(List<EbookCategory> categories) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Certification Resources',
          style: TextStyle(
            color: Color(0xFF10213F),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose a certification to see the matching resources.',
          style: TextStyle(color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _categoryChip(
                  label: 'All',
                  selected: _selectedCategoryId == null,
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = null;
                    });
                  },
                ),
              ),
              ...categories.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _categoryChip(
                    label: category.title,
                    selected: _selectedCategoryId == category.id,
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = category.id;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(EbookCategory category) {
    final previewProduct = category.products.first;
    final subtitle = category.description.trim().isNotEmpty
        ? category.description
        : '${category.products.length} resources available';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openCategoryDetails(category),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
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
                    child: previewProduct.coverImageUrl.trim().isNotEmpty
                        ? Image.network(
                            previewProduct.coverImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _coverFallback(previewProduct),
                          )
                        : _coverFallback(previewProduct),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDCE7F7)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${category.products.length}',
                        style: const TextStyle(
                          color: Color(0xFF2D4F88),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Color(0xFF2D4F88),
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

  Widget _coverFallback(EbookProduct product) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16304F), Color(0xFF4A79C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
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
            maxLines: 2,
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
          Icon(Icons.inventory_2_rounded, size: 38, color: Color(0xFF2D4F88)),
          SizedBox(height: 12),
          Text(
            'No resources found for this filter.',
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
}
