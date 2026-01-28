class HistoryEntry {
  const HistoryEntry({
    required this.examName,
    required this.date,
    required this.scorePercent,
    required this.scoreDetail,
  });

  final String examName;
  final String date;
  final double scorePercent;
  final String scoreDetail;
}

class TopicBreakdown {
  const TopicBreakdown({
    required this.category,
    required this.correct,
    required this.incorrect,
    required this.accuracy,
  });

  final String category;
  final int correct;
  final int incorrect;
  final int accuracy;
}
