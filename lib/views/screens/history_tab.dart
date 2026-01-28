import 'package:flutter/material.dart';

import 'history_detail_view.dart';
import 'history_list_view.dart';
import 'history_models.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final List<HistoryEntry> _history = const [
    HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/10/2020, 10:45:37 AM',
      scorePercent: 40.0,
      scoreDetail: '4/10',
    ),
    HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/9/2026, 4:00:18 PM',
      scorePercent: 30.0,
      scoreDetail: '3/10',
    ),
    HistoryEntry(
      examName: 'API 570 - Piping Inspector',
      date: '1/9/2026, 2:46:37 PM',
      scorePercent: 20.0,
      scoreDetail: '2/10',
    ),
  ];

  final List<TopicBreakdown> _topics = const [
    TopicBreakdown(
      category: 'Preheating and Heat\nTreatment',
      correct: 0,
      incorrect: 0,
      accuracy: 1,
    ),
    TopicBreakdown(
      category: 'Corrosion Rates and\nInspection Intervals',
      correct: 0,
      incorrect: 0,
      accuracy: 1,
    ),
    TopicBreakdown(
      category: 'Weld Joint Quality\nFactors',
      correct: 0,
      incorrect: 0,
      accuracy: 1,
    ),
    TopicBreakdown(
      category: 'Internal Pressure /\nMinimum Thickness of\nPipe',
      correct: 0,
      incorrect: 0,
      accuracy: 1,
    ),
    TopicBreakdown(
      category: 'Pressure Testing',
      correct: 0,
      incorrect: 0,
      accuracy: 1,
    ),
    TopicBreakdown(
      category: 'Thermal Expansion',
      correct: 0,
      incorrect: 0,
      accuracy: 1,
    ),
    TopicBreakdown(
      category: 'Blanks',
      correct: 1,
      incorrect: 1,
      accuracy: 1,
    ),
    TopicBreakdown(
      category: 'Impact Testing',
      correct: 1,
      incorrect: 1,
      accuracy: 1,
    ),
    TopicBreakdown(
      category: 'Flanges',
      correct: 1,
      incorrect: 1,
      accuracy: 1,
    ),
  ];

  HistoryEntry? _selectedEntry;
  String _selectedFilter = 'All Exams';

  @override
  Widget build(BuildContext context) {
    final List<HistoryEntry> filtered = _selectedFilter == 'All Exams'
        ? _history
        : _history
            .where((entry) => entry.examName == _selectedFilter)
            .toList();

    return SafeArea(
      child: _selectedEntry == null
          ? HistoryListView(
              entries: filtered,
              filterValue: _selectedFilter,
              onFilterChanged: (value) =>
                  setState(() => _selectedFilter = value),
              onSelect: (entry) =>
                  setState(() => _selectedEntry = entry),
            )
          : HistoryDetailView(
              entry: _selectedEntry!,
              topics: _topics,
              onBack: () => setState(() => _selectedEntry = null),
            ),
    );
  }
}
