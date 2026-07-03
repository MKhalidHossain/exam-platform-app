import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../controllers/quiz_voice_controller.dart';

// Minimum gap between consecutive listen() calls. The pause between native
// STT sessions felt like "warming up" at the 1000 ms default — 150 ms keeps
// the mic effectively always-on without hammering the plugin.
const Duration minimumVoiceListenRetryDelay = Duration(milliseconds: 150);

// Total time the mic stays open. Plenty for any single answer / command.
const Duration voiceListenForDuration = Duration(seconds: 25);

// How long native STT waits in silence before finalising.
//
// Calibration history:
//   * Original 4 s = made the user wait forever after each command.
//   * Tried 1.1 s = too aggressive; natural mid-utterance pauses ("the
//     answer is …. option B") got chopped, the audio sent to Whisper was
//     truncated, and the assistant "didn't understand" because Whisper
//     received "the answer is" with no answer.
//   * 2.5 s = production sweet spot. Long enough to bridge thinking pauses
//     without losing the snappy-feel — we additionally finalise early via
//     the partial-result endpoint timer in mcq_screen.dart, so the user
//     barely waits when they clearly stopped speaking.
const Duration voicePauseForDuration = Duration(milliseconds: 2500);

// Fast-speaker mode is for users who answer in single words ("B"). They
// rarely pause mid-utterance, so we can collapse a bit further.
const Duration fastVoicePauseForDuration = Duration(milliseconds: 1500);

// After the last partial-result event fires, how long we wait before
// force-finalising the utterance. Together with the safety [voicePauseForDuration]
// this gives us: long mic-open as a safety net, fast cutoff once the user
// has clearly stopped talking. Driven manually in `_onSpeechResult` —
// the native plugin doesn't expose dynamic pauseFor adjustment.
const Duration voicePartialResultEndpointDelay = Duration(milliseconds: 1200);
const Duration fastVoicePartialResultEndpointDelay = Duration(milliseconds: 900);

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
