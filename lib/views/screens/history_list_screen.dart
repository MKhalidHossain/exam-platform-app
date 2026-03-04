import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'history_list_view.dart';
import 'history_models.dart';
import '../../controllers/history_controller.dart';
import '../../models/history_attempt_model.dart';

class HistoryListScreen extends StatefulWidget {
  const HistoryListScreen({
    super.key,
    this.controllerTag,
  });

  final String? controllerTag;

  @override
  State<HistoryListScreen> createState() => _HistoryListScreenState();
}

class _HistoryListScreenState extends State<HistoryListScreen> {
  late final HistoryController _controller;
  String _selectedFilter = 'All Exams';

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<HistoryController>(tag: widget.controllerTag)
        ? Get.find<HistoryController>(tag: widget.controllerTag)
        : Get.put(HistoryController(), tag: widget.controllerTag);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.isLoading.value) {
        _controller.fetchAllAttempts();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: SafeArea(
        child: Obx(() {
          final entries = _controller.attempts.map(_mapAttemptToEntry).toList();
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

          return HistoryListView(
            entries: filtered,
            filterValue: activeFilter,
            filterOptions: filters,
            onFilterChanged: (value) =>
                setState(() => _selectedFilter = value),
            onSelect: (_) {},
            isLoading: _controller.isLoading.value,
            errorMessage: _controller.errorMessage.value,
            onRetry: _controller.fetchAllAttempts,
          );
        }),
      ),
    );
  }
}
