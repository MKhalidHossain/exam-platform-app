class HistoryAttempt {
  const HistoryAttempt({
    required this.attemptId,
    required this.examId,
    required this.examName,
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.status,
    this.startedAt,
    this.endedAt,
  });

  final String attemptId;
  final String examId;
  final String examName;
  final int score;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;

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

  factory HistoryAttempt.fromJson(Map<String, dynamic> json) {
    return HistoryAttempt(
      attemptId: json['attemptId']?.toString() ?? '',
      examId: json['examId']?.toString() ?? '',
      examName: json['examName']?.toString() ?? 'Exam',
      score: _toInt(json['score']),
      correctCount: _toInt(json['correctCount']),
      wrongCount: _toInt(json['wrongCount']),
      unansweredCount: _toInt(json['unansweredCount']),
      status: json['status']?.toString() ?? '',
      startedAt: _toDate(json['startedAt']),
      endedAt: _toDate(json['endedAt']),
    );
  }
}

class AttemptsMeta {
  const AttemptsMeta({
    this.page,
    this.limit,
    this.total,
    this.totalPages,
  });

  final int? page;
  final int? limit;
  final int? total;
  final int? totalPages;

  factory AttemptsMeta.fromJson(Map<String, dynamic> json) {
    return AttemptsMeta(
      page: HistoryAttempt._toInt(json['page']),
      limit: HistoryAttempt._toInt(json['limit']),
      total: HistoryAttempt._toInt(json['total']),
      totalPages: HistoryAttempt._toInt(json['totalPages']),
    );
  }
}

class HistoryAttemptsData {
  const HistoryAttemptsData({
    this.attempts = const [],
    this.meta,
  });

  final List<HistoryAttempt> attempts;
  final AttemptsMeta? meta;

  factory HistoryAttemptsData.fromJson(Map<String, dynamic> json) {
    final attemptsJson = json['attempts'];
    final attempts = attemptsJson is List
        ? attemptsJson
            .whereType<Map>()
            .map((e) => HistoryAttempt.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <HistoryAttempt>[];

    final metaJson = json['meta'];
    final AttemptsMeta? meta =
        metaJson is Map<String, dynamic> ? AttemptsMeta.fromJson(metaJson) : null;

    return HistoryAttemptsData(
      attempts: attempts,
      meta: meta,
    );
  }
}
