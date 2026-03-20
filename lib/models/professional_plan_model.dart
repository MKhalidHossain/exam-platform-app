/// Response: {
///   "success": true,
///   "message": "...",
///   "data": { "plan": { ... }, "subscription": { ... } }
/// }
import 'referral_model.dart';

class ProfessionalPlanModel {
  final String id;
  final String name;
  final num price;
  final String currency;
  final num unlockExamPrice;
  final PlanInterval interval;
  final String? description;
  final List<String> features;
  final bool referralEligible;
  final ReferralPublicCode? referralOffer;
  final List<PlanAddOnOption> prePurchaseAddOnOptions;
  final PlanSubscription? subscription;

  const ProfessionalPlanModel({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.unlockExamPrice,
    required this.interval,
    this.description,
    this.features = const [],
    this.referralEligible = false,
    this.referralOffer,
    this.prePurchaseAddOnOptions = const [],
    this.subscription,
  });

  factory ProfessionalPlanModel.fromJson(Map<String, dynamic> json) {
    final dynamic planRaw = json['plan'];
    final Map<String, dynamic> planJson = planRaw is Map<String, dynamic>
        ? planRaw
        : (planRaw is Map ? Map<String, dynamic>.from(planRaw) : json);

    final dynamic subscriptionRaw = json['subscription'];
    Map<String, dynamic>? subscriptionJson =
        subscriptionRaw is Map<String, dynamic>
        ? subscriptionRaw
        : (subscriptionRaw is Map
              ? Map<String, dynamic>.from(subscriptionRaw)
              : null);

    if (subscriptionJson == null &&
        (json['subscriptionExpiresAt'] != null ||
            json['nextBillingDate'] != null ||
            json['billingCycle'] != null ||
            json['status'] != null ||
            json['isActive'] != null ||
            json['tier'] != null)) {
      subscriptionJson = <String, dynamic>{
        'subscriptionExpiresAt': json['subscriptionExpiresAt'],
        'nextBillingDate': json['nextBillingDate'],
        'billingCycle': json['billingCycle'],
        'status': json['status'],
        'isActive': json['isActive'],
        'tier': json['tier'],
        'startedAt': json['startedAt'],
      };
    }

    final rawAddOnOptions = json['prePurchaseAddOnOptions'];
    final addOnOptions = rawAddOnOptions is List
        ? rawAddOnOptions
              .map((e) => PlanAddOnOption.fromJson(_asMap(e)))
              .toList(growable: false)
        : const <PlanAddOnOption>[];
    final referralOfferRaw = planJson['referralOffer'];
    final ReferralPublicCode? referralOffer =
        referralOfferRaw is Map<String, dynamic>
        ? ReferralPublicCode.fromJson(referralOfferRaw)
        : (referralOfferRaw is Map
              ? ReferralPublicCode.fromJson(
                  Map<String, dynamic>.from(referralOfferRaw),
                )
              : null);

    return ProfessionalPlanModel(
      id: planJson['id'] as String? ?? 'professional',
      name: planJson['name'] as String? ?? 'Professional Plan',
      price: _parseNum(planJson['price']) ?? 180,
      currency: planJson['currency'] as String? ?? 'USD',
      unlockExamPrice: _parseNum(planJson['unlockExamPrice']) ?? 150,
      interval: planJson['interval'] != null
          ? PlanInterval.fromJson(
              planJson['interval'] is Map<String, dynamic>
                  ? planJson['interval'] as Map<String, dynamic>
                  : Map<String, dynamic>.from(planJson['interval'] as Map),
            )
          : const PlanInterval(count: 3, unit: 'months', label: '3 months'),
      description: planJson['description'] as String?,
      features:
          (planJson['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      referralEligible:
          _parseBool(planJson['referralEligible']) ||
          (referralOffer?.discountPercent ?? 0) > 0,
      referralOffer: referralOffer,
      prePurchaseAddOnOptions: addOnOptions,
      subscription: subscriptionJson != null
          ? PlanSubscription.fromJson(subscriptionJson)
          : null,
    );
  }

  String get priceFormatted => _formatMoney(price, currency);

  String get unlockExamPriceFormatted =>
      _formatMoney(unlockExamPrice, currency);

  static num? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static String _formatMoney(num amount, String currency) {
    if (currency.toUpperCase() == 'USD') {
      return '\$${amount.toStringAsFixed(2)}';
    }
    return '${currency.toUpperCase()} ${amount.toStringAsFixed(2)}';
  }
}

class PlanAddOnOption {
  final String id;
  final String code;
  final String title;
  final num basePrice;
  final num regularPrice;
  final num upgradeDiscountPrice;
  final String currency;
  final bool isBundle;
  final String coverImageUrl;

  const PlanAddOnOption({
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

  factory PlanAddOnOption.fromJson(Map<String, dynamic> json) {
    return PlanAddOnOption(
      id: (json['id'] ?? json['_id'] ?? json['productId'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      basePrice: ProfessionalPlanModel._parseNum(json['basePrice']) ?? 0,
      regularPrice: ProfessionalPlanModel._parseNum(json['regularPrice']) ?? 0,
      upgradeDiscountPrice:
          ProfessionalPlanModel._parseNum(json['upgradeDiscountPrice']) ?? 0,
      currency: (json['currency'] ?? 'USD').toString(),
      isBundle: json['isBundle'] == true,
      coverImageUrl: (json['coverImageUrl'] ?? '').toString(),
    );
  }

  String formatMoney(num amount) {
    if (currency.toUpperCase() == 'USD') {
      return '\$${amount.toStringAsFixed(2)}';
    }
    return '${currency.toUpperCase()} ${amount.toStringAsFixed(2)}';
  }

  String get basePriceFormatted => formatMoney(basePrice);
  String get regularPriceFormatted => formatMoney(regularPrice);
  String get upgradeDiscountPriceFormatted => formatMoney(upgradeDiscountPrice);
  String get selectionValue {
    final normalizedId = id.trim();
    if (normalizedId.isNotEmpty) return normalizedId;
    return code.trim();
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

class PlanInterval {
  final int count;
  final String unit;
  final String label;

  const PlanInterval({
    required this.count,
    required this.unit,
    required this.label,
  });

  factory PlanInterval.fromJson(Map<String, dynamic> json) {
    int parseCount(dynamic value, {int fallback = 3}) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? fallback;
    }

    final count = parseCount(json['count']);
    final unit = (json['unit'] as String? ?? 'months').trim();
    final label = json['label'] as String? ?? '$count $unit';

    return PlanInterval(count: count, unit: unit, label: label);
  }
}

class PlanSubscription {
  final String tier;
  final bool isActive;
  final String status;
  final DateTime? startedAt;
  final DateTime? nextBillingDate;
  final PlanInterval? billingCycle;

  const PlanSubscription({
    required this.tier,
    required this.isActive,
    required this.status,
    this.startedAt,
    this.nextBillingDate,
    this.billingCycle,
  });

  factory PlanSubscription.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final String tier = (json['tier'] as String? ?? 'starter').toLowerCase();
    final String status = (json['status'] as String? ?? 'inactive')
        .toLowerCase();
    final bool activeFromStatus = status == 'active';
    final bool activeFromTier = tier == 'professional';
    final bool isActive =
        ((json['isActive'] as bool?) ??
            (json['active'] as bool?) ??
            activeFromStatus) ||
        activeFromTier;

    final dynamic billingRaw = json['billingCycle'];
    final Map<String, dynamic>? billingJson = billingRaw is Map<String, dynamic>
        ? billingRaw
        : (billingRaw is Map ? Map<String, dynamic>.from(billingRaw) : null);

    return PlanSubscription(
      tier: tier,
      isActive: isActive,
      status: status,
      startedAt: parseDate(json['startedAt']),
      nextBillingDate:
          parseDate(json['subscriptionExpiresAt']) ??
          parseDate(json['nextBillingDate']),
      billingCycle: billingJson != null
          ? PlanInterval.fromJson(billingJson)
          : null,
    );
  }
}
