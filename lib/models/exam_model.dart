class ExamImage {
  final String? publicId;
  final String? url;

  const ExamImage({
    this.publicId,
    this.url,
  });

  factory ExamImage.fromJson(Map<String, dynamic> json) {
    return ExamImage(
      publicId: json['public_id']?.toString(),
      url: json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'public_id': publicId,
      'url': url,
    };
  }
}

class Exam {
  final String? id;
  final String? name;
  final ExamImage? image;
  final int? durationMinutes;
  final String? effectivitySheetContent;
  final String? bodyOfKnowledgeContent;
  final String? status;
  final int? questionCount;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Exam({
    this.id,
    this.name,
    this.image,
    this.durationMinutes,
    this.effectivitySheetContent,
    this.bodyOfKnowledgeContent,
    this.status,
    this.questionCount,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
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
      status: json['status']?.toString(),
      questionCount: _toInt(json['n_question']),
      createdBy: json['createdBy']?.toString(),
      createdAt: _toDate(json['createdAt']),
      updatedAt: _toDate(json['updatedAt']),
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
      'status': status,
      'n_question': questionCount,
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class ExamsMeta {
  final int? page;
  final int? limit;
  final int? total;
  final int? totalPages;

  const ExamsMeta({
    this.page,
    this.limit,
    this.total,
    this.totalPages,
  });

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

  const ActiveExamsData({
    this.exams = const [],
    this.meta,
  });

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

    return ActiveExamsData(
      exams: parsedExams,
      meta: parsedMeta,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exams': exams.map((exam) => exam.toJson()).toList(),
      'meta': meta?.toJson(),
    };
  }
}
