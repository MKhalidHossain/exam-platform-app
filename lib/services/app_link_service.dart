import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../utils/app_constants.dart';

class AppLinkService {
  AppLinkService(this._router);

  final GoRouter _router;
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _subscription;
  bool _started = false;

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks!.getInitialLink();
      _handleUri(initialUri);
    } catch (error, stackTrace) {
      debugPrint('AppLinkService initial link error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    _subscription = _appLinks!.uriLinkStream.listen(
      _handleUri,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('AppLinkService stream error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
  }

  void _handleUri(Uri? uri) {
    final route = _routeFromUri(uri);
    if (route == null) return;
    _router.go(route);
  }

  String? _routeFromUri(Uri? uri) {
    if (uri == null) return null;

    final normalizedPath = _normalizedPath(uri);
    if (normalizedPath == AppConstants.sharedReferralPath) {
      return Uri(
        path: AppConstants.sharedReferralPath,
        queryParameters: {
          if ((uri.queryParameters['ref'] ?? '').trim().isNotEmpty)
            'ref': uri.queryParameters['ref']!.trim(),
        },
      ).toString();
    }

    if (normalizedPath == AppConstants.sharedEbookPath) {
      return Uri(
        path: AppConstants.sharedEbookPath,
        queryParameters: {
          if ((uri.queryParameters['ref'] ?? '').trim().isNotEmpty)
            'ref': uri.queryParameters['ref']!.trim(),
          if ((uri.queryParameters['productId'] ?? '').trim().isNotEmpty)
            'productId': uri.queryParameters['productId']!.trim(),
        },
      ).toString();
    }

    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == 'r') {
      final referralCode = segments[1].trim();
      if (referralCode.isEmpty) return null;
      return Uri(
        path: AppConstants.sharedReferralPath,
        queryParameters: {'ref': referralCode},
      ).toString();
    }

    return null;
  }

  String _normalizedPath(Uri uri) {
    final host = uri.host.trim();
    if (host == 'shared-referral') {
      return AppConstants.sharedReferralPath;
    }
    if (host == 'shared-ebook') {
      return AppConstants.sharedEbookPath;
    }

    final path = uri.path.trim();
    if (path == '/shared-referral' || path == 'shared-referral') {
      return AppConstants.sharedReferralPath;
    }
    if (path == '/shared-ebook' || path == 'shared-ebook') {
      return AppConstants.sharedEbookPath;
    }

    return path.startsWith('/') ? path : '/$path';
  }
}
