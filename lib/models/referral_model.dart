class ReferralProfile {
  final String referralCode;
  final String referralLink;
  final double appCreditBalance;
  final ReferralEarnings earnings;
  final ReferralActions actions;
  final ReferralProgram? program;

  const ReferralProfile({
    required this.referralCode,
    required this.referralLink,
    required this.appCreditBalance,
    required this.earnings,
    this.actions = const ReferralActions(),
    this.program,
  });

  factory ReferralProfile.fromJson(Map<String, dynamic> json) {
    return ReferralProfile(
      referralCode: _stringValue(json['referralCode']),
      referralLink: _stringValue(json['referralLink']),
      appCreditBalance: _doubleValue(json['appCreditBalance']),
      earnings: ReferralEarnings.fromJson(_mapValue(json['earnings'])),
      actions: ReferralActions.fromJson(_mapValue(json['actions'])),
      program: json['program'] != null
          ? ReferralProgram.fromJson(_mapValue(json['program']))
          : null,
    );
  }
}

class ReferralProgram {
  final String headline;
  final String description;
  final int referrerCommissionPercent;
  final int newUserDiscountPercent;
  final int pendingPeriodDays;
  final double minimumCashPayout;
  final List<String> shareChannels;
  final String shareMessage;

  const ReferralProgram({
    required this.headline,
    required this.description,
    required this.referrerCommissionPercent,
    required this.newUserDiscountPercent,
    required this.pendingPeriodDays,
    required this.minimumCashPayout,
    required this.shareChannels,
    required this.shareMessage,
  });

  factory ReferralProgram.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['shareChannels'];
    final channels = rawChannels is List
        ? rawChannels.map((e) => _stringValue(e)).toList(growable: false)
        : const <String>[];

    return ReferralProgram(
      headline: _stringValue(
        json['headline'],
        fallback: 'Help Your Friend Pass Their Certification',
      ),
      description: _stringValue(json['description']),
      referrerCommissionPercent:
          _intValue(json['referrerCommissionPercent'], fallback: 10),
      newUserDiscountPercent:
          _intValue(json['newUserDiscountPercent'], fallback: 10),
      pendingPeriodDays: _intValue(json['pendingPeriodDays'], fallback: 7),
      minimumCashPayout: _doubleValue(json['minimumCashPayout'], fallback: 100),
      shareChannels: channels,
      shareMessage: _stringValue(json['shareMessage']),
    );
  }
}

class ReferralActions {
  final bool canConvertToAppCredit;
  final bool canRequestCashPayout;
  final double minimumCashPayout;

  const ReferralActions({
    this.canConvertToAppCredit = false,
    this.canRequestCashPayout = false,
    this.minimumCashPayout = 100,
  });

  factory ReferralActions.fromJson(Map<String, dynamic> json) {
    return ReferralActions(
      canConvertToAppCredit: _boolValue(json['canConvertToAppCredit']),
      canRequestCashPayout: _boolValue(json['canRequestCashPayout']),
      minimumCashPayout: _doubleValue(json['minimumCashPayout'], fallback: 100),
    );
  }
}

class ReferralPublicCode {
  final String referralCode;
  final String referralLink;
  final String referrerName;
  final double discountPercent;

  const ReferralPublicCode({
    required this.referralCode,
    required this.referralLink,
    required this.referrerName,
    required this.discountPercent,
  });

  factory ReferralPublicCode.fromJson(Map<String, dynamic> json) {
    return ReferralPublicCode(
      referralCode: _stringValue(json['referralCode']),
      referralLink: _stringValue(json['referralLink']),
      referrerName: _stringValue(json['referrerName']),
      discountPercent: _doubleValue(json['discountPercent']),
    );
  }
}

class ReferralEarnings {
  final int inspectorsReferred;
  final int successfulUpgrades;
  final double totalEarned;
  final double paidOut;
  final double availableBalance;
  final double pendingRewards;

  const ReferralEarnings({
    required this.inspectorsReferred,
    required this.successfulUpgrades,
    required this.totalEarned,
    required this.paidOut,
    required this.availableBalance,
    required this.pendingRewards,
  });

  factory ReferralEarnings.fromJson(Map<String, dynamic> json) {
    return ReferralEarnings(
      inspectorsReferred: _intValue(json['inspectorsReferred']),
      successfulUpgrades: _intValue(json['successfulUpgrades']),
      totalEarned: _doubleValue(json['totalEarned']),
      paidOut: _doubleValue(json['paidOut']),
      availableBalance: _doubleValue(json['availableBalance']),
      pendingRewards: _doubleValue(json['pendingRewards']),
    );
  }
}

class ReferralMeta {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const ReferralMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory ReferralMeta.fromJson(Map<String, dynamic> json) {
    return ReferralMeta(
      page: _intValue(json['page'], fallback: 1),
      limit: _intValue(json['limit'], fallback: 10),
      total: _intValue(json['total']),
      totalPages: _intValue(json['totalPages'], fallback: 1),
    );
  }

  static const empty = ReferralMeta(
    page: 1,
    limit: 10,
    total: 0,
    totalPages: 1,
  );
}

class ReferralReferredUsersData {
  final List<ReferralReferredUser> users;
  final ReferralMeta meta;

  const ReferralReferredUsersData({required this.users, required this.meta});

  factory ReferralReferredUsersData.fromJson(Map<String, dynamic> json) {
    final rawUsers = json['users'];
    final users = rawUsers is List
        ? rawUsers
              .map((e) => ReferralReferredUser.fromJson(_mapValue(e)))
              .toList(growable: false)
        : const <ReferralReferredUser>[];

    return ReferralReferredUsersData(
      users: users,
      meta: ReferralMeta.fromJson(_mapValue(json['meta'])),
    );
  }
}

class ReferralReferredUser {
  final String relationshipId;
  final String referredUserId;
  final String referredName;
  final String referredEmail;
  final DateTime? joinedAt;
  final DateTime? upgradedAt;
  final String status;
  final String disqualifiedReason;
  final ReferralCommission commission;

  const ReferralReferredUser({
    required this.relationshipId,
    required this.referredUserId,
    required this.referredName,
    required this.referredEmail,
    required this.joinedAt,
    required this.upgradedAt,
    required this.status,
    required this.disqualifiedReason,
    required this.commission,
  });

  factory ReferralReferredUser.fromJson(Map<String, dynamic> json) {
    return ReferralReferredUser(
      relationshipId: _stringValue(json['relationshipId']),
      referredUserId: _stringValue(json['referredUserId']),
      referredName: _stringValue(json['referredName'], fallback: 'User'),
      referredEmail: _stringValue(json['referredEmail']),
      joinedAt: _dateValue(json['joinedAt']),
      upgradedAt: _dateValue(json['upgradedAt']),
      status: _stringValue(json['status'], fallback: 'active'),
      disqualifiedReason: _stringValue(json['disqualifiedReason']),
      commission: ReferralCommission.fromJson(_mapValue(json['commission'])),
    );
  }
}

class ReferralCommission {
  final double totalCommission;
  final double pendingCommission;
  final double availableCommission;
  final double paidOutCommission;

  const ReferralCommission({
    required this.totalCommission,
    required this.pendingCommission,
    required this.availableCommission,
    required this.paidOutCommission,
  });

  factory ReferralCommission.fromJson(Map<String, dynamic> json) {
    return ReferralCommission(
      totalCommission: _doubleValue(json['totalCommission']),
      pendingCommission: _doubleValue(json['pendingCommission']),
      availableCommission: _doubleValue(json['availableCommission']),
      paidOutCommission: _doubleValue(json['paidOutCommission']),
    );
  }
}

class ReferralLedgerData {
  final List<ReferralRewardEntry> rewards;
  final List<ReferralPayoutEntry> payouts;
  final List<ReferralConversionEntry> conversions;
  final ReferralEarnings? earnings;
  final ReferralActions actions;
  final ReferralMeta meta;

  const ReferralLedgerData({
    required this.rewards,
    required this.payouts,
    required this.conversions,
    this.earnings,
    this.actions = const ReferralActions(),
    required this.meta,
  });

  factory ReferralLedgerData.fromJson(Map<String, dynamic> json) {
    final rawRewards = json['rewards'];
    final rewards = rawRewards is List
        ? rawRewards
              .map((e) => ReferralRewardEntry.fromJson(_mapValue(e)))
              .toList(growable: false)
        : const <ReferralRewardEntry>[];

    final rawPayouts = json['payouts'];
    final payouts = rawPayouts is List
        ? rawPayouts
              .map((e) => ReferralPayoutEntry.fromJson(_mapValue(e)))
              .toList(growable: false)
        : const <ReferralPayoutEntry>[];

    final rawConversions = json['conversions'];
    final conversions = rawConversions is List
        ? rawConversions
              .map((e) => ReferralConversionEntry.fromJson(_mapValue(e)))
              .toList(growable: false)
        : const <ReferralConversionEntry>[];

    return ReferralLedgerData(
      rewards: rewards,
      payouts: payouts,
      conversions: conversions,
      earnings: json['earnings'] != null
          ? ReferralEarnings.fromJson(_mapValue(json['earnings']))
          : null,
      actions: ReferralActions.fromJson(_mapValue(json['actions'])),
      meta: ReferralMeta.fromJson(_mapValue(json['meta'])),
    );
  }
}

class ReferralRewardEntry {
  final String id;
  final String status;
  final double commissionAmount;
  final double remainingAmount;
  final String currency;
  final DateTime? pendingUntil;
  final DateTime? createdAt;
  final DateTime? availableAt;

  const ReferralRewardEntry({
    required this.id,
    required this.status,
    required this.commissionAmount,
    required this.remainingAmount,
    required this.currency,
    required this.pendingUntil,
    required this.createdAt,
    required this.availableAt,
  });

  factory ReferralRewardEntry.fromJson(Map<String, dynamic> json) {
    return ReferralRewardEntry(
      id: _stringValue(json['_id']),
      status: _stringValue(json['status'], fallback: 'pending'),
      commissionAmount: _doubleValue(json['commissionAmount']),
      remainingAmount: _doubleValue(json['remainingAmount']),
      currency: _stringValue(json['currency'], fallback: 'USD'),
      pendingUntil: _dateValue(json['pendingUntil']),
      createdAt: _dateValue(json['createdAt']),
      availableAt: _dateValue(json['availableAt']),
    );
  }
}

class ReferralPayoutEntry {
  final String id;
  final double amount;
  final String currency;
  final String status;
  final DateTime? requestedAt;
  final DateTime? processedAt;

  const ReferralPayoutEntry({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.requestedAt,
    required this.processedAt,
  });

  factory ReferralPayoutEntry.fromJson(Map<String, dynamic> json) {
    return ReferralPayoutEntry(
      id: _stringValue(json['_id']),
      amount: _doubleValue(json['amount']),
      currency: _stringValue(json['currency'], fallback: 'USD'),
      status: _stringValue(json['status'], fallback: 'pending'),
      requestedAt: _dateValue(json['requestedAt']),
      processedAt: _dateValue(json['processedAt']),
    );
  }
}

class ReferralConversionEntry {
  final String id;
  final double amount;
  final String currency;
  final double creditBalanceBefore;
  final double creditBalanceAfter;
  final DateTime? convertedAt;

  const ReferralConversionEntry({
    required this.id,
    required this.amount,
    required this.currency,
    required this.creditBalanceBefore,
    required this.creditBalanceAfter,
    required this.convertedAt,
  });

  factory ReferralConversionEntry.fromJson(Map<String, dynamic> json) {
    return ReferralConversionEntry(
      id: _stringValue(json['_id']),
      amount: _doubleValue(json['amount']),
      currency: _stringValue(json['currency'], fallback: 'USD'),
      creditBalanceBefore: _doubleValue(json['creditBalanceBefore']),
      creditBalanceAfter: _doubleValue(json['creditBalanceAfter']),
      convertedAt: _dateValue(json['convertedAt']),
    );
  }
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _stringValue(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

int _intValue(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

double _doubleValue(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

bool _boolValue(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

DateTime? _dateValue(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
