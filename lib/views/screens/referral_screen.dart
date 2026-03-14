import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error/error_handler.dart';
import '../../models/referral_model.dart';
import '../../services/referral_service.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/gradient_background.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final ReferralService _referralService = ReferralService();

  bool _isLoading = true;
  bool _isActionLoading = false;
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
    final usersRes = await _referralService.getMyReferredUsers(page: 1, limit: 50);
    final ledgerRes = await _referralService.getMyReferralLedger(page: 1, limit: 50);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        useImage: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: const Color(0xFF2D4F88),
                    ),
                    const Expanded(
                      child: Text(
                        'Referral',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF2D4F88),
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loadAll,
                      icon: const Icon(Icons.refresh_rounded),
                      color: const Color(0xFF2D4F88),
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
    if (_isLoading && _profile == null) {
      return const Center(child: AppShimmerCircle(size: 40));
    }

    if (_error != null && _profile == null) {
      return Center(
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
      );
    }

    final profile = _profile;
    if (profile == null) {
      return const SizedBox.shrink();
    }

    final program = profile.program;
    final users = _usersData?.users ?? const <ReferralReferredUser>[];
    final ledger = _ledgerData;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (program != null) ...[
            _buildProgramIntro(program),
            const SizedBox(height: 12),
          ],
          _buildReferralIdentity(profile),
          const SizedBox(height: 10),
          _buildReferralActions(profile),
          const SizedBox(height: 12),
          _buildSummarySection(profile),
          const SizedBox(height: 14),
          _buildSectionTitle('Referred Users (${users.length})'),
          const SizedBox(height: 8),
          if (users.isEmpty)
            _emptyCard('No referred users yet.')
          else
            ...users.map(_buildReferredUserCard),
          const SizedBox(height: 12),
          _buildSectionTitle('Reward Ledger'),
          const SizedBox(height: 8),
          _buildRewardLedger(ledger?.rewards ?? const []),
          const SizedBox(height: 12),
          _buildSectionTitle('Payout Requests'),
          const SizedBox(height: 8),
          _buildPayoutLedger(ledger?.payouts ?? const []),
          const SizedBox(height: 12),
          _buildSectionTitle('Credit Conversions'),
          const SizedBox(height: 8),
          _buildConversionLedger(ledger?.conversions ?? const []),
        ],
      ),
    );
  }

  Widget _buildProgramIntro(ReferralProgram program) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCFDAF7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            program.headline,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A8A),
            ),
          ),
          if (program.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              program.description,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF334155),
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniInfo(
                'Referrer Reward',
                '${program.referrerCommissionPercent}% commission',
              ),
              _miniInfo(
                'New User Reward',
                '${program.newUserDiscountPercent}% discount',
              ),
              _miniInfo(
                'Pending Period',
                '${program.pendingPeriodDays} days',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralActions(ReferralProfile profile) {
    final fallbackCanConvert = profile.earnings.availableBalance > 0;
    final fallbackCanPayout = profile.earnings.availableBalance >= 100;
    final canConvert = profile.actions.canConvertToAppCredit || fallbackCanConvert;
    final canPayout = profile.actions.canRequestCashPayout || fallbackCanPayout;
    final minCash = profile.actions.minimumCashPayout > 0
        ? profile.actions.minimumCashPayout
        : 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Earnings Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isActionLoading || !canConvert)
                  ? null
                  : () => _convertAvailableToCredit(profile),
              icon: _isActionLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Convert to App Credit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D4F88),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_isActionLoading || !canPayout)
                  ? null
                  : () => _requestCashPayout(profile),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Request Cash Payout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2D4F88),
                side: const BorderSide(color: Color(0xFF2D4F88)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Minimum available balance for cash payout is ${_usd(minCash)}.',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralIdentity(ReferralProfile profile) {
    final channels = profile.program?.shareChannels ?? const <String>[];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCFDAF7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Referral Program',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            'Code: ${profile.referralCode}',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            profile.referralLink,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _copyReferralLink(profile),
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('Copy Referral Link'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D4F88),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _shareByChannel('share', profile),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2D4F88),
                  side: const BorderSide(color: Color(0xFF2D4F88)),
                ),
              ),
              if (channels.contains('whatsapp'))
                _shareChannelButton('WhatsApp', () => _shareByChannel('whatsapp', profile)),
              if (channels.contains('linkedin'))
                _shareChannelButton('LinkedIn', () => _shareByChannel('linkedin', profile)),
              if (channels.contains('sms'))
                _shareChannelButton('Text Message', () => _shareByChannel('sms', profile)),
              if (channels.contains('facebook'))
                _shareChannelButton('Facebook', () => _shareByChannel('facebook', profile)),
              if (channels.contains('instagram'))
                _shareChannelButton('Instagram', () => _shareByChannel('instagram', profile)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shareChannelButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2D4F88),
        side: const BorderSide(color: Color(0xFFC8D7FA)),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
  }

  Future<void> _copyReferralLink(ReferralProfile profile) async {
    await Clipboard.setData(ClipboardData(text: profile.referralLink));
    if (!mounted) return;
    ErrorHandler.showSnackBar(
      'Referral link copied.',
      isError: false,
      context: context,
    );
  }

  String _buildShareMessage(ReferralProfile profile) {
    final configured = profile.program?.shareMessage.trim() ?? '';
    if (configured.isNotEmpty) return configured;

    return [
      'I have been using Inspectors Path to practice for API certification exams.',
      '',
      'If you are studying for API exams, this app is worth checking out.',
      '',
      'Use my referral code and get 10% off the Professional Plan.',
      '',
      'Referral Code: ${profile.referralCode}',
      'Referral Link: ${profile.referralLink}',
    ].join('\n');
  }

  Future<void> _shareByChannel(String channel, ReferralProfile profile) async {
    final message = _buildShareMessage(profile);
    final encodedMessage = Uri.encodeComponent(message);
    final encodedLink = Uri.encodeComponent(profile.referralLink);

    if (channel == 'whatsapp') {
      final uri = Uri.parse('https://wa.me/?text=$encodedMessage');
      final opened = await _tryOpenExternalUrl(uri);
      if (!opened) await Share.share(message);
      return;
    }

    if (channel == 'linkedin') {
      final uri = Uri.parse(
        'https://www.linkedin.com/sharing/share-offsite/?url=$encodedLink',
      );
      final opened = await _tryOpenExternalUrl(uri);
      if (!opened) await Share.share(message);
      return;
    }

    if (channel == 'sms') {
      final uri = Uri.parse('sms:?body=$encodedMessage');
      final opened = await _tryOpenExternalUrl(uri);
      if (!opened) await Share.share(message);
      return;
    }

    if (channel == 'facebook') {
      final uri = Uri.parse(
        'https://www.facebook.com/sharer/sharer.php?u=$encodedLink',
      );
      final opened = await _tryOpenExternalUrl(uri);
      if (!opened) await Share.share(message);
      return;
    }

    if (channel == 'instagram') {
      await Share.share(message);
      return;
    }

    await Share.share(message, subject: 'Inspectors Path referral');
  }

  Future<bool> _tryOpenExternalUrl(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _convertAvailableToCredit(ReferralProfile profile) async {
    final available = profile.earnings.availableBalance;
    if (available <= 0) {
      ErrorHandler.showSnackBar(
        'No available referral balance to convert.',
        isError: true,
        context: context,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to App Credit'),
        content: Text(
          'Convert your available balance (${_usd(available)}) to app credit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    final res = await _referralService.convertToAppCredit();
    if (!mounted) return;
    setState(() => _isActionLoading = false);

    if (!res.success) {
      ErrorHandler.showFromResponse(
        res,
        context: context,
        failureFallback: 'Failed to convert referral balance.',
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

  Future<void> _requestCashPayout(ReferralProfile profile) async {
    final minBalance = profile.actions.minimumCashPayout > 0
        ? profile.actions.minimumCashPayout
        : 100;
    final available = profile.earnings.availableBalance;
    if (available < minBalance) {
      ErrorHandler.showSnackBar(
        'Minimum ${_usd(minBalance)} available balance is required for payout.',
        isError: true,
        context: context,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Cash Payout'),
        content: Text(
          'Request cash payout for your available balance (${_usd(available)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Request'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    final res = await _referralService.requestCashPayout();
    if (!mounted) return;
    setState(() => _isActionLoading = false);

    if (!res.success) {
      ErrorHandler.showFromResponse(
        res,
        context: context,
        failureFallback: 'Failed to request cash payout.',
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

  Widget _buildSummarySection(ReferralProfile profile) {
    final earnings = profile.earnings;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'Inspectors Referred',
                value: earnings.inspectorsReferred.toString(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                title: 'Successful Upgrades',
                value: earnings.successfulUpgrades.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'Total Earned',
                value: _usd(earnings.totalEarned),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                title: 'Paid Out',
                value: _usd(earnings.paidOut),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'Available Balance',
                value: _usd(earnings.availableBalance),
                valueColor: const Color(0xFF166534),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                title: 'Pending Rewards',
                value: _usd(earnings.pendingRewards),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _summaryCard(
          title: 'App Credit Balance',
          value: _usd(profile.appCreditBalance),
          valueColor: const Color(0xFF1D4ED8),
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    Color valueColor = const Color(0xFF0F172A),
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferredUserCard(ReferralReferredUser user) {
    final statusColor = user.status == 'active'
        ? const Color(0xFF166534)
        : const Color(0xFFB91C1C);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  user.referredName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  user.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (user.referredEmail.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              user.referredEmail,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Joined: ${_dateText(user.joinedAt)} | Upgraded: ${_dateText(user.upgradedAt)}',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          if (user.disqualifiedReason.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: ${user.disqualifiedReason}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniInfo('Total', _usd(user.commission.totalCommission)),
              _miniInfo('Pending', _usd(user.commission.pendingCommission)),
              _miniInfo('Available', _usd(user.commission.availableCommission)),
              _miniInfo('Paid Out', _usd(user.commission.paidOutCommission)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardLedger(List<ReferralRewardEntry> rewards) {
    if (rewards.isEmpty) return _emptyCard('No reward ledger entries.');

    return Column(
      children: rewards
          .map(
            (reward) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: ${reward.status}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Created: ${_dateText(reward.createdAt)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          'Pending until: ${_dateText(reward.pendingUntil)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _usd(reward.commissionAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Remaining ${_usd(reward.remainingAmount)}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildPayoutLedger(List<ReferralPayoutEntry> payouts) {
    if (payouts.isEmpty) return _emptyCard('No payout requests yet.');

    return Column(
      children: payouts
          .map(
            (payout) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: ${payout.status}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Requested: ${_dateText(payout.requestedAt)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          'Processed: ${_dateText(payout.processedAt)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _usd(payout.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
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
            (conversion) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Converted to App Credit',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        _usd(conversion.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Converted: ${_dateText(conversion.convertedAt)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Credit: ${_usd(conversion.creditBalanceBefore)} -> ${_usd(conversion.creditBalanceAfter)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E3A8A),
      ),
    );
  }

  Widget _miniInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  String _usd(double amount) {
    final hasFraction = amount % 1 != 0;
    return '\$${amount.toStringAsFixed(hasFraction ? 2 : 0)}';
  }

  String _dateText(DateTime? value) {
    if (value == null) return '--';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }
}
