import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/storage_service.dart';
import '../../utils/app_constants.dart';
import '../widgets/gradient_background.dart';

class SharedEbookRedirectScreen extends StatefulWidget {
  final String referralCode;
  final String productId;

  const SharedEbookRedirectScreen({
    super.key,
    required this.referralCode,
    required this.productId,
  });

  @override
  State<SharedEbookRedirectScreen> createState() =>
      _SharedEbookRedirectScreenState();
}

class _SharedEbookRedirectScreenState extends State<SharedEbookRedirectScreen> {
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleRedirect());
  }

  Future<void> _handleRedirect() async {
    final referralCode = widget.referralCode.trim();
    final productId = widget.productId.trim();

    if (referralCode.isNotEmpty) {
      await _storageService.saveString(
        AppConstants.pendingReferralCodeKey,
        referralCode,
      );
    }

    if (productId.isNotEmpty) {
      await _storageService.saveString(
        AppConstants.pendingReferralProductIdKey,
        productId,
      );
    }

    final hasSession = await _storageService.hasValidSessionArtifacts();
    if (!mounted) return;

    final nextRoute = hasSession
        ? Uri(
            path: '/ebook-detail',
            queryParameters: {if (productId.isNotEmpty) 'productId': productId},
          ).toString()
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
