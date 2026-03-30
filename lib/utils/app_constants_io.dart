import 'package:flutter/foundation.dart';

const String _debugApiOrigin = 'http://localhost:5001';

String getBaseUrl(String defaultUrl) {
  return kDebugMode ? '$_debugApiOrigin/api/v1' : defaultUrl;
}

String getPublicBaseUrl(String defaultUrl) {
  return kDebugMode ? _debugApiOrigin : defaultUrl;
}
