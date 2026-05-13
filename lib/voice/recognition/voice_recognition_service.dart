import 'speech_recognition_result.dart';

class VoiceRecognitionLocale {
  final String localeId;
  final String name;

  const VoiceRecognitionLocale({required this.localeId, required this.name});
}

class VoiceRecognitionListenConfig {
  final String? localeId;
  final Duration listenFor;
  final Duration pauseFor;
  final bool partialResults;

  const VoiceRecognitionListenConfig({
    this.localeId,
    this.listenFor = const Duration(minutes: 1),
    this.pauseFor = const Duration(minutes: 1),
    this.partialResults = true,
  });
}

typedef VoiceRecognitionResultCallback = void Function(SpeechRecognitionResult);

abstract class VoiceRecognitionService {
  Future<SpeechRecognitionResult> initialize();

  Future<List<VoiceRecognitionLocale>> locales();

  Future<SpeechRecognitionResult> listen({
    VoiceRecognitionListenConfig config = const VoiceRecognitionListenConfig(),
    VoiceRecognitionResultCallback? onPartialResult,
  });

  Future<SpeechRecognitionResult> stop();

  Future<SpeechRecognitionResult> cancel();
}
