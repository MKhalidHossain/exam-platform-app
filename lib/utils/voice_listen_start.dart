import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../controllers/quiz_voice_controller.dart';

const Duration minimumVoiceListenRetryDelay = Duration(seconds: 1);

Duration enforceMinimumVoiceListenRetryDelay(Duration delay) {
  return delay < minimumVoiceListenRetryDelay
      ? minimumVoiceListenRetryDelay
      : delay;
}

Future<bool> startSpeechListeningSafely({
  required SpeechToText speech,
  required QuizVoiceController controller,
  required QuizVoiceScreen screen,
  required void Function(SpeechRecognitionResult result) onResult,
  required String? localeId,
}) async {
  try {
    await speech.listen(
      onResult: onResult,
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(minutes: 1),
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
      ),
    );
    return speech.isListening;
  } catch (error, stackTrace) {
    controller.logEvent(
      'speech listen start failed: $error\n$stackTrace',
      screen: screen,
    );
    return false;
  }
}
