class Announcement {
  final String id;
  final String message;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Announcement({
    required this.id,
    required this.message,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString(),
      createdAt: _toDate(json['createdAt']),
      updatedAt: _toDate(json['updatedAt']),
    );
  }
}

class AnnouncementsMeta {
  final int? page;
  final int? limit;
  final int? total;
  final int? totalPages;

  const AnnouncementsMeta({
    this.page,
    this.limit,
    this.total,
    this.totalPages,
  });

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory AnnouncementsMeta.fromJson(Map<String, dynamic> json) {
    return AnnouncementsMeta(
      page: _toInt(json['page']),
      limit: _toInt(json['limit']),
      total: _toInt(json['total']),
      totalPages: _toInt(json['totalPages']),
    );
  }
}

class AnnouncementsData {
  final List<Announcement> announcements;
  final AnnouncementsMeta? meta;

  const AnnouncementsData({
    this.announcements = const [],
    this.meta,
  });

  factory AnnouncementsData.fromJson(Map<String, dynamic> json) {
    final items = json['announcements'];
    List<Announcement> parsed = [];
    if (items is List) {
      parsed = items
          .whereType<Map<String, dynamic>>()
          .map(Announcement.fromJson)
          .toList();
    }

    final metaJson = json['meta'];
    AnnouncementsMeta? parsedMeta;
    if (metaJson is Map<String, dynamic>) {
      parsedMeta = AnnouncementsMeta.fromJson(metaJson);
    }

    return AnnouncementsData(
      announcements: parsed,
      meta: parsedMeta,
    );
  }
}
