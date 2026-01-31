import 'dart:io';

import 'package:flutter/foundation.dart';

String getBaseUrl(String defaultUrl) {
  if (Platform.isAndroid) {
    return kDebugMode ? 'http://10.0.2.2:5001/api/v1' : defaultUrl;
  }
  if (Platform.isIOS) {
    return kDebugMode ? 'http://127.0.0.1:5001/api/v1' : defaultUrl;
  }
  return defaultUrl;
}
