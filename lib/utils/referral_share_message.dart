import '../models/referral_model.dart';

String buildReferralShareMessage(ReferralProfile profile) {
  final customMessage = profile.program?.shareMessage.trim() ?? '';
  final referralLink = profile.referralLink.trim();
  if (customMessage.isNotEmpty && referralLink.isNotEmpty) {
    return '$customMessage\n\n$referralLink';
  }
  if (customMessage.isNotEmpty) {
    return customMessage;
  }
  if (referralLink.isEmpty) {
    return '';
  }

  final referralCode = profile.referralCode.trim();
  final codeLine = referralCode.isEmpty
      ? ''
      : 'Use my referral code $referralCode when you upgrade to the Professional Plan.';

  return [
    'Upgrade to the EJ Professional Plan and unlock full inspection exam access.',
    if (codeLine.isNotEmpty) codeLine,
    referralLink,
  ].join('\n\n');
}
