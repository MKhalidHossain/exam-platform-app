import 'package:shared_preferences/shared_preferences.dart';

import '../voice/parsing/voice_text_normalizer.dart';

enum CommandSensitivity { strict, normal, flexible }

/// Which speech-recognition engine the app should use as its primary STT
/// source.
///
/// * [native] — platform STT (Apple Speech / Android RecognitionService) via
///   the `speech_to_text` package. Free, on-device-ish, accuracy varies
///   wildly by OEM and accent.
/// * [whisperOnDevice] — on-device Whisper via sherpa-onnx (Phase 2). Best
///   accent robustness; requires a ~140 MB model file downloaded on first
///   use. When the model isn't yet present the runtime falls back to
///   [native] so the app remains functional.
/// * [hybrid] — start with [native] for low-latency commands, escalate to
///   the cloud fallback when on-device confidence is below threshold.
enum VoiceEngine { native, whisperOnDevice, hybrid }

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
  final VoiceAccentProfile accentProfile;
  final bool fastSpeakerMode;
  final VoiceEngine voiceEngine;
  /// HTTPS URL of the self-hosted Whisper transcription endpoint. When
  /// non-empty the controller instantiates a [CloudSpeechService] against it
  /// and enables cloud-assisted recognition. Empty disables the cloud path
  /// entirely regardless of [cloudFallbackEnabled].
  final String cloudEndpointUrl;
  /// Optional bearer token sent as `Authorization: Bearer <token>` to the
  /// cloud endpoint. Lets the VPS reject anonymous requests.
  final String cloudAuthToken;

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
    required this.accentProfile,
    required this.fastSpeakerMode,
    required this.voiceEngine,
    required this.cloudEndpointUrl,
    required this.cloudAuthToken,
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
      accentProfile: VoiceAccentProfile.defaultEnglish,
      fastSpeakerMode: false,
      voiceEngine: VoiceEngine.native,
      cloudEndpointUrl: '',
      cloudAuthToken: '',
    );
  }

  /// True when the runtime should actually invoke the cloud transcriber.
  ///
  /// Configuring [cloudEndpointUrl] is treated as opting into cloud
  /// assistance — typing a URL into Settings (or baking one in via
  /// `--dart-define=CLOUD_VOICE_ENDPOINT=…`) is unambiguous intent and
  /// having to flip a separate toggle would surprise users. The explicit
  /// [cloudFallbackEnabled] flag still wins when the URL is empty.
  bool get isCloudFallbackActive =>
      cloudFallbackEnabled || cloudEndpointUrl.trim().isNotEmpty;

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
    VoiceAccentProfile? accentProfile,
    bool? fastSpeakerMode,
    VoiceEngine? voiceEngine,
    String? cloudEndpointUrl,
    String? cloudAuthToken,
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
      accentProfile: accentProfile ?? this.accentProfile,
      fastSpeakerMode: fastSpeakerMode ?? this.fastSpeakerMode,
      voiceEngine: voiceEngine ?? this.voiceEngine,
      cloudEndpointUrl: cloudEndpointUrl ?? this.cloudEndpointUrl,
      cloudAuthToken: cloudAuthToken ?? this.cloudAuthToken,
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
  static const String _accentProfileKey = 'voice_assistant_accent_profile';
  static const String _fastSpeakerModeKey = 'voice_assistant_fast_speaker_mode';
  static const String _voiceEngineKey = 'voice_assistant_voice_engine';
  static const String _cloudEndpointUrlKey = 'voice_assistant_cloud_endpoint_url';
  static const String _cloudAuthTokenKey = 'voice_assistant_cloud_auth_token';
  /// Compile-time default for the cloud endpoint. Setting this in
  /// `--dart-define=CLOUD_VOICE_ENDPOINT=https://your-vps/api/voice/transcribe-command`
  /// at build time means every install picks it up automatically without
  /// requiring the user to type the URL in Settings. Override per-user is
  /// still possible via [VoiceAssistantSettings.cloudEndpointUrl].
  static const String _compiledEndpointDefault = String.fromEnvironment(
    'CLOUD_VOICE_ENDPOINT',
    defaultValue: '',
  );
  static const String _compiledTokenDefault = String.fromEnvironment(
    'CLOUD_VOICE_TOKEN',
    defaultValue: '',
  );

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
          prefs.getString(_speechLocaleCodeKey) ?? defaults.speechLocaleCode,
      autoListenOnScreenOpen:
          prefs.getBool(_autoListenKey) ?? defaults.autoListenOnScreenOpen,
      commandSensitivity: _sensitivityFromName(
        prefs.getString(_sensitivityKey),
      ),
      // Persisted user choice now wins. Default is still false (opt-in), but
      // we no longer force-override an existing preference on every load.
      // The runtime selector still checks that a CloudSpeechTranscriber has
      // been wired before actually routing audio through it, so flipping the
      // toggle without a backend keeps the app on native STT.
      cloudFallbackEnabled:
          prefs.getBool(_cloudFallbackKey) ?? defaults.cloudFallbackEnabled,
      showHeardText: prefs.getBool(_showHeardTextKey) ?? defaults.showHeardText,
      showDebugConfidence:
          prefs.getBool(_showDebugConfidenceKey) ??
          defaults.showDebugConfidence,
      accentProfile: _accentProfileFromName(prefs.getString(_accentProfileKey)),
      fastSpeakerMode:
          prefs.getBool(_fastSpeakerModeKey) ?? defaults.fastSpeakerMode,
      voiceEngine: _voiceEngineFromName(prefs.getString(_voiceEngineKey)),
      cloudEndpointUrl:
          prefs.getString(_cloudEndpointUrlKey) ?? _compiledEndpointDefault,
      cloudAuthToken:
          prefs.getString(_cloudAuthTokenKey) ?? _compiledTokenDefault,
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
    await prefs.setString(_accentProfileKey, settings.accentProfile.name);
    await prefs.setBool(_fastSpeakerModeKey, settings.fastSpeakerMode);
    await prefs.setString(_voiceEngineKey, settings.voiceEngine.name);
    await prefs.setString(
      _cloudEndpointUrlKey,
      settings.cloudEndpointUrl.trim(),
    );
    await prefs.setString(_cloudAuthTokenKey, settings.cloudAuthToken.trim());
  }

  CommandSensitivity _sensitivityFromName(String? name) {
    for (final sensitivity in CommandSensitivity.values) {
      if (sensitivity.name == name) return sensitivity;
    }
    return CommandSensitivity.normal;
  }

  VoiceAccentProfile _accentProfileFromName(String? name) {
    for (final profile in VoiceAccentProfile.values) {
      if (profile.name == name) return profile;
    }
    return VoiceAccentProfile.defaultEnglish;
  }

  VoiceEngine _voiceEngineFromName(String? name) {
    for (final engine in VoiceEngine.values) {
      if (engine.name == name) return engine;
    }
    return VoiceEngine.native;
  }
}
