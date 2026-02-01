import 'dart:io';

import 'package:flutter/foundation.dart';

String getBaseUrl(String defaultUrl) {
  if (Platform.isAndroid) {
    return kDebugMode ? 'http://10.10.5.95:5001/api/v1' : defaultUrl;
  }
  if (Platform.isIOS) {
    return kDebugMode ? 'http://10.10.5.95:5001/api/v1' : defaultUrl;
  }
  return defaultUrl;
}
