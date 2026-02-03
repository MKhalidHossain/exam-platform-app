import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import 'history_models.dart';
import 'history_list_screen.dart';
import '../../controllers/history_controller.dart';
import '../../controllers/performance_controller.dart';
import '../../models/history_attempt_model.dart';
import '../../models/performance_model.dart';

class PerformanceArgs {
  const PerformanceArgs({
    required this.entry,
    required this.history,
  });

  final HistoryEntry entry;
  final List<HistoryEntry> history;
}

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({
    super.key,
    required this.entry,
    required this.history,
    this.isProfileFlow = false,
  });

  final HistoryEntry entry;
  final List<HistoryEntry> history;
  final bool isProfileFlow;

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  static const String _profileHistoryTag = 'profileHistory';
  late final PerformanceController _controller;
  HistoryController? _historyController;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<PerformanceController>()
        ? Get.find<PerformanceController>()
        : Get.put(PerformanceController());
    if (widget.isProfileFlow) {
      _historyController =
          Get.isRegistered<HistoryController>(tag: _profileHistoryTag)
              ? Get.find<HistoryController>(tag: _profileHistoryTag)
              : Get.put(HistoryController(), tag: _profileHistoryTag);
      _controller.fetchOverview();
      _historyController?.fetchAttempts(limit: 4);
    } else {
      final examId = widget.entry.examId;
      if (examId != null && examId.trim().isNotEmpty) {
        _controller.fetchPerformance(examId);
      }
    }
  }

  String _formatAttemptDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year}, '
        '$hour:$minute:$second $ampm';
  }

  HistoryEntry _mapAttemptToEntry(
    PerformanceAttempt attempt,
    String examName,
  ) {
    final total =
        attempt.correctCount + attempt.wrongCount + attempt.unansweredCount;
    final scoreDetail = total > 0
        ? '${attempt.correctCount}/$total'
        : '${attempt.correctCount}/0';
    final date = attempt.endedAt ?? attempt.startedAt;
    return HistoryEntry(
      examName: examName,
      date: _formatAttemptDate(date),
      scorePercent: attempt.score.toDouble(),
      scoreDetail: scoreDetail,
      attemptId: attempt.attemptId,
      examId: attempt.examId,
    );
  }

  HistoryEntry _mapHistoryAttemptToEntry(HistoryAttempt attempt) {
    final total =
        attempt.correctCount + attempt.wrongCount + attempt.unansweredCount;
    final scoreDetail = total > 0
        ? '${attempt.correctCount}/$total'
        : '${attempt.correctCount}/0';
    final date = attempt.endedAt ?? attempt.startedAt;
    return HistoryEntry(
      examName: attempt.examName,
      date: _formatAttemptDate(date),
      scorePercent: attempt.score.toDouble(),
      scoreDetail: scoreDetail,
      attemptId: attempt.attemptId,
      examId: attempt.examId,
    );
  }

  List<PerformanceAttempt> _sortedAttempts(List<PerformanceAttempt> attempts) {
    final sorted = List<PerformanceAttempt>.from(attempts);
    sorted.sort((a, b) {
      final aTime = a.endedAt ?? a.startedAt;
      final bTime = b.endedAt ?? b.startedAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  List<HistoryAttempt> _sortedHistoryAttempts(List<HistoryAttempt> attempts) {
    final sorted = List<HistoryAttempt>.from(attempts);
    sorted.sort((a, b) {
      final aTime = a.endedAt ?? a.startedAt;
      final bTime = b.endedAt ?? b.startedAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  int _averageScore(List<int> scores) {
    if (scores.isEmpty) return 0;
    final total = scores.reduce((a, b) => a + b);
    return (total / scores.length).round();
  }

  int _bestScore(List<int> scores) {
    int best = 0;
    for (final score in scores) {
      if (score > best) best = score;
    }
    return best;
  }

  Widget _buildShimmer({required Widget child}) {
    final baseColor = Colors.grey[300]!;
    final highlightColor = Colors.grey[100]!;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }

  Widget _buildShimmerLine({
    required double width,
    required double height,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildMasteryShimmerCard(double scale) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 12 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFFECF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE6FA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerLine(
                  width: 90 * scale,
                  height: 8 * scale,
                  radius: 4 * scale,
                ),
                SizedBox(height: 6 * scale),
                _buildShimmerLine(
                  width: 60 * scale,
                  height: 8 * scale,
                  radius: 4 * scale,
                ),
              ],
            ),
          ),
          SizedBox(width: 6 * scale),
          _buildShimmerLine(
            width: 34 * scale,
            height: 34 * scale,
            radius: 17 * scale,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationShimmer(double scale) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 10 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E5F1)),
      ),
      child: Row(
        children: [
          Container(
            width: 4 * scale,
            height: 42 * scale,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerLine(
                  width: double.infinity,
                  height: 8 * scale,
                  radius: 4 * scale,
                ),
                SizedBox(height: 6 * scale),
                _buildShimmerLine(
                  width: 140 * scale,
                  height: 8 * scale,
                  radius: 4 * scale,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryShimmer(double scale) {
    return Column(
      children: List.generate(4, (index) {
        return Column(
          children: [
            const Divider(height: 1, color: Color(0xFFE4E8F2)),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8 * scale),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildShimmerLine(
                      width: double.infinity,
                      height: 8 * scale,
                      radius: 4 * scale,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildShimmerLine(
                          width: 70 * scale,
                          height: 8 * scale,
                          radius: 4 * scale,
                        ),
                        SizedBox(height: 6 * scale),
                        _buildShimmerLine(
                          width: 50 * scale,
                          height: 8 * scale,
                          radius: 4 * scale,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildShimmerLine(
                          width: 36 * scale,
                          height: 8 * scale,
                          radius: 4 * scale,
                        ),
                        SizedBox(height: 6 * scale),
                        _buildShimmerLine(
                          width: 28 * scale,
                          height: 8 * scale,
                          radius: 4 * scale,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required String examLabel,
    required List<HistoryEntry> history,
    required List<int> scores,
    required int latestScore,
    required int averageScore,
    required int bestScore,
    required bool isLoading,
    required String? errorMessage,
    required String recommendationText,
    bool useShimmerLoading = false,
    bool showOverviewLoading = false,
    bool useOverviewCards = false,
    int? overviewAverageScore,
    int? overviewBestScore,
    int? attemptsCountOverride,
    VoidCallback? onSeeMore,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double scale = (constraints.maxWidth / 375).clamp(0.85, 1.15);
        final double hPad = 16 * scale;
        final double titleSize = 15 * scale;
        final double sectionTitle = 12.5 * scale;
        final double bodySize = 11 * scale;
        final double cardTitle = 10.5 * scale;

        final bool showOverviewShimmer =
            useShimmerLoading && showOverviewLoading;

        final List<Widget> masteryCards = showOverviewShimmer
            ? [
                Expanded(child: _buildMasteryShimmerCard(scale)),
                SizedBox(width: 10 * scale),
                Expanded(child: _buildMasteryShimmerCard(scale)),
              ]
            : useOverviewCards
                ? [
                    Expanded(
                      child: _MasteryCard(
                        label: 'Average Score',
                        percent: overviewAverageScore,
                        scale: scale,
                        titleSize: cardTitle,
                      ),
                    ),
                    SizedBox(width: 10 * scale),
                    Expanded(
                      child: _MasteryCard(
                        label: 'Best Score',
                        percent: overviewBestScore,
                        scale: scale,
                        titleSize: cardTitle,
                      ),
                    ),
                  ]
                : scores.isNotEmpty
                    ? [
                        Expanded(
                          child: _MasteryCard(
                            label: '$examLabel\nLatest Score',
                            percent: latestScore,
                            scale: scale,
                            titleSize: cardTitle,
                          ),
                        ),
                        SizedBox(width: 10 * scale),
                        Expanded(
                          child: _MasteryCard(
                            label: 'Average Score',
                            percent: averageScore,
                            scale: scale,
                            titleSize: cardTitle,
                          ),
                        ),
                      ]
                    : [
                        Expanded(
                          child: _MasteryCard(
                            label: '$examLabel\nLatest Score',
                            percent: widget.entry.scorePercent.round(),
                            scale: scale,
                            titleSize: cardTitle,
                          ),
                        ),
                        SizedBox(width: 10 * scale),
                        Expanded(
                          child: _MasteryCard(
                            label: 'Best Score',
                            percent: bestScore == 0 ? null : bestScore,
                            scale: scale,
                            titleSize: cardTitle,
                          ),
                        ),
                      ];

        final int attemptsCount = attemptsCountOverride ?? scores.length;

        final VoidCallback handleSeeMore = onSeeMore ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('See more tapped.')),
              );
            };

        return Scaffold(
          backgroundColor: const Color(0xFFF2F5FF),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, 8 * scale, hPad, 24 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        color: const Color(0xFF27407C),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Performance',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF27407C),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 42 * scale),
                    ],
                  ),
                  SizedBox(height: 10 * scale),
                  _SectionCard(
                    title: 'Mastery Overview',
                    scale: scale,
                    titleSize: sectionTitle,
                    child: Column(
                      children: [
                        Row(children: masteryCards),
                        SizedBox(height: 6 * scale),
                        Align(
                          alignment: Alignment.centerRight,
                          child: showOverviewShimmer
                              ? _buildShimmer(
                                  child: _buildShimmerLine(
                                    width: 70 * scale,
                                    height: 8 * scale,
                                    radius: 4 * scale,
                                  ),
                                )
                              : Text(
                                  'Attempts: $attemptsCount',
                                  style: TextStyle(
                                    fontSize: 9.5 * scale,
                                    color: const Color(0xFF6C7685),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  _SectionCard(
                    title: 'Smart Recommendation',
                    scale: scale,
                    titleSize: sectionTitle,
                    child: showOverviewShimmer
                        ? _buildShimmer(
                            child: _buildRecommendationShimmer(scale),
                          )
                        : Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12 * scale,
                              vertical: 10 * scale,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF1FF),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFE0E5F1)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4 * scale,
                                  height: 42 * scale,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E4AA8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                SizedBox(width: 10 * scale),
                                Expanded(
                                  child: Text(
                                    recommendationText,
                                    style: TextStyle(
                                      fontSize: bodySize,
                                      color: const Color(0xFF2A3240),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  SizedBox(height: 12 * scale),
                  Row(
                    children: [
                      Text(
                        'Consolidated Quiz History',
                        style: TextStyle(
                          fontSize: sectionTitle,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2A3240),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: handleSeeMore,
                        child: Text(
                          'See more',
                          style: TextStyle(
                            fontSize: 10.5 * scale,
                            color: const Color(0xFF1E6CF3),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8 * scale),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * scale,
                      vertical: 10 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E5F1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _HeaderChip(
                              label: 'EXAM',
                              fontSize: 9.5 * scale,
                              height: 26 * scale,
                            ),
                            SizedBox(width: 8 * scale),
                            _HeaderChip(
                              label: 'DATE',
                              fontSize: 9.5 * scale,
                              height: 26 * scale,
                            ),
                            SizedBox(width: 8 * scale),
                            _HeaderChip(
                              label: 'SCORE',
                              fontSize: 9.5 * scale,
                              height: 26 * scale,
                            ),
                          ],
                        ),
                        SizedBox(height: 6 * scale),
                        if (isLoading && history.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8 * scale),
                            child: _buildShimmer(
                              child: _buildHistoryShimmer(scale),
                            ),
                          )
                        else if (errorMessage != null &&
                            errorMessage.trim().isNotEmpty &&
                            history.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12 * scale),
                            child: Column(
                              children: [
                                Text(
                                  errorMessage,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9.5 * scale,
                                    color: const Color(0xFF6C7685),
                                  ),
                                ),
                                SizedBox(height: 6 * scale),
                                TextButton(
                                  onPressed: () {
                                    final id = widget.entry.examId;
                                    if (id != null && id.trim().isNotEmpty) {
                                      _controller.fetchPerformance(id);
                                    }
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        else if (history.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12 * scale),
                            child: Text(
                              'No history available.',
                              style: TextStyle(
                                fontSize: 9.5 * scale,
                                color: const Color(0xFF6C7685),
                              ),
                            ),
                          )
                        else
                          ...history.take(4).map((entry) {
                            final Color scoreColor = entry.scorePercent <= 20
                                ? const Color(0xFFE53935)
                                : entry.scorePercent <= 30
                                    ? const Color(0xFFFF8A00)
                                    : const Color(0xFFFF4D4D);
                            return Column(
                              children: [
                                const Divider(
                                  height: 1,
                                  color: Color(0xFFE4E8F2),
                                ),
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 8 * scale),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          entry.examName,
                                          style: TextStyle(
                                            fontSize: 9.8 * scale,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF2A3240),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          entry.date.replaceFirst(', ', ',\n'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 9.2 * scale,
                                            color: const Color(0xFF6C7685),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${entry.scorePercent.toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                fontSize: 9.8 * scale,
                                                fontWeight: FontWeight.w700,
                                                color: scoreColor,
                                              ),
                                            ),
                                            Text(
                                              entry.scoreDetail,
                                              style: TextStyle(
                                                fontSize: 9.2 * scale,
                                                color: const Color(0xFF6C7685),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3C8A),
                        padding: EdgeInsets.symmetric(
                          vertical: 12 * scale,
                          horizontal: 22 * scale,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: Text(
                        'Back to Home',
                        style: TextStyle(fontSize: 12 * scale),
                      ),
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Disclaimer tapped.'),
                          ),
                        );
                      },
                      child: Text.rich(
                        TextSpan(
                          text: 'Not affiliated with or endorsed by API. ',
                          style: TextStyle(
                            fontSize: 9.5 * scale,
                            color: const Color(0xFF6C7685),
                          ),
                          children: [
                            TextSpan(
                              text: 'See full\n',
                              style: TextStyle(
                                fontSize: 9.5 * scale,
                                color: const Color(0xFF1E6CF3),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(
                              text: 'disclaimer.',
                              style: TextStyle(
                                fontSize: 9.5 * scale,
                                color: const Color(0xFF1E6CF3),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final examId = widget.entry.examId;
    final String examLabel = widget.entry.examName;

    if (widget.isProfileFlow) {
      return Obx(() {
        final PerformanceData? overview =
            _controller.performanceByExam[PerformanceController.overviewKey];
        final bool overviewLoading =
            _controller.loadingByExam[PerformanceController.overviewKey] ??
                false;
        final historyController = _historyController;
        final List<HistoryAttempt> attempts =
            historyController?.attempts.toList() ?? const [];
        final List<HistoryAttempt> sortedAttempts =
            _sortedHistoryAttempts(attempts);
        final List<HistoryEntry> history = sortedAttempts
            .map(_mapHistoryAttemptToEntry)
            .toList();
        final List<int> scores =
            history.map((entry) => entry.scorePercent.round()).toList();
        final int latestScore = scores.isNotEmpty ? scores.first : 0;
        final int averageScore = _averageScore(scores);
        final int bestScore = _bestScore(scores);

        final int? overviewAverageScore = overview?.avgScore?.round();
        final int? overviewBestScore = overview?.bestScore?.round();
        final int? overviewAttemptsCount = overview?.totalAttempts;
        final int totalAttempts = overviewAttemptsCount ?? history.length;

        final bool hasAttempts = totalAttempts > 0;
        final int displayAverage = overviewAverageScore ?? averageScore;
        final int displayBest = overviewBestScore ?? bestScore;
        final String recommendationText = !hasAttempts
            ? 'No attempts yet.\nTake a quiz to see recommendations.'
            : 'Average score is $displayAverage%.\n'
                'Best score is $displayBest%.';

        return _buildContent(
          context: context,
          examLabel: 'All Exams',
          history: history,
          scores: scores,
          latestScore: latestScore,
          averageScore: averageScore,
          bestScore: bestScore,
          isLoading: historyController?.isLoading.value ?? false,
          errorMessage: historyController?.errorMessage.value,
          recommendationText: recommendationText,
          useShimmerLoading: true,
          showOverviewLoading: overviewLoading,
          useOverviewCards: true,
          overviewAverageScore: overviewAverageScore,
          overviewBestScore: overviewBestScore,
          attemptsCountOverride: overviewAttemptsCount,
          onSeeMore: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    HistoryListScreen(controllerTag: _profileHistoryTag),
              ),
            );
          },
        );
      });
    }

    if (examId == null || examId.trim().isEmpty) {
      final List<HistoryEntry> history = widget.history;
      final List<int> scores =
          history.map((entry) => entry.scorePercent.round()).toList();
      final int latestScore = history.isNotEmpty
          ? history.first.scorePercent.round()
          : widget.entry.scorePercent.round();
      final int averageScore = _averageScore(scores);
      final int bestScore = _bestScore(scores);
      final String recommendationText = scores.isEmpty
          ? 'No attempts yet for $examLabel.\n'
              'Take a quiz to see recommendations.'
          : 'Latest score for $examLabel is $latestScore%.\n'
              'Practice weak areas to improve.';

      return _buildContent(
        context: context,
        examLabel: examLabel,
        history: history,
        scores: scores,
        latestScore: latestScore,
        averageScore: averageScore,
        bestScore: bestScore,
        isLoading: false,
        errorMessage: null,
        recommendationText: recommendationText,
      );
    }

    return Obx(() {
      final PerformanceData? performance = _controller.performanceByExam[examId];
      final bool isLoading = _controller.loadingByExam[examId] ?? false;
      final String? errorMessage = _controller.errorByExam[examId];

      final List<PerformanceAttempt> attempts =
          performance?.attempts ?? const [];
      final List<PerformanceAttempt> sortedAttempts =
          _sortedAttempts(attempts);
      final List<HistoryEntry> apiHistory = sortedAttempts
          .map((attempt) => _mapAttemptToEntry(attempt, examLabel))
          .toList();
      final List<HistoryEntry> history =
          apiHistory.isNotEmpty ? apiHistory : widget.history;
      final List<int> scores = attempts.isNotEmpty
          ? attempts.map((attempt) => attempt.score).toList()
          : history.map((entry) => entry.scorePercent.round()).toList();
      final int latestScore = attempts.isNotEmpty
          ? sortedAttempts.first.score
          : (history.isNotEmpty
              ? history.first.scorePercent.round()
              : widget.entry.scorePercent.round());
      final int averageScore = _averageScore(scores);
      final int bestScore = _bestScore(scores);

      final String recommendationText = scores.isEmpty
          ? 'No attempts yet for $examLabel.\n'
              'Take a quiz to see recommendations.'
          : 'Latest score for $examLabel is $latestScore%.\n'
              'Practice weak areas to improve.';

      return _buildContent(
        context: context,
        examLabel: examLabel,
        history: history,
        scores: scores,
        latestScore: latestScore,
        averageScore: averageScore,
        bestScore: bestScore,
        isLoading: isLoading,
        errorMessage: errorMessage,
        recommendationText: recommendationText,
      );
    });
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.scale,
    required this.titleSize,
    required this.child,
  });

  final String title;
  final double scale;
  final double titleSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 12 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E2A3A),
            ),
          ),
          SizedBox(height: 10 * scale),
          child,
        ],
      ),
    );
  }
}

class _MasteryCard extends StatelessWidget {
  const _MasteryCard({
    required this.label,
    required this.percent,
    required this.scale,
    required this.titleSize,
  });

  final String label;
  final int? percent;
  final double scale;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 12 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFFECF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE6FA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2A3240),
              ),
            ),
          ),
          SizedBox(width: 6 * scale),
          _PercentRing(percent: percent, scale: scale),
        ],
      ),
    );
  }
}

class _PercentRing extends StatelessWidget {
  const _PercentRing({
    required this.percent,
    required this.scale,
  });

  final int? percent;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double size = 34 * scale;
    final Color ringColor = percent == null
        ? const Color(0xFFB9BFCB)
        : const Color(0xFFEE3D3D);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          percent == null ? '-' : '$percent%',
          style: TextStyle(
            fontSize: 9.5 * scale,
            fontWeight: FontWeight.w700,
            color: ringColor,
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.label,
    required this.fontSize,
    required this.height,
  });

  final String label;
  final double fontSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1E5EF)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2A3240),
          ),
        ),
      ),
    );
  }
}
