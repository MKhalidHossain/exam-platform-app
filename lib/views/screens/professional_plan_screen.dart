import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../services/iap_service.dart';
import '../widgets/gradient_background.dart';

class ProfessionalPlanScreen extends StatefulWidget {
  const ProfessionalPlanScreen({super.key});

  @override
  State<ProfessionalPlanScreen> createState() => _ProfessionalPlanScreenState();
}

class _ProfessionalPlanScreenState extends State<ProfessionalPlanScreen> {
  final RxBool _screenTick = false.obs;

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
                                      'Professional Plan',
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
                                    '/6 months',
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
                                'What\'s Included in Your Plan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Features List
                              _buildFeatureItem('Access to selected resources'),
                              _buildFeatureItem('Full-length mock exams'),
                              _buildFeatureItem(
                                'Timed & Full Simulation Modes',
                              ),
                              _buildFeatureItem('Interactive study mode'),
                              _buildFeatureItem(
                                'Progress tracking, Performance Dashboard & exam history',
                              ),
                              _buildFeatureItem(
                                'Detailed explanations with code references',
                              ),
                              _buildFeatureItem('All Smart Study Tools'),
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
                                        : 'Subscribe for $appStorePrice',
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
                                        : 'Restore Purchases',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        context.push('/privacy-policy'),
                                    child: const Text('Privacy Policy'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        context.push('/terms-of-service'),
                                    child: const Text('Terms of Use'),
                                  ),
                                ],
                              ),
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

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, color: Color(0xFF111827), size: 20),
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
