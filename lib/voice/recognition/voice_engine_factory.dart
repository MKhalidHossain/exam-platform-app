import 'package:flutter/foundation.dart';

import '../../services/voice_assistant_settings_service.dart';
import 'native_speech_service.dart';
import 'voice_recognition_service.dart';

/// Decides which [VoiceRecognitionService] implementation backs the assistant
/// for a given session.
///
/// Phase 2 plan: this factory will return a `WhisperSpeechService` (sherpa-onnx
/// + Silero VAD + hot-words) when the on-device Whisper model is present and
/// the user has opted into [VoiceEngine.whisperOnDevice] or
/// [VoiceEngine.hybrid]. Until that engine ships, the factory transparently
/// falls back to [NativeSpeechService] and emits a debug log so we can see
/// real-world request rates for the on-device engine before committing the
/// model download.
class VoiceEngineFactory {
  const VoiceEngineFactory({this.whisperBuilder});

  /// Optional builder for the on-device Whisper engine. Wiring this up is the
  /// Phase 2 deliverable; tests and future code can inject one here without
  /// changing call sites. When null, the factory always returns the native
  /// engine.
  final VoiceRecognitionService Function()? whisperBuilder;

  VoiceRecognitionService create({
    required VoiceAssistantSettings settings,
    NativeSpeechService? nativeOverride,
  }) {
    final native = nativeOverride ?? NativeSpeechService();
    switch (settings.voiceEngine) {
      case VoiceEngine.native:
        return native;
      case VoiceEngine.whisperOnDevice:
      case VoiceEngine.hybrid:
        final builder = whisperBuilder;
        if (builder == null) {
          debugPrint(
            '[Voice][factory] requested ${settings.voiceEngine.name} but no '
            'WhisperSpeechService implementation is wired yet — falling back '
            'to native STT.',
          );
          return native;
        }
        try {
          return builder();
        } catch (error, stackTrace) {
          debugPrint(
            '[Voice][factory] whisper builder threw $error; falling back to '
            'native. stack: $stackTrace',
          );
          return native;
        }
    }
  }
}
