import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/error_handler.dart';
import '../../models/ebook_store_model.dart';
import '../../models/referral_model.dart';
import '../../services/ebook_service.dart';
import '../../services/referral_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_constants.dart';
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
  final ReferralService _referralService = ReferralService();
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  String? _error;
  EbookStoreData? _store;
  ReferralProfile? _referralProfile;
  String _sharedReferralCode = '';
  String _sharedProductId = '';
  String? _selectedCategoryId;

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
        _removeSelfReferralFromSharedContext(referralRes.data!);
      }
    });
  }

  void _removeSelfReferralFromSharedContext(ReferralProfile profile) {
    final myReferralCode = profile.referralCode.trim().toUpperCase();
    final sharedReferralCode = _sharedReferralCode.trim().toUpperCase();

    if (myReferralCode.isEmpty || sharedReferralCode.isEmpty) {
      return;
    }

    if (myReferralCode == sharedReferralCode) {
      _sharedReferralCode = '';
    }
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
        queryParameters: {
          'categoryId': category.id,
          if (_sharedReferralCode.trim().isNotEmpty) 'ref': _sharedReferralCode,
          if (_sharedProductId.trim().isNotEmpty) 'productId': _sharedProductId,
        },
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

    final allCategories =
        store.categories.where((item) => item.products.isNotEmpty).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final categories = _selectedCategoryId == null
        ? allCategories
        : allCategories
              .where((item) => item.id == _selectedCategoryId)
              .toList(growable: false);

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
          if (categories.isEmpty)
            _emptyState()
          else
            ...categories.map(_buildCategoryCard),
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
    final categories =
        store.categories.where((item) => item.products.isNotEmpty).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
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
    final previewProducts = category.products.take(3).toList(growable: false);
    final coverProduct = category.products.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openCategoryDetails(category),
          borderRadius: BorderRadius.circular(26),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFDCE7F7)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x142D4F88),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 92,
                  height: 122,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A10213F),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: coverProduct.coverImageUrl.trim().isNotEmpty
                        ? Image.network(
                            coverProduct.coverImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _coverFallback(coverProduct),
                          )
                        : _coverFallback(coverProduct),
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
                          _tag(
                            category.shortCode.trim().isEmpty
                                ? 'CATEGORY'
                                : category.shortCode,
                            const Color(0xFFE0EDFF),
                            const Color(0xFF20437C),
                          ),
                          _tag(
                            '${category.products.length} eBooks',
                            const Color(0xFFE7F8EF),
                            const Color(0xFF166534),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        category.title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      if (category.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          category.description,
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
                        runSpacing: 8,
                        children: previewProducts
                            .map(
                              (product) => _tag(
                                product.title,
                                const Color(0xFFF1F5F9),
                                const Color(0xFF475569),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Color(0xFF2D4F88),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'View category ebooks',
                            style: const TextStyle(
                              color: Color(0xFF2D4F88),
                              fontWeight: FontWeight.w800,
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
}
