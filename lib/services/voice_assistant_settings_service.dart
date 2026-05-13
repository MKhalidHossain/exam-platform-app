import 'package:shared_preferences/shared_preferences.dart';

enum CommandSensitivity { strict, normal, flexible }

class VoiceAssistantSettings {
  final double voiceSpeed;
  final double voicePitch;
  final String languageCode;
  final String speechLocaleCode;
  final bool autoListenOnScreenOpen;
  final CommandSensitivity commandSensitivity;
  final bool cloudFallbackEnabled;
  final bool showHeardText;
  final bool showDebugConfidence;

  const VoiceAssistantSettings({
    required this.voiceSpeed,
    required this.voicePitch,
    required this.languageCode,
    required this.speechLocaleCode,
    required this.autoListenOnScreenOpen,
    required this.commandSensitivity,
    required this.cloudFallbackEnabled,
    required this.showHeardText,
    required this.showDebugConfidence,
  });

  factory VoiceAssistantSettings.defaults() {
    return const VoiceAssistantSettings(
      voiceSpeed: 0.5,
      voicePitch: 1.0,
      languageCode: 'en-US',
      speechLocaleCode: 'en-US',
      autoListenOnScreenOpen: true,
      commandSensitivity: CommandSensitivity.normal,
      cloudFallbackEnabled: false,
      showHeardText: true,
      showDebugConfidence: true,
    );
  }

  VoiceAssistantSettings copyWith({
    double? voiceSpeed,
    double? voicePitch,
    String? languageCode,
    String? speechLocaleCode,
    bool? autoListenOnScreenOpen,
    CommandSensitivity? commandSensitivity,
    bool? cloudFallbackEnabled,
    bool? showHeardText,
    bool? showDebugConfidence,
  }) {
    return VoiceAssistantSettings(
      voiceSpeed: voiceSpeed ?? this.voiceSpeed,
      voicePitch: voicePitch ?? this.voicePitch,
      languageCode: languageCode ?? this.languageCode,
      speechLocaleCode: speechLocaleCode ?? this.speechLocaleCode,
      autoListenOnScreenOpen:
          autoListenOnScreenOpen ?? this.autoListenOnScreenOpen,
      commandSensitivity: commandSensitivity ?? this.commandSensitivity,
      cloudFallbackEnabled: cloudFallbackEnabled ?? this.cloudFallbackEnabled,
      showHeardText: showHeardText ?? this.showHeardText,
      showDebugConfidence: showDebugConfidence ?? this.showDebugConfidence,
    );
  }
}

class VoiceAssistantSettingsService {
  static const String _voiceSpeedKey = 'voice_assistant_voice_speed';
  static const String _voicePitchKey = 'voice_assistant_voice_pitch';
  static const String _languageCodeKey = 'voice_assistant_language_code';
  static const String _speechLocaleCodeKey =
      'voice_assistant_speech_locale_code';
  static const String _autoListenKey = 'voice_assistant_auto_listen';
  static const String _sensitivityKey = 'voice_assistant_command_sensitivity';
  static const String _cloudFallbackKey = 'voice_assistant_cloud_fallback';
  static const String _showHeardTextKey = 'voice_assistant_show_heard_text';
  static const String _showDebugConfidenceKey =
      'voice_assistant_show_debug_confidence';

  Future<VoiceAssistantSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = VoiceAssistantSettings.defaults();
    return VoiceAssistantSettings(
      voiceSpeed: (prefs.getDouble(_voiceSpeedKey) ?? defaults.voiceSpeed)
          .clamp(0.2, 1.0)
          .toDouble(),
      voicePitch: (prefs.getDouble(_voicePitchKey) ?? defaults.voicePitch)
          .clamp(0.5, 2.0)
          .toDouble(),
      languageCode: prefs.getString(_languageCodeKey) ?? defaults.languageCode,
      speechLocaleCode:
          prefs.getString(_speechLocaleCodeKey) ??
          prefs.getString(_languageCodeKey) ??
          defaults.speechLocaleCode,
      autoListenOnScreenOpen:
          prefs.getBool(_autoListenKey) ?? defaults.autoListenOnScreenOpen,
      commandSensitivity: _sensitivityFromName(
        prefs.getString(_sensitivityKey),
      ),
      cloudFallbackEnabled:
          prefs.getBool(_cloudFallbackKey) ?? defaults.cloudFallbackEnabled,
      showHeardText: prefs.getBool(_showHeardTextKey) ?? defaults.showHeardText,
      showDebugConfidence:
          prefs.getBool(_showDebugConfidenceKey) ??
          defaults.showDebugConfidence,
    );
  }

  Future<void> saveSettings(VoiceAssistantSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_voiceSpeedKey, settings.voiceSpeed);
    await prefs.setDouble(_voicePitchKey, settings.voicePitch);
    await prefs.setString(_languageCodeKey, settings.languageCode.trim());
    await prefs.setString(
      _speechLocaleCodeKey,
      settings.speechLocaleCode.trim(),
    );
    await prefs.setBool(_autoListenKey, settings.autoListenOnScreenOpen);
    await prefs.setString(_sensitivityKey, settings.commandSensitivity.name);
    await prefs.setBool(_cloudFallbackKey, settings.cloudFallbackEnabled);
    await prefs.setBool(_showHeardTextKey, settings.showHeardText);
    await prefs.setBool(_showDebugConfidenceKey, settings.showDebugConfidence);
  }

  CommandSensitivity _sensitivityFromName(String? name) {
    for (final sensitivity in CommandSensitivity.values) {
      if (sensitivity.name == name) return sensitivity;
    }
    return CommandSensitivity.normal;
  }
}
