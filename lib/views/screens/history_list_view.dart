import 'package:flutter/material.dart';
import '../widgets/app_shimmer.dart';

import 'history_models.dart';

class HistoryListView extends StatelessWidget {
  const HistoryListView({
    super.key,
    required this.entries,
    required this.filterValue,
    required this.filterOptions,
    required this.onFilterChanged,
    required this.onSelect,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  final List<HistoryEntry> entries;
  final String filterValue;
  final List<String> filterOptions;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<HistoryEntry> onSelect;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final double scale = (width / 375).clamp(0.85, 1.15);
        final double hPad = 16 * scale;
        final double titleSize = 16 * scale;
        final double subtitleSize = 13 * scale;
        final double headerSize = 11 * scale;
        final double rowTitleSize = 11 * scale;
        final double rowDateSize = 10 * scale;
        final double rowScoreSize = 11 * scale;
        final double topPad = 8 * scale;
        final double bottomPad = 12 * scale;

        final List<String> options =
            filterOptions.isNotEmpty ? filterOptions : const ['All Exams'];
        final String activeFilter =
            options.contains(filterValue) ? filterValue : options.first;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hPad - 4, topPad, hPad, bottomPad),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: const Color(0xFF27407C),
                  ),
                //  
                  Text(
                    'History',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF27407C),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: LayoutBuilder(
                builder: (context, headerConstraints) {
                  final double maxButtonWidth =
                      (headerConstraints.maxWidth * 0.55)
                          .clamp(0.0, headerConstraints.maxWidth);
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Consolidated Quiz History',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: subtitleSize,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF202B3C),
                          ),
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxButtonWidth),
                        child: _ExamFilterMenu(
                          value: activeFilter,
                          options: options,
                          maxWidth: maxButtonWidth,
                          onSelected: onFilterChanged,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: 12 * scale),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Container(
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
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          12 * scale,
                          12 * scale,
                          12 * scale,
                          8 * scale,
                        ),
                        child: Row(
                          children: [
                            _HeaderChip(
                              label: 'EXAM',
                              fontSize: headerSize,
                              height: 28 * scale,
                            ),
                            SizedBox(width: 8 * scale),
                            _HeaderChip(
                              label: 'DATE',
                              fontSize: headerSize,
                              height: 28 * scale,
                            ),
                            SizedBox(width: 8 * scale),
                            _HeaderChip(
                              label: 'SCORE',
                              fontSize: headerSize,
                              height: 28 * scale,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE4E8F2)),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            if (isLoading) {
                              return _HistoryListShimmer(scale: scale);
                            }

                            if (errorMessage != null &&
                                errorMessage!.trim().isNotEmpty) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16 * scale,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        errorMessage!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: rowDateSize,
                                          color: const Color(0xFF6C7685),
                                        ),
                                      ),
                                      if (onRetry != null) ...[
                                        SizedBox(height: 8 * scale),
                                        TextButton(
                                          onPressed: onRetry,
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }

                            if (entries.isEmpty) {
                              return Center(
                                child: Text(
                                  'No history yet.',
                                  style: TextStyle(
                                    fontSize: rowDateSize,
                                    color: const Color(0xFF6C7685),
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 12 * scale),
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                final Color scoreColor = entry.scorePercent <= 20
                                    ? const Color(0xFFE53935)
                                    : entry.scorePercent <= 30
                                        ? const Color(0xFFFF8A00)
                                        : const Color(0xFFFF4D4D);
                                return InkWell(
                                  onTap: () => onSelect(entry),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 10 * scale,
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            entry.examName,
                                            style: TextStyle(
                                              fontSize: rowTitleSize,
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
                                            softWrap: true,
                                            style: TextStyle(
                                              fontSize: rowDateSize,
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
                                                  fontSize: rowScoreSize,
                                                  fontWeight: FontWeight.w700,
                                                  color: scoreColor,
                                                ),
                                              ),
                                              Text(
                                                entry.scoreDetail,
                                                style: TextStyle(
                                                  fontSize: rowDateSize,
                                                  color: const Color(0xFF6C7685),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              separatorBuilder: (context, index) => const Divider(
                                height: 1,
                                color: Color(0xFFE4E8F2),
                              ),
                              itemCount: entries.length,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 12 * scale),
          ],
        );
      },
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

class _ExamFilterMenu extends StatefulWidget {
  const _ExamFilterMenu({
    required this.value,
    required this.options,
    required this.maxWidth,
    required this.onSelected,
  });

  final String value;
  final List<String> options;
  final double maxWidth;
  final ValueChanged<String> onSelected;

  @override
  State<_ExamFilterMenu> createState() => _ExamFilterMenuState();
}

class _ExamFilterMenuState extends State<_ExamFilterMenu> {
  @override
  Widget build(BuildContext context) {
    const double horizontalPadding = 12;
    const double iconSpacing = 6;
    const double iconSize = 16;
    final double labelMaxWidth =
        (widget.maxWidth - (horizontalPadding * 2 + iconSpacing + iconSize))
            .clamp(0.0, widget.maxWidth);

    return PopupMenuButton<String>(
      onSelected: (value) {
        widget.onSelected(value);
      },
      itemBuilder: (context) => widget.options
          .map(
            (option) => PopupMenuItem<String>(
              value: option,
              child: Text(option, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1E4AA8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: labelMaxWidth),
              child: Text(
                widget.value,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: iconSpacing),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: iconSize,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryListShimmer extends StatelessWidget {
  const _HistoryListShimmer({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 10 * scale),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AppShimmerBox(
                  height: 10 * scale,
                  radius: 4 * scale,
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    AppShimmerBox(
                      width: 70 * scale,
                      height: 10 * scale,
                      radius: 4 * scale,
                    ),
                    SizedBox(height: 6 * scale),
                    AppShimmerBox(
                      width: 50 * scale,
                      height: 10 * scale,
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
                    AppShimmerBox(
                      width: 36 * scale,
                      height: 10 * scale,
                      radius: 4 * scale,
                    ),
                    SizedBox(height: 6 * scale),
                    AppShimmerBox(
                      width: 28 * scale,
                      height: 10 * scale,
                      radius: 4 * scale,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: Color(0xFFE4E8F2)),
      itemCount: 6,
    );
  }
}
