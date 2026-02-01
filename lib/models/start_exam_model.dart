import 'dart:convert';

class StartExamData {
  final List<dynamic> questions;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final bool fromCache;
  final String? status;
  final int? statusCode;

  const StartExamData({
    required this.questions,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.fromCache = false,
    this.status,
    this.statusCode,
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

  static List<dynamic> _parseQuestions(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      } catch (_) {}
      return [];
    }
    if (raw is Map && raw['questions'] is List) {
      return raw['questions'] as List;
    }
    return [];
  }

  factory StartExamData.fromJson(Map<String, dynamic> json) {
    return StartExamData(
      questions: _parseQuestions(json['questions']),
      startTime: _toDate(json['startTime']),
      endTime: _toDate(json['endTime']),
      durationMinutes: _toInt(json['durationMinutes']),
      fromCache: json['fromCache'] == true,
      status: json['status']?.toString(),
      statusCode: _toInt(json['statusCode']),
    );
  }
}
