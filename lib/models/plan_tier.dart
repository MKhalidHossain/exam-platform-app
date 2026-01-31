enum PlanTier { starter, professional }

PlanTier planTierFromSubscription(String? tier) {
  final normalized = tier?.toLowerCase().trim();
  if (normalized == 'professional' || normalized == 'pro') {
    return PlanTier.professional;
  }
  return PlanTier.starter;
}

extension PlanTierX on PlanTier {
  String get label => this == PlanTier.professional ? 'Professional' : 'Starter';
  String get userLabel =>
      this == PlanTier.professional ? 'Professional User' : 'Starter User';
}
