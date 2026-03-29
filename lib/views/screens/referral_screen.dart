import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/error/error_handler.dart';
import '../../models/referral_model.dart';
import '../../services/referral_service.dart';
import '../../utils/referral_share_message.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/animated_refresh_button.dart';
import '../widgets/gradient_background.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final ReferralService _referralService = ReferralService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  ReferralProfile? _profile;
  ReferralReferredUsersData? _usersData;
  ReferralLedgerData? _ledgerData;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final profileRes = await _referralService.getMyReferralProfile();
    final usersRes = await _referralService.getMyReferredUsers(
      page: 1,
      limit: 50,
    );
    final ledgerRes = await _referralService.getMyReferralLedger(
      page: 1,
      limit: 50,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;

      if (profileRes.success && profileRes.data != null) {
        _profile = profileRes.data;
      }
      if (usersRes.success && usersRes.data != null) {
        _usersData = usersRes.data;
      }
      if (ledgerRes.success && ledgerRes.data != null) {
        _ledgerData = ledgerRes.data;
      }

      if (_profile == null) {
        _error = ErrorHandler.getMessageFromResponse(
          profileRes,
          failureFallback: 'Unable to load referral data.',
        );
      }
    });
  }

  Future<double?> _promptAmount({
    required String title,
    required String hintText,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<double?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: hintText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                Navigator.of(context).pop(null);
                return;
              }
              final value = double.tryParse(text);
              Navigator.of(context).pop(value);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    return result;
  }

  Future<void> _convertToCredit() async {
    final amount = await _promptAmount(
      title: 'Convert to App Credit',
      hintText: 'Leave blank to convert full available balance',
    );
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    final response = await _referralService.convertToCredit(amount: amount);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!response.success) {
      ErrorHandler.showFromResponse(
        response,
        context: context,
        failureFallback: 'Unable to convert balance to app credit.',
      );
      return;
    }

    ErrorHandler.showSnackBar(
      'Referral balance converted to app credit.',
      isError: false,
      context: context,
    );
    await _loadAll();
  }

  Future<void> _requestCashPayout() async {
    final amount = await _promptAmount(
      title: 'Request Cash Payout',
      hintText: 'Leave blank to request full available balance',
    );
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    final response = await _referralService.requestCashPayout(amount: amount);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!response.success) {
      ErrorHandler.showFromResponse(
        response,
        context: context,
        failureFallback: 'Unable to submit payout request.',
      );
      return;
    }

    ErrorHandler.showSnackBar(
      'Cash payout request submitted.',
      isError: false,
      context: context,
    );
    await _loadAll();
  }

  Future<void> _shareReferralInvite(ReferralProfile profile) async {
    final referralLink = profile.referralLink.trim();
    if (referralLink.isNotEmpty) {
      final shareMessage = buildReferralShareMessage(profile);
      await Share.share(shareMessage.isEmpty ? referralLink : shareMessage);
      return;
    }

    if (!mounted) return;
    ErrorHandler.showSnackBar(
      'Referral link is not ready yet.',
      context: context,
    );
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
                      color: const Color(0xFF10213F),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Referral Center',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF10213F),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _profile == null
                              ? null
                              : () => _shareReferralInvite(_profile!),
                          icon: const Icon(Icons.share_outlined),
                          color: const Color(0xFF10213F),
                        ),
                        AnimatedRefreshButton(
                          onPressed: _loadAll,
                          tooltip: 'Refresh referral data',
                          backgroundColor: const Color(0xFFF8FAFC),
                          borderColor: const Color(0x1F10213F),
                          shadowColor: const Color(0x1A10213F),
                        ),
                      ],
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
    if (_isLoading) {
      return RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _buildLoadingHero(),
            const SizedBox(height: 16),
            _buildLoadingActionBar(),
            const SizedBox(height: 18),
            _buildLoadingSection('Referred Buyers', cards: 2),
            const SizedBox(height: 18),
            _buildLoadingSection('Reward Ledger', cards: 2),
            const SizedBox(height: 18),
            _buildLoadingSection('Payout Requests', cards: 1),
            const SizedBox(height: 18),
            _buildLoadingSection('Credit Conversions', cards: 1),
          ],
        ),
      );
    }

    if (_error != null && _profile == null) {
      return RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 80, 18, 28),
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D4F88),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return const SizedBox.shrink();
    }

    final users = _usersData?.users ?? const <ReferralReferredUser>[];
    final ledger = _ledgerData;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _buildHero(profile),
          const SizedBox(height: 16),
          _buildActionBar(profile),
          const SizedBox(height: 18),
          _buildSectionTitle('Referred Buyers'),
          const SizedBox(height: 10),
          if (users.isEmpty)
            _emptyCard('No referred users yet.')
          else
            ...users.map(_buildReferredUserCard),
          const SizedBox(height: 18),
          _buildSectionTitle('Reward Ledger'),
          const SizedBox(height: 10),
          _buildRewardLedger(ledger?.rewards ?? const []),
          const SizedBox(height: 18),
          _buildSectionTitle('Payout Requests'),
          const SizedBox(height: 10),
          _buildPayoutLedger(ledger?.payouts ?? const []),
          const SizedBox(height: 18),
          _buildSectionTitle('Credit Conversions'),
          const SizedBox(height: 10),
          _buildConversionLedger(ledger?.conversions ?? const []),
        ],
      ),
    );
  }

  Widget _buildLoadingHero() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173B2E), Color(0xFF245B47), Color(0xFF4C9A7D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332D4F88),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmerBox(width: 120, height: 14, radius: 6),
          SizedBox(height: 10),
          AppShimmerBox(width: 170, height: 30, radius: 8),
          SizedBox(height: 10),
          AppShimmerBox(width: double.infinity, height: 14, radius: 6),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: AppShimmerBox(height: 56, radius: 18)),
              SizedBox(width: 8),
              Expanded(child: AppShimmerBox(height: 56, radius: 18)),
              SizedBox(width: 8),
              Expanded(child: AppShimmerBox(height: 56, radius: 18)),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: AppShimmerBox(height: 38, radius: 12)),
              SizedBox(width: 8),
              Expanded(child: AppShimmerBox(height: 38, radius: 12)),
              SizedBox(width: 8),
              Expanded(child: AppShimmerBox(height: 38, radius: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingActionBar() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        4,
        (_) => const AppShimmerBox(width: 120, height: 44, radius: 16),
      ),
    );
  }

  Widget _buildLoadingSection(String title, {required int cards}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        const SizedBox(height: 10),
        ...List.generate(
          cards,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _ReferralLoadingCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(ReferralProfile profile) {
    final earnings = profile.earnings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173B2E), Color(0xFF245B47), Color(0xFF4C9A7D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332D4F88),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your referral code',
            style: TextStyle(
              color: Color(0xFFD6E4FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            profile.referralCode,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.referralLink,
            style: const TextStyle(color: Color(0xFFD6E4FF), height: 1.45),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _heroStat(
                  title: 'Available',
                  value: _usd(earnings.availableBalance),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroStat(
                  title: 'Pending',
                  value: _usd(earnings.pendingRewards),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroStat(
                  title: 'App Credit',
                  value: _usd(profile.appCreditBalance),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _heroSummary(
                  title: 'Referred users',
                  value: earnings.inspectorsReferred.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroSummary(
                  title: 'Successful purchases',
                  value: earnings.successfulUpgrades.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroSummary(
                  title: 'Total earned',
                  value: _usd(earnings.totalEarned),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD6E4FF),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroSummary({required String title, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFD6E4FF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(ReferralProfile profile) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _actionButton(
          label: 'Copy Link',
          icon: Icons.copy_outlined,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: profile.referralLink));
            if (!mounted) return;
            ErrorHandler.showSnackBar(
              'Referral link copied.',
              isError: false,
              context: context,
            );
          },
        ),
        _actionButton(
          label: 'Share Link',
          icon: Icons.share_outlined,
          filled: true,
          onTap: () => _shareReferralInvite(profile),
        ),
        _actionButton(
          label: _isSubmitting ? 'Working...' : 'To Credit',
          icon: Icons.account_balance_wallet_outlined,
          onTap: _isSubmitting ? null : _convertToCredit,
        ),
        _actionButton(
          label: _isSubmitting ? 'Working...' : 'Cash Payout',
          icon: Icons.payments_outlined,
          onTap: _isSubmitting ? null : _requestCashPayout,
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    final foreground = filled ? Colors.white : const Color(0xFF2D4F88);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF2D4F88) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8E3F5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: Color(0xFF10213F),
      ),
    );
  }

  Widget _buildReferredUserCard(ReferralReferredUser user) {
    final statusColor = user.status == 'active'
        ? const Color(0xFF166534)
        : const Color(0xFFB91C1C);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE7F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.referredName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF10213F),
                      ),
                    ),
                    if (user.referredEmail.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.referredEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  user.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Joined ${_dateText(user.joinedAt)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          Text(
            'First successful purchase ${_dateText(user.upgradedAt)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          if (user.disqualifiedReason.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              user.disqualifiedReason,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniStat('Total', _usd(user.commission.totalCommission)),
              _miniStat('Pending', _usd(user.commission.pendingCommission)),
              _miniStat('Available', _usd(user.commission.availableCommission)),
              _miniStat('Paid out', _usd(user.commission.paidOutCommission)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF10213F),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardLedger(List<ReferralRewardEntry> rewards) {
    if (rewards.isEmpty) return _emptyCard('No reward ledger entries.');

    return Column(
      children: rewards
          .map((reward) {
            final color = switch (reward.status) {
              'available' => const Color(0xFF166534),
              'pending' => const Color(0xFF92400E),
              'paid_out' => const Color(0xFF1D4ED8),
              _ => const Color(0xFF64748B),
            };

            return _ledgerCard(
              title: reward.status.replaceAll('_', ' ').toUpperCase(),
              subtitle:
                  'Created ${_dateText(reward.createdAt)} • Pending until ${_dateText(reward.pendingUntil)}',
              amount: _usd(reward.commissionAmount),
              trailingText: 'Remaining ${_usd(reward.remainingAmount)}',
              accent: color,
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildPayoutLedger(List<ReferralPayoutEntry> payouts) {
    if (payouts.isEmpty) return _emptyCard('No payout requests yet.');

    return Column(
      children: payouts
          .map(
            (payout) => _ledgerCard(
              title: payout.status.toUpperCase(),
              subtitle:
                  'Requested ${_dateText(payout.requestedAt)} • Processed ${_dateText(payout.processedAt)}',
              amount: _usd(payout.amount),
              accent: const Color(0xFF7C3AED),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildConversionLedger(List<ReferralConversionEntry> conversions) {
    if (conversions.isEmpty) return _emptyCard('No conversion records yet.');

    return Column(
      children: conversions
          .map(
            (conversion) => _ledgerCard(
              title: 'APP CREDIT',
              subtitle:
                  'Converted ${_dateText(conversion.convertedAt)} • ${_usd(conversion.creditBalanceBefore)} -> ${_usd(conversion.creditBalanceAfter)}',
              amount: _usd(conversion.amount),
              accent: const Color(0xFF0F766E),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _ledgerCard({
    required String title,
    required String subtitle,
    required String amount,
    required Color accent,
    String? trailingText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE7F7)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 52,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10213F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(fontWeight: FontWeight.w900, color: accent),
              ),
              if (trailingText != null) ...[
                const SizedBox(height: 4),
                Text(
                  trailingText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE7F7)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _usd(double amount) {
    final hasFraction = amount % 1 != 0;
    return '\$${amount.toStringAsFixed(hasFraction ? 2 : 0)}';
  }

  String _dateText(DateTime? date) {
    if (date == null) return 'Not yet';
    final local = date.toLocal();
    final month = _monthName(local.month);
    return '$month ${local.day}, ${local.year}';
  }

  String _monthName(int month) {
    const months = [
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
    return months[(month - 1).clamp(0, 11)];
  }
}

class _ReferralLoadingCard extends StatelessWidget {
  const _ReferralLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE7F7)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: AppShimmerBox(width: 140, height: 18, radius: 6)),
              SizedBox(width: 12),
              AppShimmerBox(width: 72, height: 26, radius: 999),
            ],
          ),
          SizedBox(height: 10),
          AppShimmerBox(width: 170, height: 12, radius: 6),
          SizedBox(height: 8),
          AppShimmerBox(width: 210, height: 12, radius: 6),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: AppShimmerBox(height: 44, radius: 14)),
              SizedBox(width: 8),
              Expanded(child: AppShimmerBox(height: 44, radius: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
