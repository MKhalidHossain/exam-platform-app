import 'dart:convert';

class StartExamData {
  final List<dynamic> questions;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final bool fromCache;
  final bool? status;
  final int? statusCode;
  final StartExamProgress? progress;

  const StartExamData({
    required this.questions,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.fromCache = false,
    this.status,
    this.statusCode,
    this.progress,
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

  static bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final lowered = value.toString().toLowerCase();
    if (lowered == 'true' || lowered == '1' || lowered == 'yes') return true;
    if (lowered == 'false' || lowered == '0' || lowered == 'no') return false;
    return null;
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
    final dynamic rawStartTime =
        json['startTime'] ?? json['start_time'] ?? json['startedAt'];
    final dynamic rawEndTime =
        json['endTime'] ?? json['end_time'] ?? json['endedAt'];
    final dynamic rawDuration = json['durationMinutes'] ??
        json['duration_minutes'] ??
        json['duration'];
    final dynamic progressJson = json['progress'];
    return StartExamData(
      questions: _parseQuestions(json['questions']),
      startTime: _toDate(rawStartTime),
      endTime: _toDate(rawEndTime),
      durationMinutes: _toInt(rawDuration),
      fromCache: json['fromCache'] == true,
      status: _toBool(json['status']),
      statusCode: _toInt(json['statusCode']),
      progress: progressJson is Map<String, dynamic>
          ? StartExamProgress.fromJson(progressJson)
          : null,
    );
  }
}

class StartExamProgress {
  final List<dynamic> answers;
  final List<int> timeSpentSec;
  final int currentIndex;
  final List<String> flaggedQuestionIds;
  final DateTime? lastSavedAt;

  const StartExamProgress({
    this.answers = const [],
    this.timeSpentSec = const [],
    this.currentIndex = 0,
    this.flaggedQuestionIds = const [],
    this.lastSavedAt,
  });

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static List<int> _toIntList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((item) => _toInt(item, fallback: -1))
          .where((item) => item >= 0)
          .toList();
    }
    final parsed = _toInt(value, fallback: -1);
    return parsed >= 0 ? <int>[parsed] : const [];
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((item) => item?.toString() ?? '')
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }
    final item = value.toString();
    return item.trim().isEmpty ? const [] : <String>[item];
  }

  factory StartExamProgress.fromJson(Map<String, dynamic> json) {
    final dynamic answersJson = json['answers'];
    return StartExamProgress(
      answers: answersJson is List ? answersJson : const [],
      timeSpentSec: _toIntList(
        json['timeSpentSec'] ?? json['timeSpent'] ?? json['time_spent'],
      ),
      currentIndex: _toInt(json['currentIndex']),
      flaggedQuestionIds: _toStringList(json['flaggedQuestionIds']),
      lastSavedAt: _toDate(json['lastSavedAt']),
    );
  }
}
