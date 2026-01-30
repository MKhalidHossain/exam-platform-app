import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import '../widgets/gradient_background.dart';
import '../../controllers/user_controller.dart';
import '../../models/plan_tier.dart';
import '../../services/exam_service.dart';
import '../../services/api_service.dart';
import '../../models/exam_model.dart';
import '../../models/professional_plan_model.dart';

class SubscribeScreen extends StatefulWidget {
  const SubscribeScreen({super.key});

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  final ExamService _examService = ExamService();
  final ApiService _apiService = ApiService();
  late final UserController _userController;
  bool _isPaymentLoading = false;

  ProfessionalPlanModel? _professionalPlan;
  bool _planLoading = true;
  String? _planError;

  @override
  void initState() {
    super.initState();
    _loadProfessionalPlan();
  }

  Future<void> _loadProfessionalPlan() async {
    setState(() {
      _planLoading = true;
      _planError = null;
    });
    final res = await _apiService.getProfessionalPlan();
    if (!mounted) return;
    setState(() {
      _planLoading = false;
      if (res.success && res.data != null) {
        _professionalPlan = res.data;
        _planError = null;
      } else {
        _planError = res.message ?? 'Failed to load plan';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _userController = Get.isRegistered<UserController>()
        ? Get.find<UserController>()
        : Get.put(UserController());
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentPlan = _userController.planTier.value;

      return Scaffold(
        body: GradientBackground(
          useImage: true,
          child: SafeArea(
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.pop(),
                        color: const Color(0xFF2D4F88),
                      ),
                      const Expanded(
                        child: Text(
                          'Unlock your exam access',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D4F88),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      children: [
                        // Starter Plan Card
                        _buildPlanCard(
                          planTier: PlanTier.starter,
                          isActive: currentPlan == PlanTier.starter,
                          onUpgrade: currentPlan == PlanTier.starter
                              ? () {
                                  // Handle upgrade to professional
                                  _handleUpgrade(PlanTier.professional);
                                }
                              : null,
                        ),
                        const SizedBox(height: 24),
                        // Professional Plan Card
                        _buildPlanCard(
                          planTier: PlanTier.professional,
                          isActive: currentPlan == PlanTier.professional,
                          onUpgrade:
                              (currentPlan == PlanTier.starter && !_isPaymentLoading)
                                  ? () {
                                      _openUnlockExamDialog();
                                    }
                                  : null,
                        ),
                        if (_isPaymentLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text('Processing payment...'),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _handleUpgrade(PlanTier planTier) {
    // Handle upgrade logic here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Upgrading to ${planTier == PlanTier.professional ? 'Professional' : 'Starter'} plan...'),
        backgroundColor: Colors.green,
      ),
    );
    // TODO: Implement actual upgrade API call
  }

  Future<void> _openUnlockExamDialog() async {
    final selectedIds = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UnlockExamDialog(
        examService: _examService,
        maxSelect: 1,
      ),
    );

    if (!mounted) return;
    if (selectedIds == null || selectedIds.isEmpty) return;

    final examId = selectedIds.first;
    await _payWithStripe(examId);
  }

  /// Stripe-only flow: create intent → PaymentSheet → confirm backend
  Future<void> _payWithStripe(String examId) async {
    setState(() => _isPaymentLoading = true);

    try {
      // 1. Create Payment Intent on backend
      final createRes = await _apiService.createExamStripePaymentIntent(examId);
      if (!mounted) return;
      if (!createRes.success || createRes.data == null) {
        setState(() => _isPaymentLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(createRes.message ?? 'Failed to create payment'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final clientSecret = createRes.data!['clientSecret'] as String?;
      final paymentIntentId = createRes.data!['paymentIntentId'] as String?;
      if (clientSecret == null || clientSecret.isEmpty || paymentIntentId == null) {
        setState(() => _isPaymentLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid payment response'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 2. Init and present Stripe Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'EJ Exam Access',
          returnURL: 'flutterstripe://redirect',
        ),
      );
      if (!mounted) return;

      await Stripe.instance.presentPaymentSheet();
      if (!mounted) return;

      // 3. User completed payment in sheet → confirm on backend
      final confirmRes = await _apiService.confirmExamStripePayment(examId, paymentIntentId);
      if (!mounted) return;
      setState(() => _isPaymentLoading = false);

      if (confirmRes.success) {
        await _userController.applyProfessionalUpgrade(examId: examId);
        await _userController.refreshProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(confirmRes.message ?? 'Exam unlocked successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(confirmRes.message ?? 'Failed to confirm payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() => _isPaymentLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.error.message ?? 'Stripe error'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPaymentLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPlanCard({
    required PlanTier planTier,
    required bool isActive,
    ProfessionalPlanModel? professionalPlan,
    VoidCallback? onUpgrade,
  }) {
    final bool isStarter = planTier == PlanTier.starter;
    final plan = professionalPlan;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(
                color: const Color(0xFF2D4F88),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isStarter
                      ? const Color(0xFF2D4F88)
                      : const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  isStarter
                      ? 'assets/icons/starter_plan.png'
                      : 'assets/icons/professional_plan.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to icon if image fails to load
                    return Icon(
                      isStarter ? Icons.star : Icons.bolt,
                      color: Colors.white,
                      size: 24,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isStarter ? 'Starter Plan' : (plan?.name ?? 'Professional Plan'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isStarter) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Popular',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isStarter) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Free',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/forever',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan?.priceFormatted ?? '\$180.00',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/${plan?.interval.label ?? '3 months'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Container(
            height: 1,
            color: Colors.grey[200],
          ),
          const SizedBox(height: 20),
          Text(
            isStarter
                ? 'What\'s Included in Your Plan'
                : (plan?.description ?? 'What\'s Included in Your Plan'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          ..._buildFeaturesList(isStarter, professionalPlan: plan),
          const SizedBox(height: 24),
          // Free Plan Button
          if (isStarter)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: isActive
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        side: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Your Current Plan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: onUpgrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.grey[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Free Plan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            )
          // Professional Paid Plan Button
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: isActive
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        side: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Your Current Plan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: onUpgrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D4F88),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        plan != null ? 'Subscribe - ${plan.priceFormatted}' : 'Subscribe - \$180.00',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFeaturesList(bool isStarter, {ProfessionalPlanModel? professionalPlan}) {
    if (isStarter) {
      return [
        _buildFeatureItem('15 free practice questions per month'),
        _buildFeatureItem('Explore all certifications'),
        _buildFeatureItem('Up to 2 practice questions per certification'),
        _buildFeatureItem('Upgrade anytime for full access'),
      ];
    }
    if (professionalPlan != null && professionalPlan.features.isNotEmpty) {
      return professionalPlan.features
          .map((f) => _buildFeatureItem(f))
          .toList();
    }
    return [
      _buildFeatureItem('Access to selected resources'),
      _buildFeatureItem('Full-length mock exams'),
      _buildFeatureItem('Timed & Full Simulation Modes'),
      _buildFeatureItem('Interactive study mode'),
      _buildFeatureItem(
          'Progress tracking, Performance Dashboard & exam history'),
      _buildFeatureItem('Detailed explanations with code references'),
      _buildFeatureItem('All Smart Study Tools'),
    ];
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check,
            color: Color(0xFF111827),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF111827),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockExamDialog extends StatefulWidget {
  final ExamService examService;
  final int maxSelect;

  const _UnlockExamDialog({
    required this.examService,
    required this.maxSelect,
  });

  @override
  State<_UnlockExamDialog> createState() => _UnlockExamDialogState();
}

class _UnlockExamDialogState extends State<_UnlockExamDialog> {
  late final Future<List<ExamModel>> _future;
  final Set<String> _selectedIds = {};
  bool _acknowledged = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ExamModel>> _load() async {
    final res = await widget.examService.getActiveExams();
    if (!res.success) {
      throw Exception(res.message ?? 'Failed to fetch exams');
    }
    return res.data ?? const [];
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (_selectedIds.length >= widget.maxSelect) return;
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _acknowledged && _selectedIds.isNotEmpty;

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
              return const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
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
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final e = exams[index];
                      final selected = _selectedIds.contains(e.id);
                      final disabled = !selected && _selectedIds.length >= widget.maxSelect;

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: disabled ? null : () => _toggle(e.id),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged: disabled ? null : (_) => _toggle(e.id),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Master your certification exam',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
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
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    '${_selectedIds.length}/${widget.maxSelect} exam${widget.maxSelect == 1 ? '' : 's'} selected',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acknowledged,
                      onChanged: (v) => setState(() => _acknowledged = v ?? false),
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
                          side: const BorderSide(color: Color(0xFF2D4F88), width: 1.5),
                          foregroundColor: const Color(0xFF2D4F88),
                        ),
                        child: const Text('Go Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canConfirm ? () => Navigator.pop(context, _selectedIds.toList()) : null,
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
