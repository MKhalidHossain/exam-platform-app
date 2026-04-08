import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/user_controller.dart';
import '../../core/error/error_handler.dart';
import '../../models/user_unlocks_model.dart';
import '../../services/user_service.dart';
import '../../utils/app_colors.dart';
import '../widgets/animated_refresh_button.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/gradient_background.dart';

class UnlockExamResourcesScreen extends StatefulWidget {
  const UnlockExamResourcesScreen({super.key});

  @override
  State<UnlockExamResourcesScreen> createState() =>
      _UnlockExamResourcesScreenState();
}

class _UnlockExamResourcesScreenState extends State<UnlockExamResourcesScreen> {
  final UserService _userService = UserService();

  bool _isLoading = true;
  String? _error;
  UserUnlocksData? _data;

  @override
  void initState() {
    super.initState();
    _loadUnlocks();
  }

  Future<void> _loadUnlocks() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final response = await _userService.getMyUnlocks();
    if (!mounted) return;

    if (response.success && response.data != null) {
      final data = response.data!;
      final unlockedExamIds = data.unlockedExams
          .map((exam) => exam.examId)
          .where((id) => id.trim().isNotEmpty)
          .toSet();

      if (Get.isRegistered<UserController>()) {
        await Get.find<UserController>().setUnlockedExamIds(unlockedExamIds);
      }

      setState(() {
        _data = data;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _error = ErrorHandler.getMessageFromResponse(
        response,
        failureFallback: 'Unable to load unlocked exams and resources.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        useImage: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: AppColors.primaryBlueDark,
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Unlock Exam & Resources',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.primaryBlueDark,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    AnimatedRefreshButton(
                      onPressed: _loadUnlocks,
                      tooltip: 'Refresh unlock data',
                      foregroundColor: AppColors.primaryBlueDark,
                      backgroundColor: AppColors.surface,
                      borderColor: AppColors.inputBorderLight,
                      shadowColor: const Color(0x1419478D),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _data == null) {
      return RefreshIndicator(
        onRefresh: _loadUnlocks,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: const [
            _SummaryLoadingRow(),
            SizedBox(height: 18),
            _SectionLoading(titleWidth: 180),
            SizedBox(height: 18),
            _SectionLoading(titleWidth: 210),
          ],
        ),
      );
    }

    if (_error != null && _data == null) {
      return RefreshIndicator(
        onRefresh: _loadUnlocks,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [_ErrorCard(message: _error!)],
        ),
      );
    }

    final data = _data;
    if (data == null) {
      return const SizedBox.shrink();
    }

    final unlockedExams = data.unlockedExams;
    final unlockedResources = data.unlockedResources
        .where((resource) => resource.isBundle || !resource.inheritedFromBundle)
        .toList(growable: false);
    final hasNoUnlocks = unlockedExams.isEmpty && unlockedResources.isEmpty;

    return RefreshIndicator(
      onRefresh: _loadUnlocks,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _SummaryRow(
            examCount: data.unlockedExamCount,
            resourceCount: unlockedResources.length,
          ),
          const SizedBox(height: 18),
          if (_error != null) ...[
            _InlineNotice(message: _error!),
            const SizedBox(height: 18),
          ],
          if (hasNoUnlocks) ...[
            const _EmptyUnlocksCard(),
          ] else ...[
            _SectionHeader(
              icon: Icons.fact_check_outlined,
              title: 'Unlocked Exams',
              count: unlockedExams.length,
            ),
            const SizedBox(height: 12),
            if (unlockedExams.isEmpty)
              const _EmptySectionCard(
                message: 'No unlocked exams found for this account yet.',
              )
            else
              ...unlockedExams.map(
                (exam) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExamUnlockCard(exam: exam),
                ),
              ),
            const SizedBox(height: 18),
            _SectionHeader(
              icon: Icons.menu_book_outlined,
              title: 'Unlocked Resources',
              count: unlockedResources.length,
            ),
            const SizedBox(height: 12),
            if (unlockedResources.isEmpty)
              const _EmptySectionCard(
                message: 'No unlocked resources found for this account yet.',
              )
            else
              ...unlockedResources.map(
                (resource) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ResourceUnlockCard(resource: resource),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.examCount, required this.resourceCount});

  final int examCount;
  final int resourceCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.fact_check_outlined,
            title: 'Unlocked Exams',
            value: examCount.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.menu_book_outlined,
            title: 'Unlocked Resources',
            value: resourceCount.toString(),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inputBorderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1419478D),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryBlueDark, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlueDark,
            ),
          ),
        ),
        _StatusChip(
          label: '$count',
          backgroundColor: AppColors.backgroundLight,
          foregroundColor: AppColors.primaryBlue,
        ),
      ],
    );
  }
}

class _ExamUnlockCard extends StatelessWidget {
  const _ExamUnlockCard({required this.exam});

  final UnlockedExam exam;

  @override
  Widget build(BuildContext context) {
    final unlockedAt = exam.purchasedAt ?? exam.unlockDate;
    final examTitle = exam.examName.trim().isNotEmpty
        ? exam.examName.trim()
        : 'Exam ${exam.examId}';
    final purchaseType = _toTitleCase(exam.purchaseType);
    final paymentStatus = _toTitleCase(exam.paymentStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  examTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusChip(
                label: exam.isExpired ? 'Expired' : 'Active',
                backgroundColor: exam.isExpired
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFDCFCE7),
                foregroundColor: exam.isExpired
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFF166534),
              ),
            ],
          ),
          if (exam.examId.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Exam ID: ${exam.examId}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (purchaseType.isNotEmpty)
                _MetaPill(
                  icon: Icons.workspace_premium_outlined,
                  label: purchaseType,
                ),
              if (paymentStatus.isNotEmpty)
                _MetaPill(icon: Icons.payments_outlined, label: paymentStatus),
              _MetaPill(
                icon: Icons.calendar_today_outlined,
                label: 'Unlocked ${_formatDate(unlockedAt)}',
              ),
              _MetaPill(
                icon: Icons.schedule_outlined,
                label: 'Expires ${_formatDate(exam.expiresAt)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResourceUnlockCard extends StatelessWidget {
  const _ResourceUnlockCard({required this.resource});

  final UnlockedResource resource;

  @override
  Widget build(BuildContext context) {
    final categoryTitle = resource.categoryTitle.trim().isNotEmpty
        ? resource.categoryTitle.trim()
        : 'Resource';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resource.title.trim().isNotEmpty
                ? resource.title.trim()
                : resource.productCode,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            categoryTitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (resource.sourceLabel.trim().isNotEmpty)
                _MetaPill(
                  icon: Icons.sell_outlined,
                  label: resource.sourceLabel.trim(),
                ),
              _MetaPill(
                icon: Icons.calendar_today_outlined,
                label: 'Unlocked ${_formatDate(resource.purchasedAt)}',
              ),
              if (resource.isBundle)
                const _MetaPill(
                  icon: Icons.inventory_2_outlined,
                  label: 'Bundle',
                ),
              if (resource.inheritedFromBundle)
                const _MetaPill(
                  icon: Icons.auto_awesome_motion_outlined,
                  label: 'From bundle',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.inputBorderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlueDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlueDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _EmptyUnlocksCard extends StatelessWidget {
  const _EmptyUnlocksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: const Column(
        children: [
          Icon(
            Icons.lock_open_outlined,
            size: 38,
            color: AppColors.primaryBlue,
          ),
          SizedBox(height: 14),
          Text(
            'No unlock data found yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Unlocked exams and purchased resources will appear here once they are available on your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration().copyWith(
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB91C1C),
            size: 34,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to load unlock data',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF92400E),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLoadingRow extends StatelessWidget {
  const _SummaryLoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: AppShimmerBox(height: 140, radius: 18)),
        SizedBox(width: 12),
        Expanded(child: AppShimmerBox(height: 140, radius: 18)),
      ],
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading({required this.titleWidth});

  final double titleWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppShimmerBox(width: titleWidth, height: 28, radius: 8),
        const SizedBox(height: 12),
        const AppShimmerBox(height: 160, radius: 18),
        const SizedBox(height: 12),
        const AppShimmerBox(height: 160, radius: 18),
      ],
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.inputBorderLight),
    boxShadow: const [
      BoxShadow(
        color: Color(0x1419478D),
        blurRadius: 20,
        offset: Offset(0, 10),
      ),
    ],
  );
}

String _formatDate(DateTime? value) {
  if (value == null) return 'N/A';
  final local = value.toLocal();
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

String _toTitleCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  return trimmed
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) {
        final lower = part.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}
