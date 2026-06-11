class ExamModel {
  final String id;
  final String name;
  final String? imageUrl;
  final int? questionCount;
  final String? effectivitySheetContent;
  final String? bodyOfKnowledgeContent;
  final String? code;
  final bool? unlocked;
  final double? unlockPrice;
  final String? currency;

  const ExamModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.questionCount,
    this.effectivitySheetContent,
    this.bodyOfKnowledgeContent,
    this.code,
    this.unlocked,
    this.unlockPrice,
    this.currency,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    final image = json['image'];
    String? url;
    if (image is Map) {
      url = image['url'] as String?;
    }
    return ExamModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      imageUrl: url,
      questionCount: Exam._toInt(json['n_question']),
      effectivitySheetContent: json['effectivitySheetContent']?.toString(),
      bodyOfKnowledgeContent: json['bodyOfKnowledgeContent']?.toString(),
      code:
          json['code']?.toString() ??
          json['examCode']?.toString() ??
          json['slug']?.toString(),
      unlocked: Exam._toBool(json['unlocked']),
      unlockPrice: Exam._toDouble(json['unlockPrice'] ?? json['unlock_price']),
      currency: json['currency']?.toString(),
    );
  }
}

class ExamImage {
  final String? publicId;
  final String? url;

  const ExamImage({this.publicId, this.url});

  factory ExamImage.fromJson(Map<String, dynamic> json) {
    return ExamImage(
      publicId: json['public_id']?.toString(),
      url: json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'public_id': publicId, 'url': url};
  }
}

class Exam {
  final String? id;
  final String? name;
  final ExamImage? image;
  final int? durationMinutes;
  final String? effectivitySheetContent;
  final String? bodyOfKnowledgeContent;
  final String? code;
  final String? status;
  final int? questionCount;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? unlocked;
  final double? unlockPrice;
  final String? currency;

  const Exam({
    this.id,
    this.name,
    this.image,
    this.durationMinutes,
    this.effectivitySheetContent,
    this.bodyOfKnowledgeContent,
    this.code,
    this.status,
    this.questionCount,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.unlocked,
    this.unlockPrice,
    this.currency,
  });

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final lowered = value.toString().toLowerCase();
    if (lowered == 'true' || lowered == '1' || lowered == 'yes') return true;
    if (lowered == 'false' || lowered == '0' || lowered == 'no') return false;
    return null;
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['_id']?.toString(),
      name: json['name']?.toString(),
      image: json['image'] is Map<String, dynamic>
          ? ExamImage.fromJson(json['image'] as Map<String, dynamic>)
          : null,
      durationMinutes: _toInt(json['durationMinutes']),
      effectivitySheetContent: json['effectivitySheetContent']?.toString(),
      bodyOfKnowledgeContent: json['bodyOfKnowledgeContent']?.toString(),
      code:
          json['code']?.toString() ??
          json['examCode']?.toString() ??
          json['slug']?.toString(),
      status: json['status']?.toString(),
      questionCount: _toInt(json['n_question']),
      createdBy: json['createdBy']?.toString(),
      createdAt: _toDate(json['createdAt']),
      updatedAt: _toDate(json['updatedAt']),
      unlocked: _toBool(json['unlocked']),
      unlockPrice: _toDouble(json['unlockPrice'] ?? json['unlock_price']),
      currency: json['currency']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'image': image?.toJson(),
      'durationMinutes': durationMinutes,
      'effectivitySheetContent': effectivitySheetContent,
      'bodyOfKnowledgeContent': bodyOfKnowledgeContent,
      'code': code,
      'status': status,
      'n_question': questionCount,
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'unlocked': unlocked,
      'unlockPrice': unlockPrice,
      'currency': currency,
    };
  }
}

class ExamsMeta {
  final int? page;
  final int? limit;
  final int? total;
  final int? totalPages;

  const ExamsMeta({this.page, this.limit, this.total, this.totalPages});

  factory ExamsMeta.fromJson(Map<String, dynamic> json) {
    return ExamsMeta(
      page: Exam._toInt(json['page']),
      limit: Exam._toInt(json['limit']),
      total: Exam._toInt(json['total']),
      totalPages: Exam._toInt(json['totalPages']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'totalPages': totalPages,
    };
  }
}

class ActiveExamsData {
  final List<Exam> exams;
  final ExamsMeta? meta;

  const ActiveExamsData({this.exams = const [], this.meta});

  factory ActiveExamsData.fromJson(Map<String, dynamic> json) {
    final examsJson = json['exams'];
    List<Exam> parsedExams = [];
    if (examsJson is List) {
      parsedExams = examsJson
          .whereType<Map<String, dynamic>>()
          .map(Exam.fromJson)
          .toList();
    }

    final metaJson = json['meta'];
    ExamsMeta? parsedMeta;
    if (metaJson is Map<String, dynamic>) {
      parsedMeta = ExamsMeta.fromJson(metaJson);
    }

    return ActiveExamsData(exams: parsedExams, meta: parsedMeta);
  }

  Map<String, dynamic> toJson() {
    return {
      'exams': exams.map((exam) => exam.toJson()).toList(),
      'meta': meta?.toJson(),
    };
  }
}
