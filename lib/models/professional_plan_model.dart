/// Response: { "success": true, "message": "...", "data": { "plan": { ... } } }
class ProfessionalPlanModel {
  final String id;
  final String name;
  final num price;
  final String currency;
  final PlanInterval interval;
  final String? description;
  final List<String> features;

  const ProfessionalPlanModel({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.interval,
    this.description,
    this.features = const [],
  });

  factory ProfessionalPlanModel.fromJson(Map<String, dynamic> json) {
    return ProfessionalPlanModel(
      id: json['id'] as String? ?? 'professional',
      name: json['name'] as String? ?? 'Professional Plan',
      price: (json['price'] as num?) ?? 180,
      currency: json['currency'] as String? ?? 'USD',
      interval: json['interval'] != null
          ? PlanInterval.fromJson(json['interval'] as Map<String, dynamic>)
          : const PlanInterval(count: 3, unit: 'months', label: '3 months'),
      description: json['description'] as String?,
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  String get priceFormatted {
    if (currency == 'USD') return '\$${price.toStringAsFixed(2)}';
    return '$currency ${price.toStringAsFixed(2)}';
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
    return PlanInterval(
      count: json['count'] as int? ?? 3,
      unit: json['unit'] as String? ?? 'months',
      label: json['label'] as String? ?? '3 months',
    );
  }
}
