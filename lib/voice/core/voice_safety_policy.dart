import 'voice_intent.dart';

class VoiceSafetyPolicy {
  static const Set<VoiceIntentType> riskyIntentTypes = {
    VoiceIntentType.submit,
    VoiceIntentType.confirmSubmit,
    VoiceIntentType.finalSubmit,
    VoiceIntentType.exitQuiz,
    VoiceIntentType.resetAnswers,
    VoiceIntentType.clearAnswer,
    VoiceIntentType.finishExam,
    VoiceIntentType.delete,
    VoiceIntentType.restartTest,
  };

  static const Set<String> riskyPhrases = {
    'submit quiz',
    'confirm submit',
    'final submit',
    'exit quiz',
    'reset answers',
    'clear answer',
    'finish exam',
    'delete',
    'restart test',
  };

  const VoiceSafetyPolicy._();

  static bool isRiskyIntentType(VoiceIntentType type) {
    return riskyIntentTypes.contains(type);
  }

  static bool isRiskyIntent(VoiceIntent intent) {
    return intent.isRisky || isRiskyIntentType(intent.type);
  }

  static bool isRiskyText(String text) {
    final normalizedText = _normalizeForSafety(text);
    if (normalizedText.isEmpty) return false;

    for (final phrase in riskyPhrases) {
      if (normalizedText == phrase ||
          normalizedText.startsWith('$phrase ') ||
          normalizedText.endsWith(' $phrase') ||
          normalizedText.contains(' $phrase ')) {
        return true;
      }
    }

    return false;
  }

  static String _normalizeForSafety(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
