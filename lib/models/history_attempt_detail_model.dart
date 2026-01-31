class HistoryAttemptDetail {
  const HistoryAttemptDetail({
    required this.attemptId,
    this.exam,
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.flaggedQuestionIds = const [],
    this.review,
    this.createdAt,
    this.updatedAt,
  });

  final String attemptId;
  final AttemptExam? exam;
  final int score;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<String> flaggedQuestionIds;
  final AttemptReview? review;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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

  factory HistoryAttemptDetail.fromJson(Map<String, dynamic> json) {
    final examJson = json['exam'];
    final reviewJson = json['review'];
    return HistoryAttemptDetail(
      attemptId: json['attemptId']?.toString() ?? '',
      exam: examJson is Map<String, dynamic>
          ? AttemptExam.fromJson(examJson)
          : null,
      score: _toInt(json['score']),
      correctCount: _toInt(json['correctCount']),
      wrongCount: _toInt(json['wrongCount']),
      unansweredCount: _toInt(json['unansweredCount']),
      status: json['status']?.toString() ?? '',
      startedAt: _toDate(json['startedAt']),
      endedAt: _toDate(json['endedAt']),
      flaggedQuestionIds: _toStringList(json['flaggedQuestionIds']),
      review: reviewJson is Map<String, dynamic>
          ? AttemptReview.fromJson(reviewJson)
          : null,
      createdAt: _toDate(json['createdAt']),
      updatedAt: _toDate(json['updatedAt']),
    );
  }
}

class AttemptExam {
  const AttemptExam({
    required this.examId,
    required this.name,
    required this.durationMinutes,
  });

  final String examId;
  final String name;
  final int durationMinutes;

  factory AttemptExam.fromJson(Map<String, dynamic> json) {
    return AttemptExam(
      examId: json['examId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      durationMinutes: HistoryAttemptDetail._toInt(json['durationMinutes']),
    );
  }
}

class AttemptReview {
  const AttemptReview({
    this.topicBreakdown = const [],
    this.answers = const [],
  });

  final List<AttemptTopicBreakdown> topicBreakdown;
  final List<AttemptReviewAnswer> answers;

  factory AttemptReview.fromJson(Map<String, dynamic> json) {
    final topicsJson = json['topicBreakdown'];
    final answersJson = json['answers'];
    final topics = topicsJson is List
        ? topicsJson
            .whereType<Map>()
            .map((item) =>
                AttemptTopicBreakdown.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <AttemptTopicBreakdown>[];
    final answers = answersJson is List
        ? answersJson
            .whereType<Map>()
            .map((item) =>
                AttemptReviewAnswer.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <AttemptReviewAnswer>[];
    return AttemptReview(topicBreakdown: topics, answers: answers);
  }
}

class AttemptTopicBreakdown {
  const AttemptTopicBreakdown({
    required this.category,
    required this.correct,
    required this.incorrect,
    required this.accuracy,
  });

  final String category;
  final int correct;
  final int incorrect;
  final int accuracy;

  factory AttemptTopicBreakdown.fromJson(Map<String, dynamic> json) {
    return AttemptTopicBreakdown(
      category: json['category']?.toString() ?? '',
      correct: HistoryAttemptDetail._toInt(json['correct']),
      incorrect: HistoryAttemptDetail._toInt(json['incorrect']),
      accuracy: HistoryAttemptDetail._toInt(json['accuracy']),
    );
  }
}

class AttemptReviewAnswer {
  const AttemptReviewAnswer({
    required this.questionId,
    this.userAnswer = const [],
    this.correctAnswer = const [],
    required this.isCorrect,
    required this.timeSpentSec,
  });

  final String questionId;
  final List<String> userAnswer;
  final List<String> correctAnswer;
  final bool isCorrect;
  final int timeSpentSec;

  factory AttemptReviewAnswer.fromJson(Map<String, dynamic> json) {
    return AttemptReviewAnswer(
      questionId: json['questionId']?.toString() ?? '',
      userAnswer: HistoryAttemptDetail._toStringList(json['userAnswer']),
      correctAnswer: HistoryAttemptDetail._toStringList(json['correctAnswer']),
      isCorrect: json['isCorrect'] == true,
      timeSpentSec: HistoryAttemptDetail._toInt(json['timeSpentSec']),
    );
  }
}
