import '../../controllers/quiz_voice_controller.dart';

/// Canonical command vocabulary the assistant expects on each screen.
///
/// One source of truth for:
/// * the `availableCommands` list passed to the cloud fallback transcriber
///   (`CloudSpeechService.transcribeCommand`), which already accepts it
///   and forwards it to the backend for prompt biasing;
/// * the future on-device Whisper hot-words list (Phase 2 engine swap);
/// * any UI affordance that wants to render the supported commands.
///
/// Previously each screen redeclared its own inline `availableCommands`
/// list (e.g. mcq_screen.dart and exam_review_screen.dart). Centralising
/// it makes biasing decisions consistent and keeps the prompt aligned
/// with the parser's intent set.
class VoiceCommandVocabulary {
  const VoiceCommandVocabulary._();

  static const List<String> _shared = <String>[
    'help',
    'what can i say',
    'stop',
    'pause',
    'resume',
    'continue',
    'wait',
    'stop voice mode',
  ];

  static const List<String> _mcq = <String>[
    // Answer letters — single, spelled, and natural framings
    'a',
    'b',
    'c',
    'd',
    'option a',
    'option b',
    'option c',
    'option d',
    'the answer is a',
    'the answer is b',
    'the answer is c',
    'the answer is d',
    'i think a',
    'i think b',
    'i think c',
    'i think d',
    'pick a',
    'pick b',
    'pick c',
    'pick d',
    'select a',
    'select b',
    'select c',
    'select d',
    'choose a',
    'choose b',
    'choose c',
    'choose d',
    'letter a',
    'letter b',
    'letter c',
    'letter d',
    // True/False
    'true',
    'false',
    // Multi-select
    'a and b',
    'a and c',
    'b and d',
    // Navigation
    'next',
    'next question',
    'next one',
    'move on',
    'continue',
    'back',
    'go back',
    'previous',
    'previous question',
    'go to question',
    'first question',
    'last question',
    'skip',
    'skip this',
    // Question utilities
    'repeat',
    'repeat question',
    'read again',
    'say it again',
    'what did you say',
    'explain',
    'explain it',
    'why',
    'tell me why',
    'explanation',
    'flag',
    'flag question',
    'bookmark',
    'mark it',
    'unflag',
    // Review / submit
    'review',
    'submit',
    'finish',
    'done',
    "i'm done",
  ];

  static const List<String> _examReview = <String>[
    'submit',
    'finish',
    'return to question',
    'go back to question',
    'unanswered',
    'show unanswered',
    'flagged',
    'show flagged',
    'back',
    'cancel',
  ];

  static const List<String> _examLoading = <String>[
    'status',
    'retry',
    'cancel',
    'back',
  ];

  static const List<String> _examSession = <String>[
    'start',
    'begin',
    'cancel',
    'back',
  ];

  static const List<String> _quizSettings = <String>[
    'save',
    'cancel',
    'reset',
    'back',
  ];

  /// Returns the deduplicated command list for [screen], with the always-on
  /// shared commands appended. Lowercase, ready to be sent as hot-words.
  static List<String> commandsFor(QuizVoiceScreen screen) {
    final List<String> specific = switch (screen) {
      QuizVoiceScreen.mcq => _mcq,
      QuizVoiceScreen.examReview => _examReview,
      QuizVoiceScreen.examLoading => _examLoading,
      QuizVoiceScreen.examSession => _examSession,
      QuizVoiceScreen.quizSettings => _quizSettings,
      QuizVoiceScreen.none => const <String>[],
    };
    final merged = <String>{...specific, ..._shared};
    return List<String>.unmodifiable(merged);
  }

  /// Single-word answers most commonly mis-recognised by accent-naive STT
  /// engines. Promoted aggressively in hot-words to lift their decoder
  /// probability above visually-similar English words ("be" -> "b").
  static const List<String> singleLetterAnswers = <String>['a', 'b', 'c', 'd'];
}
