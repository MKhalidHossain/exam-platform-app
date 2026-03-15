class EbookStoreData {
  final List<EbookCategory> categories;
  final EbookUserAccess userAccess;

  const EbookStoreData({required this.categories, required this.userAccess});

  factory EbookStoreData.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final categories = rawCategories is List
        ? rawCategories
              .map((e) => EbookCategory.fromJson(_asMap(e)))
              .toList(growable: false)
        : const <EbookCategory>[];

    return EbookStoreData(
      categories: categories,
      userAccess: EbookUserAccess.fromJson(_asMap(json['userAccess'])),
    );
  }

  factory EbookStoreData.fromUpgradeAddOnOptions(
    List<EbookUpgradeAddOnOption> options,
    EbookUserAccess userAccess,
  ) {
    final products = options
        .asMap()
        .entries
        .map(
          (entry) => entry.value.toProduct(
            categoryId: 'upgrade_add_ons',
            sortOrder: entry.key,
            userAccess: userAccess,
          ),
        )
        .toList(growable: false);

    return EbookStoreData(
      categories: [
        EbookCategory(
          id: 'upgrade_add_ons',
          title: 'Ebook Store',
          slug: 'ebook-store',
          shortCode: 'EBOOKS',
          description: 'Available ebook add-ons and guides',
          sortOrder: 0,
          products: products,
        ),
      ],
      userAccess: userAccess,
    );
  }
}

class EbookUpgradeAddOnOption {
  final String id;
  final String code;
  final String title;
  final double basePrice;
  final double regularPrice;
  final double upgradeDiscountPrice;
  final String currency;
  final bool isBundle;
  final String coverImageUrl;

  const EbookUpgradeAddOnOption({
    required this.id,
    required this.code,
    required this.title,
    required this.basePrice,
    required this.regularPrice,
    required this.upgradeDiscountPrice,
    required this.currency,
    required this.isBundle,
    required this.coverImageUrl,
  });

  factory EbookUpgradeAddOnOption.fromJson(Map<String, dynamic> json) {
    return EbookUpgradeAddOnOption(
      id: _asString(json['id']),
      code: _asString(json['code']),
      title: _asString(json['title']),
      basePrice: _asDouble(json['basePrice']),
      regularPrice: _asDouble(json['regularPrice']),
      upgradeDiscountPrice: _asDouble(json['upgradeDiscountPrice']),
      currency: _asString(json['currency'], fallback: 'USD'),
      isBundle: _asBool(json['isBundle']),
      coverImageUrl: _asString(json['coverImageUrl']),
    );
  }

  EbookProduct toProduct({
    required String categoryId,
    required int sortOrder,
    required EbookUserAccess userAccess,
  }) {
    final currentPrice = regularPrice > 0 ? regularPrice : basePrice;
    final originalPrice = basePrice > currentPrice ? basePrice : currentPrice;
    final unlocked = userAccess.isUnlockedForCode(code);

    return EbookProduct(
      id: id,
      categoryId: categoryId,
      code: code,
      title: title,
      shortDescription: isBundle
          ? 'Bundle add-on from the upgrade catalog'
          : 'Guide from the upgrade catalog',
      fullDescription: '',
      coverImageUrl: coverImageUrl,
      contentUrl: '',
      previewAvailable: false,
      previewTitle: '',
      previewContent: '',
      previewUrl: '',
      pricing: EbookPricing(
        current: currentPrice,
        original: originalPrice,
        upgradeDiscount: upgradeDiscountPrice,
        currency: currency,
      ),
      isBundle: isBundle,
      bundleIncludes: const [],
      locked: !unlocked,
      unlocked: unlocked,
      purchaseState: unlocked ? 'purchased' : 'locked',
      sortOrder: sortOrder,
    );
  }
}

class EbookCategory {
  final String id;
  final String title;
  final String slug;
  final String shortCode;
  final String description;
  final int sortOrder;
  final List<EbookProduct> products;

  const EbookCategory({
    required this.id,
    required this.title,
    required this.slug,
    required this.shortCode,
    required this.description,
    required this.sortOrder,
    required this.products,
  });

  factory EbookCategory.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    final products = rawProducts is List
        ? rawProducts
              .map((e) => EbookProduct.fromJson(_asMap(e)))
              .toList(growable: false)
        : const <EbookProduct>[];

    return EbookCategory(
      id: _asString(json['id']),
      title: _asString(json['title']),
      slug: _asString(json['slug']),
      shortCode: _asString(json['shortCode']),
      description: _asString(json['description']),
      sortOrder: _asInt(json['sortOrder']),
      products: products,
    );
  }
}

class EbookProduct {
  final String id;
  final String categoryId;
  final String code;
  final String title;
  final String shortDescription;
  final String fullDescription;
  final String coverImageUrl;
  final String contentUrl;
  final bool previewAvailable;
  final String previewTitle;
  final String previewContent;
  final String previewUrl;
  final EbookPricing pricing;
  final bool isBundle;
  final List<String> bundleIncludes;
  final bool locked;
  final bool unlocked;
  final String purchaseState;
  final int sortOrder;

  const EbookProduct({
    required this.id,
    required this.categoryId,
    required this.code,
    required this.title,
    required this.shortDescription,
    required this.fullDescription,
    required this.coverImageUrl,
    required this.contentUrl,
    required this.previewAvailable,
    required this.previewTitle,
    required this.previewContent,
    required this.previewUrl,
    required this.pricing,
    required this.isBundle,
    required this.bundleIncludes,
    required this.locked,
    required this.unlocked,
    required this.purchaseState,
    required this.sortOrder,
  });

  factory EbookProduct.fromJson(Map<String, dynamic> json) {
    final rawBundleIncludes = json['bundleIncludes'];
    final bundleIncludes = rawBundleIncludes is List
        ? rawBundleIncludes.map((e) => _asString(e)).toList(growable: false)
        : const <String>[];

    return EbookProduct(
      id: _asString(json['id']),
      categoryId: _asString(json['categoryId']),
      code: _asString(json['code']),
      title: _asString(json['title']),
      shortDescription: _asString(json['shortDescription']),
      fullDescription: _asString(json['fullDescription']),
      coverImageUrl: _asString(json['coverImageUrl']),
      contentUrl: _asString(json['contentUrl']),
      previewAvailable: _asBool(json['previewAvailable']),
      previewTitle: _asString(json['previewTitle']),
      previewContent: _asString(json['previewContent']),
      previewUrl: _asString(json['previewUrl']),
      pricing: EbookPricing.fromJson(_asMap(json['pricing'])),
      isBundle: _asBool(json['isBundle']),
      bundleIncludes: bundleIncludes,
      locked: _asBool(json['locked']),
      unlocked: _asBool(json['unlocked']),
      purchaseState: _asString(json['purchaseState']),
      sortOrder: _asInt(json['sortOrder']),
    );
  }
}

class EbookPricing {
  final double current;
  final double original;
  final double upgradeDiscount;
  final String currency;

  const EbookPricing({
    required this.current,
    required this.original,
    required this.upgradeDiscount,
    required this.currency,
  });

  factory EbookPricing.fromJson(Map<String, dynamic> json) {
    return EbookPricing(
      current: _asDouble(json['current']),
      original: _asDouble(json['original']),
      upgradeDiscount: _asDouble(json['upgradeDiscount']),
      currency: _asString(json['currency'], fallback: 'USD'),
    );
  }
}

class EbookUserAccess {
  final bool hasApi510InspectionGuide;
  final bool hasApi510ReportGuide;
  final bool hasApi510Bundle;
  final List<String> resourceUnlocks;

  const EbookUserAccess({
    required this.hasApi510InspectionGuide,
    required this.hasApi510ReportGuide,
    required this.hasApi510Bundle,
    required this.resourceUnlocks,
  });

  factory EbookUserAccess.fromJson(Map<String, dynamic> json) {
    final rawUnlocks = json['resourceUnlocks'];
    final unlocks = rawUnlocks is List
        ? rawUnlocks.map((e) => _asString(e)).toList(growable: false)
        : const <String>[];

    return EbookUserAccess(
      hasApi510InspectionGuide: _asBool(json['has_api510_inspection_guide']),
      hasApi510ReportGuide: _asBool(json['has_api510_report_guide']),
      hasApi510Bundle: _asBool(json['has_api510_bundle']),
      resourceUnlocks: unlocks,
    );
  }

  bool isUnlockedForCode(String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    if (resourceUnlocks
        .map((e) => e.trim().toLowerCase())
        .contains(normalized)) {
      return true;
    }

    switch (normalized) {
      case 'api510_inspection_guide':
      case 'api510':
        return hasApi510InspectionGuide || hasApi510Bundle;
      case 'api510_report_guide':
        return hasApi510ReportGuide || hasApi510Bundle;
      case 'api510_bundle':
        return hasApi510Bundle;
      default:
        return false;
    }
  }
}

class EbookPurchasedContent {
  final String id;
  final String code;
  final String title;
  final String contentUrl;
  final bool unlocked;

  const EbookPurchasedContent({
    required this.id,
    required this.code,
    required this.title,
    required this.contentUrl,
    required this.unlocked,
  });

  factory EbookPurchasedContent.fromJson(Map<String, dynamic> json) {
    return EbookPurchasedContent(
      id: _asString(json['id']),
      code: _asString(json['code']),
      title: _asString(json['title']),
      contentUrl: _asString(json['contentUrl']),
      unlocked: _asBool(json['unlocked']),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}
