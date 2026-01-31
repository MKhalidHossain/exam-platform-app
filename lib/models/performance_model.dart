class PerformanceData {
  const PerformanceData({
    this.attempts = const [],
    this.timeline = const [],
  });

  final List<PerformanceAttempt> attempts;
  final List<PerformanceTimelineEntry> timeline;

  factory PerformanceData.fromJson(Map<String, dynamic> json) {
    final attemptsJson = json['attempts'];
    final timelineJson = json['timeline'];
    final attempts = attemptsJson is List
        ? attemptsJson
            .whereType<Map>()
            .map((item) =>
                PerformanceAttempt.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <PerformanceAttempt>[];
    final timeline = timelineJson is List
        ? timelineJson
            .whereType<Map>()
            .map((item) => PerformanceTimelineEntry.fromJson(
                Map<String, dynamic>.from(item)))
            .toList()
        : <PerformanceTimelineEntry>[];
    return PerformanceData(attempts: attempts, timeline: timeline);
  }
}

class PerformanceAttempt {
  const PerformanceAttempt({
    required this.attemptId,
    required this.examId,
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.flaggedQuestionIds = const [],
  });

  final String attemptId;
  final String examId;
  final int score;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<String> flaggedQuestionIds;

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
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

  factory PerformanceAttempt.fromJson(Map<String, dynamic> json) {
    return PerformanceAttempt(
      attemptId: json['attemptId']?.toString() ?? '',
      examId: json['examId']?.toString() ?? '',
      score: _toInt(json['score']),
      correctCount: _toInt(json['correctCount']),
      wrongCount: _toInt(json['wrongCount']),
      unansweredCount: _toInt(json['unansweredCount']),
      status: json['status']?.toString() ?? '',
      startedAt: _toDate(json['startedAt']),
      endedAt: _toDate(json['endedAt']),
      flaggedQuestionIds: _toStringList(json['flaggedQuestionIds']),
    );
  }
}

class PerformanceTimelineEntry {
  const PerformanceTimelineEntry({
    required this.attemptId,
    required this.score,
    required this.status,
    this.startedAt,
    this.endedAt,
  });

  final String attemptId;
  final int score;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;

  factory PerformanceTimelineEntry.fromJson(Map<String, dynamic> json) {
    return PerformanceTimelineEntry(
      attemptId: json['attemptId']?.toString() ?? '',
      score: PerformanceAttempt._toInt(json['score']),
      status: json['status']?.toString() ?? '',
      startedAt: PerformanceAttempt._toDate(json['startedAt']),
      endedAt: PerformanceAttempt._toDate(json['endedAt']),
    );
  }
}
