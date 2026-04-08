class UserUnlocksData {
  final List<UnlockedExam> unlockedExams;
  final int unlockedExamCount;
  final List<String> resourceUnlocks;
  final List<UnlockedResource> unlockedResources;
  final int unlockedResourceCount;

  const UserUnlocksData({
    required this.unlockedExams,
    required this.unlockedExamCount,
    required this.resourceUnlocks,
    required this.unlockedResources,
    required this.unlockedResourceCount,
  });

  factory UserUnlocksData.fromJson(Map<String, dynamic> json) {
    final rawUnlockedExams = json['unlockedExams'];
    final rawResourceUnlocks = json['resourceUnlocks'];
    final rawUnlockedResources = json['unlockedResources'];

    final unlockedExams = rawUnlockedExams is List
        ? rawUnlockedExams
              .map((item) => UnlockedExam.fromJson(_asMap(item)))
              .toList(growable: false)
        : const <UnlockedExam>[];

    final resourceUnlocks = rawResourceUnlocks is List
        ? rawResourceUnlocks
              .map((item) => _asString(item))
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    final unlockedResources = rawUnlockedResources is List
        ? rawUnlockedResources
              .map((item) => UnlockedResource.fromJson(_asMap(item)))
              .toList(growable: false)
        : const <UnlockedResource>[];

    return UserUnlocksData(
      unlockedExams: unlockedExams,
      unlockedExamCount: _asInt(
        json['unlockedExamCount'],
        fallback: unlockedExams.length,
      ),
      resourceUnlocks: resourceUnlocks,
      unlockedResources: unlockedResources,
      unlockedResourceCount: _asInt(
        json['unlockedResourceCount'],
        fallback: unlockedResources.length,
      ),
    );
  }
}

class UnlockedExam {
  final String examId;
  final String examName;
  final String purchaseType;
  final String paymentStatus;
  final DateTime? unlockDate;
  final DateTime? purchasedAt;
  final DateTime? expiresAt;
  final int expiryMonths;
  final bool isExpired;

  const UnlockedExam({
    required this.examId,
    required this.examName,
    required this.purchaseType,
    required this.paymentStatus,
    required this.unlockDate,
    required this.purchasedAt,
    required this.expiresAt,
    required this.expiryMonths,
    required this.isExpired,
  });

  factory UnlockedExam.fromJson(Map<String, dynamic> json) {
    return UnlockedExam(
      examId: _asString(json['examId']),
      examName: _asString(json['examName']),
      purchaseType: _asString(json['purchaseType']),
      paymentStatus: _asString(json['paymentStatus']),
      unlockDate: _asDateTime(json['unlockDate']),
      purchasedAt: _asDateTime(json['purchasedAt']),
      expiresAt: _asDateTime(json['expiresAt']),
      expiryMonths: _asInt(json['expiryMonths']),
      isExpired: _asBool(json['isExpired']),
    );
  }
}

class UnlockedResource {
  final String productId;
  final String productCode;
  final String title;
  final String categoryId;
  final String categoryTitle;
  final bool isBundle;
  final bool isManual;
  final String unlockMode;
  final String sourceLabel;
  final String purchaseType;
  final String provider;
  final String status;
  final DateTime? purchasedAt;
  final String sourceProductCode;
  final String sourceProductTitle;
  final bool inheritedFromBundle;

  const UnlockedResource({
    required this.productId,
    required this.productCode,
    required this.title,
    required this.categoryId,
    required this.categoryTitle,
    required this.isBundle,
    required this.isManual,
    required this.unlockMode,
    required this.sourceLabel,
    required this.purchaseType,
    required this.provider,
    required this.status,
    required this.purchasedAt,
    required this.sourceProductCode,
    required this.sourceProductTitle,
    required this.inheritedFromBundle,
  });

  factory UnlockedResource.fromJson(Map<String, dynamic> json) {
    return UnlockedResource(
      productId: _asString(json['productId']),
      productCode: _asString(json['productCode']),
      title: _asString(json['title']),
      categoryId: _asString(json['categoryId']),
      categoryTitle: _asString(json['categoryTitle']),
      isBundle: _asBool(json['isBundle']),
      isManual: _asBool(json['isManual']),
      unlockMode: _asString(json['unlockMode']),
      sourceLabel: _asString(json['sourceLabel']),
      purchaseType: _asString(json['purchaseType']),
      provider: _asString(json['provider']),
      status: _asString(json['status']),
      purchasedAt: _asDateTime(json['purchasedAt']),
      sourceProductCode: _asString(json['sourceProductCode']),
      sourceProductTitle: _asString(json['sourceProductTitle']),
      inheritedFromBundle: _asBool(json['inheritedFromBundle']),
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

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
