import 'package:shared_preferences/shared_preferences.dart';

enum CommandSensitivity { strict, normal, flexible }

class VoiceAssistantSettings {
  final double voiceSpeed;
  final double voicePitch;
  final String languageCode;
  final bool autoListenOnScreenOpen;
  final CommandSensitivity commandSensitivity;
  final bool showHeardText;

  const VoiceAssistantSettings({
    required this.voiceSpeed,
    required this.voicePitch,
    required this.languageCode,
    required this.autoListenOnScreenOpen,
    required this.commandSensitivity,
    required this.showHeardText,
  });

  factory VoiceAssistantSettings.defaults() {
    return const VoiceAssistantSettings(
      voiceSpeed: 0.5,
      voicePitch: 1.0,
      languageCode: 'en-US',
      autoListenOnScreenOpen: true,
      commandSensitivity: CommandSensitivity.normal,
      showHeardText: true,
    );
  }

  VoiceAssistantSettings copyWith({
    double? voiceSpeed,
    double? voicePitch,
    String? languageCode,
    bool? autoListenOnScreenOpen,
    CommandSensitivity? commandSensitivity,
    bool? showHeardText,
  }) {
    return VoiceAssistantSettings(
      voiceSpeed: voiceSpeed ?? this.voiceSpeed,
      voicePitch: voicePitch ?? this.voicePitch,
      languageCode: languageCode ?? this.languageCode,
      autoListenOnScreenOpen:
          autoListenOnScreenOpen ?? this.autoListenOnScreenOpen,
      commandSensitivity: commandSensitivity ?? this.commandSensitivity,
      showHeardText: showHeardText ?? this.showHeardText,
    );
  }
}

class VoiceAssistantSettingsService {
  static const String _voiceSpeedKey = 'voice_assistant_voice_speed';
  static const String _voicePitchKey = 'voice_assistant_voice_pitch';
  static const String _languageCodeKey = 'voice_assistant_language_code';
  static const String _autoListenKey = 'voice_assistant_auto_listen';
  static const String _sensitivityKey = 'voice_assistant_command_sensitivity';
  static const String _showHeardTextKey = 'voice_assistant_show_heard_text';

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
      autoListenOnScreenOpen:
          prefs.getBool(_autoListenKey) ?? defaults.autoListenOnScreenOpen,
      commandSensitivity: _sensitivityFromName(
        prefs.getString(_sensitivityKey),
      ),
      showHeardText: prefs.getBool(_showHeardTextKey) ?? defaults.showHeardText,
    );
  }

  Future<void> saveSettings(VoiceAssistantSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_voiceSpeedKey, settings.voiceSpeed);
    await prefs.setDouble(_voicePitchKey, settings.voicePitch);
    await prefs.setString(_languageCodeKey, settings.languageCode.trim());
    await prefs.setBool(_autoListenKey, settings.autoListenOnScreenOpen);
    await prefs.setString(_sensitivityKey, settings.commandSensitivity.name);
    await prefs.setBool(_showHeardTextKey, settings.showHeardText);
  }

  CommandSensitivity _sensitivityFromName(String? name) {
    for (final sensitivity in CommandSensitivity.values) {
      if (sensitivity.name == name) return sensitivity;
    }
    return CommandSensitivity.normal;
  }
}
