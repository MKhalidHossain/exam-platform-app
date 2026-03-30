import '../models/referral_model.dart';

String buildReferralShareMessage(ReferralProfile profile) {
  final customMessage = profile.program?.shareMessage.trim() ?? '';
  final referralLink = profile.referralLink.trim();
  final referralCode = profile.referralCode.trim();
  final referralDiscountPercent =
      profile.program?.newUserDiscountPercent ??
      profile.program?.referrerCommissionPercent ??
      10;

  if (referralLink.isEmpty) {
    return '';
  }

  if (customMessage.isNotEmpty) {
    return customMessage.contains(referralLink)
        ? customMessage
        : '$customMessage\n\n$referralLink';
  }

  final codeLine = referralCode.isEmpty
      ? 'Open the invite link and the referral will be attached automatically.'
      : 'Your referral code will be applied automatically: $referralCode';

  return [
    'Join EJ exam prep with my referral link.',
    'You will get $referralDiscountPercent% off your first Professional Plan purchase after you register.',
    if (codeLine.isNotEmpty) codeLine,
    'If the app is not installed yet, install it first and then open the same invite again to complete signup with the referral attached.',
    referralLink,
  ].join('\n\n');
}
