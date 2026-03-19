import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/storage_service.dart';
import '../../utils/app_constants.dart';
import '../widgets/gradient_background.dart';

class SharedReferralRedirectScreen extends StatefulWidget {
  final String referralCode;

  const SharedReferralRedirectScreen({super.key, required this.referralCode});

  @override
  State<SharedReferralRedirectScreen> createState() =>
      _SharedReferralRedirectScreenState();
}

class _SharedReferralRedirectScreenState
    extends State<SharedReferralRedirectScreen> {
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleRedirect());
  }

  Future<void> _handleRedirect() async {
    final referralCode = widget.referralCode.trim();

    if (referralCode.isNotEmpty) {
      await _storageService.saveString(
        AppConstants.pendingReferralCodeKey,
        referralCode,
      );
    } else {
      await _storageService.remove(AppConstants.pendingReferralCodeKey);
    }

    await _storageService.remove(AppConstants.pendingReferralProductIdKey);

    final hasSession = await _storageService.hasValidSessionArtifacts();
    if (!mounted) return;

    final nextRoute = hasSession
        ? '/subscribe'
        : Uri(
            path: '/sign-up',
            queryParameters: {if (referralCode.isNotEmpty) 'ref': referralCode},
          ).toString();

    context.go(nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        useImage: true,
        child: const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
