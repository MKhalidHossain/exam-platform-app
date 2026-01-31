import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'history_detail_view.dart';
import 'history_list_view.dart';
import 'history_models.dart';
import '../../controllers/history_controller.dart';
import '../../models/history_attempt_model.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late final HistoryController _controller;
  final List<TopicBreakdown> _topics = const [
    TopicBreakdown(
      category: 'Preheating and Heat\nTreatment',
      correct: 0,
      incorrect: 0,
      accuracy: 0,
    ),
    TopicBreakdown(
      category: 'Corrosion Rates and\nInspection Intervals',
      correct: 0,
      incorrect: 0,
      accuracy: 0,
    ),
    TopicBreakdown(
      category: 'Weld Joint Quality\nFactors',
      correct: 0,
      incorrect: 0,
      accuracy: 0,
    ),
    TopicBreakdown(
      category: 'Internal Pressure /\nMinimum Thickness of\nPipe',
      correct: 0,
      incorrect: 0,
      accuracy: 0,
    ),
    TopicBreakdown(
      category: 'Pressure Testing',
      correct: 0,
      incorrect: 0,
      accuracy: 0,
    ),
    TopicBreakdown(
      category: 'Thermal Expansion',
      correct: 0,
      incorrect: 0,
      accuracy: 0,
    ),
    TopicBreakdown(
      category: 'Blanks',
      correct: 1,
      incorrect: 1,
      accuracy: 0,
    ),
    TopicBreakdown(
      category: 'Impact Testing',
      correct: 1,
      incorrect: 1,
      accuracy: 0,
    ),
    TopicBreakdown(
      category: 'Flanges',
      correct: 1,
      incorrect: 1,
      accuracy: 0,
    ),
  ];

  HistoryEntry? _selectedEntry;
  String _selectedFilter = 'All Exams';

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<HistoryController>()
        ? Get.find<HistoryController>()
        : Get.put(HistoryController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.attempts.isEmpty && !_controller.isLoading.value) {
        _controller.fetchAttempts();
      }
    });
  }

  HistoryEntry _mapAttemptToEntry(HistoryAttempt attempt) {
    final total = attempt.correctCount +
        attempt.wrongCount +
        attempt.unansweredCount;
    final scoreDetail = total > 0
        ? '${attempt.correctCount}/$total'
        : '${attempt.correctCount}/0';

    return HistoryEntry(
      examName: attempt.examName,
      date: _formatAttemptDate(attempt),
      scorePercent: attempt.score.toDouble(),
      scoreDetail: scoreDetail,
    );
  }

  String _formatAttemptDate(HistoryAttempt attempt) {
    final date = attempt.endedAt ?? attempt.startedAt;
    if (date == null) return '-';
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year}, '
        '$hour:$minute:$second $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Obx(() {
        final entries =
            _controller.attempts.map(_mapAttemptToEntry).toList();
        final filters = <String>{
          'All Exams',
          ...entries.map((entry) => entry.examName),
        }.toList();
        final activeFilter = filters.contains(_selectedFilter)
            ? _selectedFilter
            : 'All Exams';

        final List<HistoryEntry> filtered = activeFilter == 'All Exams'
            ? entries
            : entries
                .where((entry) => entry.examName == activeFilter)
                .toList();

        return _selectedEntry == null
            ? HistoryListView(
                entries: filtered,
                filterValue: activeFilter,
                filterOptions: filters,
                onFilterChanged: (value) =>
                    setState(() => _selectedFilter = value),
                onSelect: (entry) =>
                    setState(() => _selectedEntry = entry),
                isLoading: _controller.isLoading.value,
                errorMessage: _controller.errorMessage.value,
                onRetry: _controller.fetchAttempts,
              )
            : HistoryDetailView(
                entry: _selectedEntry!,
                topics: _topics,
                historyEntries: entries,
                onBack: () => setState(() => _selectedEntry = null),
              );
      }),
    );
  }
}
