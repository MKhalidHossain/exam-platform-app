class PaymentSuccessDetails {
  final String purchaseType;
  final String title;
  final num amountPaid;
  final String currency;
  final String? billingCycleLabel;
  final DateTime? nextBillingDate;
  final String? paymentMethodLabel;
  final String? receiptNumber;
  final String? transactionReference;
  final DateTime? paidAt;
  final String? provider;
  final DateTime? subscriptionStartedAt;
  final String? status;

  const PaymentSuccessDetails({
    required this.purchaseType,
    required this.title,
    required this.amountPaid,
    required this.currency,
    this.billingCycleLabel,
    this.nextBillingDate,
    this.paymentMethodLabel,
    this.receiptNumber,
    this.transactionReference,
    this.paidAt,
    this.provider,
    this.subscriptionStartedAt,
    this.status,
  });

  factory PaymentSuccessDetails.fromJson(Map<String, dynamic> json) {
    return PaymentSuccessDetails(
      purchaseType:
          (json['purchaseType']?.toString().trim().toLowerCase() ?? 'exam')
              .isEmpty
          ? 'exam'
          : json['purchaseType'].toString().trim().toLowerCase(),
      title:
          json['title']?.toString() ??
          json['planName']?.toString() ??
          json['itemName']?.toString() ??
          'Purchase',
      amountPaid:
          _parseNum(json['amountPaid']) ??
          _parseNum(json['amount']) ??
          _parseNum(json['totalAmount']) ??
          0,
      currency: (json['currency']?.toString() ?? 'USD').toUpperCase(),
      billingCycleLabel: _normalizeText(
        json['billingCycleLabel'] ?? json['billingCycle'],
      ),
      nextBillingDate: _parseDateTime(
        json['nextBillingDate'] ?? json['subscriptionExpiresAt'],
      ),
      paymentMethodLabel: _normalizeText(json['paymentMethodLabel']),
      receiptNumber: _normalizeText(json['receiptNumber']),
      transactionReference: _normalizeText(json['transactionReference']),
      paidAt: _parseDateTime(json['paidAt'] ?? json['purchasedAt']),
      provider: _normalizeText(json['provider']),
      subscriptionStartedAt: _parseDateTime(
        json['subscriptionStartedAt'] ?? json['startedAt'],
      ),
      status: _normalizeText(json['status'] ?? json['subscriptionStatus']),
    );
  }

  factory PaymentSuccessDetails.fromPayload(
    Map<String, dynamic>? payload, {
    required String purchaseType,
    required num fallbackAmount,
    required String fallbackTitle,
    String fallbackCurrency = 'USD',
    String? fallbackBillingCycleLabel,
    DateTime? fallbackNextBillingDate,
    String? fallbackPaymentMethodLabel,
    String? fallbackReceiptNumber,
    String? fallbackTransactionReference,
    DateTime? fallbackPaidAt,
    String? fallbackProvider,
    DateTime? fallbackSubscriptionStartedAt,
    String? fallbackStatus,
  }) {
    final dynamic rawPaymentSummary = payload?['paymentSummary'];
    if (rawPaymentSummary is Map<String, dynamic>) {
      return PaymentSuccessDetails.fromJson(rawPaymentSummary);
    }
    if (rawPaymentSummary is Map) {
      return PaymentSuccessDetails.fromJson(
        Map<String, dynamic>.from(rawPaymentSummary),
      );
    }

    final dynamic rawBreakdown = payload?['pricingBreakdown'];
    final Map<String, dynamic>? pricingBreakdown = rawBreakdown is Map
        ? Map<String, dynamic>.from(rawBreakdown)
        : null;

    return PaymentSuccessDetails(
      purchaseType: purchaseType.trim().toLowerCase(),
      title: fallbackTitle,
      amountPaid:
          _parseNum(payload?['amount']) ??
          _parseNum(pricingBreakdown?['totalAmount']) ??
          fallbackAmount,
      currency: (payload?['currency']?.toString() ?? fallbackCurrency)
          .toUpperCase(),
      billingCycleLabel:
          _normalizeText(payload?['billingCycleLabel']) ??
          fallbackBillingCycleLabel,
      nextBillingDate:
          _parseDateTime(
            payload?['nextBillingDate'] ?? payload?['subscriptionExpiresAt'],
          ) ??
          fallbackNextBillingDate,
      paymentMethodLabel:
          _normalizeText(payload?['paymentMethodLabel']) ??
          fallbackPaymentMethodLabel,
      receiptNumber:
          _normalizeText(payload?['receiptNumber']) ?? fallbackReceiptNumber,
      transactionReference:
          _normalizeText(payload?['transactionReference']) ??
          fallbackTransactionReference,
      paidAt:
          _parseDateTime(payload?['paidAt'] ?? payload?['purchasedAt']) ??
          fallbackPaidAt,
      provider: _normalizeText(payload?['provider']) ?? fallbackProvider,
      subscriptionStartedAt:
          _parseDateTime(
            payload?['subscriptionStartedAt'] ?? payload?['startedAt'],
          ) ??
          fallbackSubscriptionStartedAt,
      status:
          _normalizeText(
            payload?['status'] ?? payload?['subscriptionStatus'],
          ) ??
          fallbackStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'purchaseType': purchaseType,
      'title': title,
      'amountPaid': amountPaid,
      'currency': currency,
      'billingCycleLabel': billingCycleLabel,
      'nextBillingDate': nextBillingDate?.toIso8601String(),
      'paymentMethodLabel': paymentMethodLabel,
      'receiptNumber': receiptNumber,
      'transactionReference': transactionReference,
      'paidAt': paidAt?.toIso8601String(),
      'provider': provider,
      'subscriptionStartedAt': subscriptionStartedAt?.toIso8601String(),
      'status': status,
    };
  }

  static num? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static String? _normalizeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
