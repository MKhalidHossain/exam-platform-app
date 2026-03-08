import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../utils/app_constants.dart';

class InstallationIdService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<String> getOrCreateInstallationId() async {
    final prefs = await SharedPreferences.getInstance();
    final bootstrapped =
        prefs.getBool(AppConstants.installationBootstrapKey) ?? false;

    // iOS Keychain can survive uninstall. Clear secure key on first app run
    // so a reinstall is treated as a new installation.
    if (!bootstrapped) {
      await _secureStorage.delete(key: AppConstants.installationIdSecureKey);
      await prefs.setBool(AppConstants.installationBootstrapKey, true);
    }

    final existing = await _secureStorage.read(
      key: AppConstants.installationIdSecureKey,
    );
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final installationId = const Uuid().v4();
    await _secureStorage.write(
      key: AppConstants.installationIdSecureKey,
      value: installationId,
    );
    return installationId;
  }

  Future<String?> getInstallationId() async {
    final existing = await _secureStorage.read(
      key: AppConstants.installationIdSecureKey,
    );
    if (existing == null || existing.isEmpty) {
      return null;
    }
    return existing;
  }
}
