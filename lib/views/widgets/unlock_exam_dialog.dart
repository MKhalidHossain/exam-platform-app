import 'package:flutter/material.dart';
import 'app_shimmer.dart';
import '../../core/error/app_exception.dart';
import '../../core/error/error_handler.dart';
import '../../models/exam_model.dart';
import '../../services/exam_service.dart';

class UnlockExamDialogResult {
  final ExamModel exam;
  final bool alreadyUnlocked;

  const UnlockExamDialogResult({
    required this.exam,
    required this.alreadyUnlocked,
  });
}

class UnlockExamDialog extends StatefulWidget {
  final ExamService examService;
  final int maxSelect;
  final String? initialSelectedId;
  final Set<String> unlockedIds;

  const UnlockExamDialog({
    super.key,
    required this.examService,
    required this.maxSelect,
    this.initialSelectedId,
    this.unlockedIds = const {},
  });

  @override
  State<UnlockExamDialog> createState() => _UnlockExamDialogState();
}

class _UnlockExamDialogState extends State<UnlockExamDialog> {
  late final Future<List<ExamModel>> _future;
  final Set<String> _selectedIds = {};
  bool _acknowledged = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (widget.initialSelectedId != null &&
        widget.initialSelectedId!.trim().isNotEmpty) {
      final id = widget.initialSelectedId!.trim();
      if (!widget.unlockedIds.contains(id)) {
        _selectedIds.add(id);
      }
    }
  }

  Future<List<ExamModel>> _load() async {
    final res = await widget.examService.getActiveExams();
    if (!res.success) {
      throw AppException(
        userMessage: ErrorHandler.getMessageFromResponse(res, failureFallback: 'Failed to fetch exams'),
      );
    }
    final exams = res.data ?? const [];
    if (_selectedIds.isNotEmpty) {
      final unlockedIds = exams
          .where((exam) => exam.unlocked == true)
          .map((exam) => exam.id)
          .toSet();
      unlockedIds.addAll(widget.unlockedIds);
      _selectedIds.removeWhere((id) => unlockedIds.contains(id));
    }
    return exams;
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (widget.maxSelect == 1) {
          _selectedIds
            ..clear()
            ..add(id);
          return;
        }
        if (_selectedIds.length >= widget.maxSelect) return;
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: FutureBuilder<List<ExamModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 320,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppShimmerBox(width: 180, height: 18, radius: 8),
                      const SizedBox(height: 16),
                      ...List.generate(3, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: const [
                              AppShimmerCircle(size: 36),
                              SizedBox(width: 12),
                              Expanded(
                                child: AppShimmerBox(
                                  height: 14,
                                  radius: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unlock Your Exam Access',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              );
            }

            final exams = snapshot.data ?? const <ExamModel>[];
            final unlockedIds = <String>{...widget.unlockedIds};
            for (final exam in exams) {
              if (exam.unlocked == true) {
                unlockedIds.add(exam.id);
              }
            }
            final bool hasLockedSelection =
                _selectedIds.any((id) => !unlockedIds.contains(id));
            final canConfirm = _acknowledged && hasLockedSelection;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unlock Your Exam Access',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome to the Professional plan! Please select ${widget.maxSelect} exam${widget.maxSelect == 1 ? '' : 's'} to unlock.',
                  style: const TextStyle(fontSize: 14, height: 1.3),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: exams.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final e = exams[index];
                      final bool isUnlocked = unlockedIds.contains(e.id);
                      final selected = _selectedIds.contains(e.id);
                      final disabled = isUnlocked ||
                          (!selected &&
                              widget.maxSelect != 1 &&
                              _selectedIds.length >= widget.maxSelect);

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: disabled
                            ? (isUnlocked
                                ? () => Navigator.pop(
                                      context,
                                      UnlockExamDialogResult(
                                        exam: e,
                                        alreadyUnlocked: true,
                                      ),
                                    )
                                : null)
                            : () => _toggle(e.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged:
                                    disabled ? null : (_) => _toggle(e.id),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Master your certification exam',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    if (isUnlocked) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD8F5D8),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: const Text(
                                          'Unlocked',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1B6C3E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isUnlocked)
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                    context,
                                    UnlockExamDialogResult(
                                      exam: e,
                                      alreadyUnlocked: true,
                                    ),
                                  ),
                                  child: const Text('Open'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    '${_selectedIds.length}/${widget.maxSelect} exam${widget.maxSelect == 1 ? '' : 's'} selected',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acknowledged,
                      onChanged: (v) =>
                          setState(() => _acknowledged = v ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'I understand this selection is permanent and cannot be changed later.',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'If you selected the wrong exam, tap Go back to change it now',
                  style: TextStyle(fontSize: 12.5, color: Colors.blue[700]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          side: const BorderSide(
                            color: Color(0xFF2D4F88),
                            width: 1.5,
                          ),
                          foregroundColor: const Color(0xFF2D4F88),
                        ),
                        child: const Text('Go Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canConfirm
                            ? () async {
                                final selectedId = _selectedIds.first;
                                final selectedExam = exams.firstWhere(
                                  (e) => e.id == selectedId,
                                  orElse: () => exams.first,
                                );
                                final bool? confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) {
                                    return AlertDialog(
                                      title: const Text('Confirm unlock'),
                                      content: Text(
                                        'Are you sure you want to unlock ${selectedExam.name} with your payment?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(false),
                                          child: const Text('No'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(true),
                                          child: const Text('Yes'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (confirmed != true) return;
                                Navigator.pop(
                                  context,
                                  UnlockExamDialogResult(
                                    exam: selectedExam,
                                    alreadyUnlocked: false,
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: const Color(0xFF2D4F88),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Confirm unlock'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
