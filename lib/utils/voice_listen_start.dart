import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../controllers/quiz_voice_controller.dart';

const Duration minimumVoiceListenRetryDelay = Duration(seconds: 1);
const Duration voiceListenForDuration = Duration(seconds: 25);
const Duration voicePauseForDuration = Duration(seconds: 4);
const Duration fastVoicePauseForDuration = Duration(seconds: 3);

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
  bool fastSpeakerMode = false,
}) async {
  try {
    if (speech.isListening) {
      debugPrint(
        '[Voice][${screen.name}] listen start skipped: already active',
      );
      return true;
    }
    debugPrint(
      '[Voice][${screen.name}] listen start requested locale=${localeId ?? 'system'} fastSpeaker=$fastSpeakerMode',
    );
    await speech.listen(
      onResult: onResult,
      listenFor: voiceListenForDuration,
      pauseFor: fastSpeakerMode
          ? fastVoicePauseForDuration
          : voicePauseForDuration,
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
      ),
    );
    debugPrint(
      '[Voice][${screen.name}] listen call accepted; awaiting listening status',
    );
    return true;
  } catch (error, stackTrace) {
    debugPrint('[Voice][${screen.name}] listen start failed: $error');
    controller.logEvent(
      'speech listen start failed: $error\n$stackTrace',
      screen: screen,
    );
    return false;
  }
}
