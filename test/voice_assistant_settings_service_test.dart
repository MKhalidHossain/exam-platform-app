import 'package:ej_flutter/services/voice_assistant_settings_service.dart';
import 'package:ej_flutter/voice/parsing/voice_text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late VoiceAssistantSettingsService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = VoiceAssistantSettingsService();
  });

  test('loads defaults when no settings are saved', () async {
    final settings = await service.loadSettings();

    expect(settings.voiceSpeed, 0.5);
    expect(settings.voicePitch, 1.0);
    expect(settings.languageCode, 'en-US');
    expect(settings.autoListenOnScreenOpen, isTrue);
    expect(settings.commandSensitivity, CommandSensitivity.normal);
    expect(settings.cloudFallbackEnabled, isFalse);
    expect(settings.showHeardText, isTrue);
    expect(settings.accentProfile, VoiceAccentProfile.defaultEnglish);
    expect(settings.fastSpeakerMode, isFalse);
  });

  test('persists voice assistant settings', () async {
    final updated = VoiceAssistantSettings.defaults().copyWith(
      voiceSpeed: 0.8,
      voicePitch: 1.4,
      languageCode: 'en-GB',
      autoListenOnScreenOpen: false,
      commandSensitivity: CommandSensitivity.flexible,
      cloudFallbackEnabled: true,
      showHeardText: false,
      accentProfile: VoiceAccentProfile.africanEnglish,
      fastSpeakerMode: true,
    );

    await service.saveSettings(updated);
    final loaded = await service.loadSettings();

    expect(loaded.voiceSpeed, 0.8);
    expect(loaded.voicePitch, 1.4);
    expect(loaded.languageCode, 'en-GB');
    expect(loaded.autoListenOnScreenOpen, isFalse);
    expect(loaded.commandSensitivity, CommandSensitivity.flexible);
    expect(loaded.cloudFallbackEnabled, isFalse);
    expect(loaded.showHeardText, isFalse);
    expect(loaded.accentProfile, VoiceAccentProfile.africanEnglish);
    expect(loaded.fastSpeakerMode, isTrue);
  });
}
