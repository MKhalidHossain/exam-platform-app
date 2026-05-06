import '../controllers/quiz_voice_controller.dart';
import 'voice_command_matcher.dart';

enum QuizVoiceIntent {
  unknown,
  stopVoiceMode,
  help,
  startQuiz,
  nextQuestion,
  goBack,
  pauseAssistant,
  timedModeOn,
  timedModeOff,
  maxQuestions,
  minQuestions,
  increaseQuestions,
  decreaseQuestions,
  setQuestionCount,
  startTest,
  explainQuestion,
  openReview,
  status,
  retry,
  cancel,
  questionNumber,
  confirmSubmit,
  submit,
  unanswered,
  flagged,
  readSummary,
}

class QuizVoiceIntentResult {
  final QuizVoiceIntent intent;
  final String rawText;
  final String normalizedText;
  final int? numberValue;

  const QuizVoiceIntentResult({
    required this.intent,
    required this.rawText,
    required this.normalizedText,
    this.numberValue,
  });
}

class QuizVoiceIntentParser {
  static QuizVoiceIntentResult parse(QuizVoiceScreen screen, String rawText) {
    final normalized = _normalizeForScreen(screen, rawText);

    switch (screen) {
      case QuizVoiceScreen.quizSettings:
        return _parseSettings(rawText, normalized);
      case QuizVoiceScreen.examSession:
        return _parseSession(rawText, normalized);
      case QuizVoiceScreen.examLoading:
        return _parseLoading(rawText, normalized);
      case QuizVoiceScreen.mcq:
        return _parseMcq(rawText, normalized);
      case QuizVoiceScreen.examReview:
        return _parseReview(rawText, normalized);
      case QuizVoiceScreen.none:
        return QuizVoiceIntentResult(
          intent: QuizVoiceIntent.unknown,
          rawText: rawText,
          normalizedText: normalized,
        );
    }
  }

  static QuizVoiceIntentResult _parseSettings(
    String rawText,
    String normalized,
  ) {
    if (_matches(normalized, _stopCommands)) {
      return _result(QuizVoiceIntent.stopVoiceMode, rawText, normalized);
    }
    if (_matches(normalized, [
      'help',
      'commands',
      'what can i say',
      'read',
      'repeat',
    ])) {
      return _result(QuizVoiceIntent.help, rawText, normalized);
    }
    if (_matches(normalized, [
      'start',
      'start quiz',
      'begin quiz',
      'begin exam',
      'start exam',
    ])) {
      return _result(QuizVoiceIntent.startQuiz, rawText, normalized);
    }
    if (_matches(normalized, [
      'back',
      'go back',
      'return',
      'go home',
      'home',
    ])) {
      return _result(QuizVoiceIntent.goBack, rawText, normalized);
    }
    if (_matches(normalized, [
      'timed mode on',
      'turn timed mode on',
      'enable timed mode',
      'timer on',
      'timed on',
    ])) {
      return _result(QuizVoiceIntent.timedModeOn, rawText, normalized);
    }
    if (_matches(normalized, [
      'timed mode off',
      'turn timed mode off',
      'disable timed mode',
      'timer off',
      'untimed mode',
      'timed off',
    ])) {
      return _result(QuizVoiceIntent.timedModeOff, rawText, normalized);
    }
    if (_matches(normalized, [
      'maximum questions',
      'max questions',
      'all questions',
    ])) {
      return _result(QuizVoiceIntent.maxQuestions, rawText, normalized);
    }
    if (_matches(normalized, [
      'minimum questions',
      'min questions',
      'one question',
    ])) {
      return _result(QuizVoiceIntent.minQuestions, rawText, normalized);
    }
    if (_matches(normalized, [
      'increase questions',
      'more questions',
      'next questions',
    ])) {
      return _result(QuizVoiceIntent.increaseQuestions, rawText, normalized);
    }
    if (_matches(normalized, [
      'decrease questions',
      'less questions',
      'fewer questions',
    ])) {
      return _result(QuizVoiceIntent.decreaseQuestions, rawText, normalized);
    }

    final requestedCount = _extractRequestedQuestionCount(normalized);
    if (requestedCount != null) {
      return _result(
        QuizVoiceIntent.setQuestionCount,
        rawText,
        normalized,
        numberValue: requestedCount,
      );
    }

    return _result(QuizVoiceIntent.unknown, rawText, normalized);
  }

  static QuizVoiceIntentResult _parseSession(
    String rawText,
    String normalized,
  ) {
    if (_matches(normalized, _stopCommands)) {
      return _result(QuizVoiceIntent.stopVoiceMode, rawText, normalized);
    }
    if (_matches(normalized, [
      'help',
      'commands',
      'what can i say',
      'read',
      'repeat',
    ])) {
      return _result(QuizVoiceIntent.help, rawText, normalized);
    }
    if (_matches(normalized, [
      'start',
      'start quiz',
      'start test',
      'begin quiz',
      'begin exam',
      'start exam',
      'continue',
    ])) {
      return _result(QuizVoiceIntent.startTest, rawText, normalized);
    }
    if (_matches(normalized, [
      'back',
      'go back',
      'return',
      'return to settings',
      'back to settings',
    ])) {
      return _result(QuizVoiceIntent.goBack, rawText, normalized);
    }
    return _result(QuizVoiceIntent.unknown, rawText, normalized);
  }

  static QuizVoiceIntentResult _parseLoading(
    String rawText,
    String normalized,
  ) {
    if (_matches(normalized, _stopCommands)) {
      return _result(QuizVoiceIntent.stopVoiceMode, rawText, normalized);
    }
    if (_matches(normalized, [
      'status',
      'read',
      'repeat',
      'help',
      'commands',
      'what can i say',
    ])) {
      return _result(QuizVoiceIntent.status, rawText, normalized);
    }
    if (_matches(normalized, ['retry', 'try again', 'start again'])) {
      return _result(QuizVoiceIntent.retry, rawText, normalized);
    }
    if (_matches(normalized, ['cancel', 'back', 'go back', 'return'])) {
      return _result(QuizVoiceIntent.cancel, rawText, normalized);
    }
    return _result(QuizVoiceIntent.unknown, rawText, normalized);
  }

  static QuizVoiceIntentResult _parseMcq(String rawText, String normalized) {
    if (_matches(normalized, _stopCommands)) {
      return _result(QuizVoiceIntent.stopVoiceMode, rawText, normalized);
    }
    if (_matches(normalized, [
      'next',
      'skip',
      'continue',
      'go next',
      'move on',
    ])) {
      return _result(QuizVoiceIntent.nextQuestion, rawText, normalized);
    }
    if (_matches(normalized, [
      'back',
      'previous',
      'go back',
      'prev',
      'last question',
    ])) {
      return _result(QuizVoiceIntent.goBack, rawText, normalized);
    }
    final targetQuestionNumber = _extractQuestionNumber(normalized);
    if (targetQuestionNumber != null) {
      return _result(
        QuizVoiceIntent.questionNumber,
        rawText,
        normalized,
        numberValue: targetQuestionNumber,
      );
    }
    if (_matches(normalized, [
      'flag',
      'mark',
      'bookmark',
      'flag this',
      'mark this',
    ])) {
      return _result(QuizVoiceIntent.flagged, rawText, normalized);
    }
    if (_matches(normalized, [
      'read',
      'repeat',
      'again',
      'read again',
      're read',
      'say again',
      'read question',
    ])) {
      return _result(QuizVoiceIntent.readSummary, rawText, normalized);
    }
    if (_matches(normalized, [
      'explain',
      'explanation',
      'why',
      'show explanation',
      'view explanation',
      'read explanation',
    ])) {
      return _result(QuizVoiceIntent.explainQuestion, rawText, normalized);
    }
    if (_matches(normalized, [
      'review',
      'open review',
      'exam review',
      'review screen',
      'go to review',
      'check review',
      'open exam review',
      'show review',
    ])) {
      return _result(QuizVoiceIntent.openReview, rawText, normalized);
    }
    if (_matches(normalized, [
      'submit',
      'done',
      'finish',
      'complete',
      'end exam',
      'submit exam',
    ])) {
      return _result(QuizVoiceIntent.submit, rawText, normalized);
    }
    if (_matches(normalized, [
      'quiet',
      'silence',
      'pause',
      'stop reading',
      'cancel',
    ])) {
      return _result(QuizVoiceIntent.pauseAssistant, rawText, normalized);
    }
    if (_matches(normalized, [
      'help',
      'commands',
      'what can i say',
      'instructions',
    ])) {
      return _result(QuizVoiceIntent.help, rawText, normalized);
    }
    return _result(QuizVoiceIntent.unknown, rawText, normalized);
  }

  static QuizVoiceIntentResult _parseReview(String rawText, String normalized) {
    if (_matches(normalized, _stopCommands)) {
      return _result(QuizVoiceIntent.stopVoiceMode, rawText, normalized);
    }

    final targetQuestionNumber = _extractQuestionNumber(normalized);
    if (targetQuestionNumber != null) {
      return _result(
        QuizVoiceIntent.questionNumber,
        rawText,
        normalized,
        numberValue: targetQuestionNumber,
      );
    }

    if (_matches(normalized, [
      'confirm',
      'confirm submit',
      'yes submit',
      'submit confirm',
      'confirm finish',
    ])) {
      return _result(QuizVoiceIntent.confirmSubmit, rawText, normalized);
    }
    if (_matches(normalized, [
      'submit',
      'finish',
      'done',
      'complete',
      'submit exam',
    ])) {
      return _result(QuizVoiceIntent.submit, rawText, normalized);
    }
    if (_matches(normalized, [
      'back',
      'return',
      'go back',
      'take me back',
      'go to previous question',
      'return to previous question',
      'return to last question',
      'previous question',
      'last question',
      'return to question',
      'back to exam',
    ])) {
      return _result(QuizVoiceIntent.goBack, rawText, normalized);
    }
    if (_matches(normalized, [
      'unanswered',
      'review unanswered',
      'open unanswered',
    ])) {
      return _result(QuizVoiceIntent.unanswered, rawText, normalized);
    }
    if (_matches(normalized, ['flagged', 'review flagged', 'open flagged'])) {
      return _result(QuizVoiceIntent.flagged, rawText, normalized);
    }
    if (_matches(normalized, [
      'read',
      'repeat',
      'again',
      'summary',
      'review',
    ])) {
      return _result(QuizVoiceIntent.readSummary, rawText, normalized);
    }
    if (_matches(normalized, ['help', 'commands', 'what can i say'])) {
      return _result(QuizVoiceIntent.help, rawText, normalized);
    }
    return _result(QuizVoiceIntent.unknown, rawText, normalized);
  }

  static QuizVoiceIntentResult _result(
    QuizVoiceIntent intent,
    String rawText,
    String normalized, {
    int? numberValue,
  }) {
    return QuizVoiceIntentResult(
      intent: intent,
      rawText: rawText,
      normalizedText: normalized,
      numberValue: numberValue,
    );
  }

  static bool _matches(String text, List<String> keywords) =>
      VoiceCommandMatcher.matchesAny(text, keywords);

  static String _normalizeForScreen(QuizVoiceScreen screen, String rawText) {
    var text = rawText.toLowerCase();
    text = text.replaceAll("'", '');
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    const fillerPhrases = [
      'please',
      'can you',
      'could you',
      'would you',
      'i want to',
      'i wanna',
      'let me',
      'show me',
      'take me to',
      'go ahead and',
      'i would like to',
    ];
    for (final filler in fillerPhrases) {
      text = text.replaceAll(filler, ' ');
    }

    final aliases = <String, String>{
      ..._globalAliases,
      ...switch (screen) {
        QuizVoiceScreen.quizSettings => _settingsAliases,
        QuizVoiceScreen.examSession => _sessionAliases,
        QuizVoiceScreen.examLoading => _loadingAliases,
        QuizVoiceScreen.mcq => _mcqAliases,
        QuizVoiceScreen.examReview => _reviewAliases,
        QuizVoiceScreen.none => const <String, String>{},
      },
    };

    aliases.forEach((from, to) {
      text = text.replaceAll(from, to);
    });

    return VoiceCommandMatcher.normalizeText(
      text.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
  }

  static int? _extractRequestedQuestionCount(String text) {
    final digitMatch = RegExp(
      r'(?:set|choose|make|use)?\s*(?:questions?|question count)?\s*(?:to)?\s*(\d+)',
    ).firstMatch(text);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1) ?? '');
    }

    final wordMatch = RegExp(
      r'(?:set|choose|make|use)?\s*(?:questions?|question count)?\s*(?:to)?\s*([a-z\s-]+)',
    ).firstMatch(text);
    if (wordMatch == null) return null;
    return _parseSpokenNumber(wordMatch.group(1) ?? '');
  }

  static int? _extractQuestionNumber(String text) {
    final digitMatch = RegExp(
      r'(?:question|go to|number|q)\s*(\d+)',
    ).firstMatch(text);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1) ?? '');
    }

    final wordMatch = RegExp(
      r'(?:question|go to|number|q)\s+([a-z\s-]+)',
    ).firstMatch(text);
    if (wordMatch == null) return null;

    final parsed = _parseSpokenNumber(wordMatch.group(1) ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static int? _parseSpokenNumber(String rawValue) {
    final units = <String, int>{
      'zero': 0,
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
      'eleven': 11,
      'twelve': 12,
      'thirteen': 13,
      'fourteen': 14,
      'fifteen': 15,
      'sixteen': 16,
      'seventeen': 17,
      'eighteen': 18,
      'nineteen': 19,
      'first': 1,
      'second': 2,
      'third': 3,
      'fourth': 4,
      'fifth': 5,
      'sixth': 6,
      'seventh': 7,
      'eighth': 8,
      'ninth': 9,
      'tenth': 10,
    };
    final tens = <String, int>{
      'twenty': 20,
      'thirty': 30,
      'forty': 40,
      'fifty': 50,
      'sixty': 60,
      'seventy': 70,
      'eighty': 80,
      'ninety': 90,
    };

    final cleaned = rawValue
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'[^a-z\s]'), ' ')
        .trim();
    if (cleaned.isEmpty) return null;

    final tokens = cleaned.split(RegExp(r'\s+'));
    int total = 0;
    int current = 0;
    bool matchedAny = false;

    for (final token in tokens) {
      if (units.containsKey(token)) {
        current += units[token]!;
        matchedAny = true;
        continue;
      }
      if (tens.containsKey(token)) {
        current += tens[token]!;
        matchedAny = true;
        continue;
      }
      if (token == 'hundred') {
        current = current == 0 ? 100 : current * 100;
        matchedAny = true;
        continue;
      }
      if (token == 'and') {
        continue;
      }
      break;
    }

    total += current;
    if (!matchedAny || total <= 0) return null;
    return total;
  }

  static const List<String> _stopCommands = [
    'stop',
    'stop voice',
    'stop voice mode',
    'turn off voice',
    'disable voice',
    'exit voice mode',
  ];

  static const Map<String, String> _globalAliases = {
    'read again': 'read',
    'say again': 'read',
  };

  static const Map<String, String> _settingsAliases = {
    'timed mode enable': 'timed mode on',
    'enable timer': 'timed mode on',
    'disable timer': 'timed mode off',
    'without time': 'timed mode off',
    'with time': 'timed mode on',
    'number of questions': 'questions',
    'question number': 'questions',
    'start the quiz': 'start quiz',
    'begin the quiz': 'start quiz',
    'return home': 'go home',
  };

  static const Map<String, String> _sessionAliases = {
    'begin the test': 'start test',
    'start the test': 'start test',
    'start the quiz': 'start quiz',
    'go to settings': 'back to settings',
    'return settings': 'back to settings',
  };

  static const Map<String, String> _loadingAliases = {'start again': 'retry'};

  static const Map<String, String> _mcqAliases = {
    'go next': 'next',
    'move next': 'next',
    'move forward': 'next',
    'go forward': 'next',
    'go previous': 'back',
    'previous question': 'back',
    'go review': 'review',
    'open the review': 'review',
    'submit now': 'submit',
    'finish exam': 'submit',
    'read question': 'read',
    'show explanation': 'explain',
    'view explanation': 'explain',
    'mark review': 'flag',
  };

  static const Map<String, String> _reviewAliases = {
    'go previous': 'back',
    'go back to exam': 'back',
    'return to exam': 'back',
    'take me back': 'back',
    'go to previous question': 'back',
    'return to previous question': 'back',
    'return to last question': 'back',
    'previous question': 'back',
    'last question': 'back',
    'open unanswered': 'unanswered',
    'review unanswered': 'unanswered',
    'open flagged': 'flagged',
    'review flagged': 'flagged',
    'finish exam': 'submit',
    'submit now': 'submit',
    'submit exam now': 'submit exam',
    'finish now': 'submit',
    'yes confirm': 'confirm submit',
    'confirm now': 'confirm submit',
    'confirm summit': 'confirm submit',
    'confirm sumit': 'confirm submit',
    'review summary': 'summary',
  };
}
