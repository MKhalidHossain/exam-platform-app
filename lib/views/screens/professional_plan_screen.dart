import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/error/error_handler.dart';
import '../../services/iap_service.dart';
import '../../utils/app_constants.dart';
import '../widgets/gradient_background.dart';

class ProfessionalPlanScreen extends StatefulWidget {
  const ProfessionalPlanScreen({super.key});

  @override
  State<ProfessionalPlanScreen> createState() => _ProfessionalPlanScreenState();
}

class _ProfessionalPlanScreenState extends State<ProfessionalPlanScreen> {
  final RxBool _screenTick = false.obs;
  static const String _benefitsText =
      'Includes full access to API certification exam preparation, all API exams, full-length mock exams, timed simulation mode, study mode, progress tracking, performance dashboard, exam history, and detailed answer explanations.';
  static const String _renewalText =
      'This subscription auto-renews every 6 months unless cancelled at least 24 hours before the end of the current period. Payment will be charged to your Apple ID account at confirmation of purchase. You can manage or cancel your subscription in your Apple ID subscription settings.';
  static const String _agreementText =
      'By subscribing, you agree to our Terms of Use and Privacy Policy.';

  Future<void> _openExternalUrl(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ErrorHandler.showSnackBar(
        'Unable to open link. Please try again.',
        isError: true,
        context: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final IapService? iapService =
        Platform.isIOS && Get.isRegistered<IapService>()
        ? Get.find<IapService>()
        : null;
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
                        'Subscribe',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      Obx(() {
                        _screenTick.value;
                        final appStorePrice = iapService?.professionalPrice;
                        final iapUnavailable =
                            Platform.isIOS &&
                            (iapService == null ||
                                !iapService.isStoreAvailable.value ||
                                appStorePrice == null);
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
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
                                      color: const Color(0xFF2D4F88),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.bolt,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Pro Plan 6 Months',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Pricing
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    appStorePrice ?? 'Loading...',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '/ 6 months',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(height: 1, color: Colors.grey[200]),
                              const SizedBox(height: 20),
                              const Text(
                                'Benefits',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                _benefitsText,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF111827),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                _renewalText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                _agreementText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () => _openExternalUrl(
                                      AppConstants.termsOfUseUrl,
                                    ),
                                    child: const Text('Terms of Use'),
                                  ),
                                  TextButton(
                                    onPressed: () => _openExternalUrl(
                                      AppConstants.privacyPolicyUrl,
                                    ),
                                    child: const Text('Privacy Policy'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Upgrade Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: iapUnavailable
                                      ? null
                                      : () => iapService
                                            ?.buyProfessionalSubscription(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D4F88),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    appStorePrice == null
                                        ? 'Purchases unavailable'
                                        : 'Subscribe',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      iapService?.isRestoring.value == true
                                      ? null
                                      : () => iapService?.restorePurchases(),
                                  icon: const Icon(Icons.restore),
                                  label: Text(
                                    iapService?.isRestoring.value == true
                                        ? 'Restoring...'
                                        : 'Restore Purchase',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (iapService?.errorMessage.value.isNotEmpty ??
                                  false)
                                Text(
                                  iapService!.errorMessage.value,
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
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
  }
}
