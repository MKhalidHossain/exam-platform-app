/// Response: {
///   "success": true,
///   "message": "...",
///   "data": { "plan": { ... }, "subscription": { ... } }
/// }
class ProfessionalPlanModel {
  final String id;
  final String name;
  final num price;
  final String currency;
  final num unlockExamPrice;
  final PlanInterval interval;
  final String? description;
  final List<String> features;
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

  static String _formatMoney(num amount, String currency) {
    if (currency.toUpperCase() == 'USD') {
      return '\$${amount.toStringAsFixed(2)}';
    }
    return '${currency.toUpperCase()} ${amount.toStringAsFixed(2)}';
  }
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
