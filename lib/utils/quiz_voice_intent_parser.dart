export 'voice_intent.dart';

import '../controllers/quiz_voice_controller.dart';
import '../services/voice_assistant_settings_service.dart';
import '../services/voice_command_learning_service.dart';
import 'voice_command_normalizer.dart';
import 'voice_intent.dart';

class VoiceParseResult {
  final VoiceIntent? intent;
  final double confidence;
  final String normalizedText;
  final String heardText;

  const VoiceParseResult({
    required this.intent,
    required this.confidence,
    required this.normalizedText,
    required this.heardText,
  });
}

class QuizVoiceIntentParser {
  static const double executeConfidenceThreshold = 0.78;
  static const double confirmationConfidenceThreshold = 0.60;
  static const double submitConfidenceThreshold = 0.90;
  static final VoiceCommandLearningService _learningService =
      VoiceCommandLearningService();

  static Future<VoiceParseResult> parse(
    QuizVoiceScreen screen,
    String heardText,
  ) async {
    final normalizedText = _normalizeForScreen(heardText);
    if (normalizedText.isEmpty) {
      return VoiceParseResult(
        intent: null,
        confidence: 0,
        normalizedText: normalizedText,
        heardText: heardText,
      );
    }

    final aliasMatch = _matchAliases(normalizedText, _aliasesFor(screen));
    if (aliasMatch != null) {
      return VoiceParseResult(
        intent: aliasMatch.intent,
        confidence: aliasMatch.confidence,
        normalizedText: normalizedText,
        heardText: heardText,
      );
    }

    if (screen == QuizVoiceScreen.quizSettings &&
        requestedQuestionCountFrom(normalizedText) != null) {
      return VoiceParseResult(
        intent: VoiceIntent.setQuestionCount,
        confidence: 0.92,
        normalizedText: normalizedText,
        heardText: heardText,
      );
    }

    if ((screen == QuizVoiceScreen.mcq ||
            screen == QuizVoiceScreen.examReview) &&
        questionNumberFrom(normalizedText) != null) {
      return VoiceParseResult(
        intent: VoiceIntent.questionNumber,
        confidence: 0.92,
        normalizedText: normalizedText,
        heardText: heardText,
      );
    }

    final learnedIntent = await _learningService.findLearnedIntent(
      normalizedText,
    );
    if (learnedIntent != null && _isIntentAvailable(screen, learnedIntent)) {
      return VoiceParseResult(
        intent: learnedIntent,
        confidence: 0.95,
        normalizedText: normalizedText,
        heardText: heardText,
      );
    }

    final fuzzyMatch = _matchAliases(
      normalizedText,
      _aliasesFor(screen),
      exactOnly: false,
    );
    if (fuzzyMatch != null) {
      return VoiceParseResult(
        intent: fuzzyMatch.intent,
        confidence: fuzzyMatch.confidence,
        normalizedText: normalizedText,
        heardText: heardText,
      );
    }

    return VoiceParseResult(
      intent: null,
      confidence: 0,
      normalizedText: normalizedText,
      heardText: heardText,
    );
  }

  static Future<void> rememberCorrection(
    String heardText,
    VoiceIntent intent,
  ) async {
    await _learningService.rememberCorrection(heardText, intent);
  }

  static bool shouldExecute(VoiceParseResult result) {
    return shouldExecuteWithSensitivity(result, CommandSensitivity.normal);
  }

  static bool shouldExecuteWithSensitivity(
    VoiceParseResult result,
    CommandSensitivity sensitivity,
  ) {
    final intent = result.intent;
    if (intent == null) return false;
    return result.confidence >= _executionThresholdFor(intent, sensitivity);
  }

  static String? confidenceFeedback(VoiceParseResult result) {
    return confidenceFeedbackWithSensitivity(result, CommandSensitivity.normal);
  }

  static String? confidenceFeedbackWithSensitivity(
    VoiceParseResult result,
    CommandSensitivity sensitivity,
  ) {
    if (shouldExecuteWithSensitivity(result, sensitivity)) return null;
    final intent = result.intent;
    if (intent == VoiceIntent.submit || intent == VoiceIntent.confirmSubmit) {
      return 'I did not understand. Say help to hear commands.';
    }
    if (intent != null &&
        result.confidence >= _confirmationThresholdFor(sensitivity)) {
      return 'Did you mean ${commandLabelFor(intent)}?';
    }
    return 'I did not understand. Say help to hear commands.';
  }

  static String commandLabelFor(VoiceIntent intent) {
    return switch (intent) {
      VoiceIntent.optionA => 'option a',
      VoiceIntent.optionB => 'option b',
      VoiceIntent.optionC => 'option c',
      VoiceIntent.optionD => 'option d',
      VoiceIntent.trueAnswer => 'true',
      VoiceIntent.falseAnswer => 'false',
      VoiceIntent.next => 'next',
      VoiceIntent.back => 'back',
      VoiceIntent.repeat => 'repeat',
      VoiceIntent.flag => 'flag',
      VoiceIntent.explain => 'explain',
      VoiceIntent.review => 'review',
      VoiceIntent.submit => 'submit',
      VoiceIntent.confirmSubmit => 'confirm submit',
      VoiceIntent.help => 'help',
      VoiceIntent.stopVoice => 'stop voice',
      VoiceIntent.startQuiz => 'start quiz',
      VoiceIntent.startTest => 'start test',
      VoiceIntent.timedModeOn => 'timed mode on',
      VoiceIntent.timedModeOff => 'timed mode off',
      VoiceIntent.maxQuestions => 'maximum questions',
      VoiceIntent.minQuestions => 'minimum questions',
      VoiceIntent.increaseQuestions => 'increase questions',
      VoiceIntent.decreaseQuestions => 'decrease questions',
      VoiceIntent.setQuestionCount => 'set question count',
      VoiceIntent.status => 'status',
      VoiceIntent.retry => 'retry',
      VoiceIntent.cancel => 'cancel',
      VoiceIntent.questionNumber => 'question number',
      VoiceIntent.pauseAssistant => 'pause',
      VoiceIntent.resumeAssistant => 'resume',
      VoiceIntent.unanswered => 'unanswered',
      VoiceIntent.speakFaster => 'speak faster',
      VoiceIntent.speakSlower => 'speak slower',
      VoiceIntent.speakNormal => 'normal speed',
    };
  }

  static bool canLearnCorrection(VoiceIntent? intent) {
    return intent != null &&
        intent != VoiceIntent.submit &&
        intent != VoiceIntent.confirmSubmit;
  }

  static bool isConfirmationText(String heardText) {
    final normalizedText = _normalizeForScreen(heardText);
    return const {
      'yes',
      'yeah',
      'yep',
      'confirm',
      'correct',
      'right',
      'that is right',
    }.contains(normalizedText);
  }

  static int? requestedQuestionCountFrom(String normalizedText) {
    final digitMatch = RegExp(
      r'^(?:set|choose|make|use)?\s*(?:questions?|question count)?\s*(?:to|two)?\s*(\d+)$',
    ).firstMatch(normalizedText);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1) ?? '');
    }

    final wordMatch = RegExp(
      r'^(?:set|choose|make|use)?\s*(?:questions?|question count)?\s*(?:to|two)?\s*([a-z\s]+)$',
    ).firstMatch(normalizedText);
    if (wordMatch == null) return null;
    return _parseSpokenNumber(wordMatch.group(1) ?? '');
  }

  static int? questionNumberFrom(String normalizedText) {
    final digitMatch = RegExp(
      r'^(?:question|go to question|go two question|go to|go two|number|q)\s*(\d+)$',
    ).firstMatch(normalizedText);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1) ?? '');
    }

    final wordMatch = RegExp(
      r'^(?:question|go to question|go two question|go to|go two|number|q)\s+([a-z\s]+)$',
    ).firstMatch(normalizedText);
    if (wordMatch == null) return null;

    final parsed = _parseSpokenNumber(wordMatch.group(1) ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static _AliasMatch? _matchAliases(
    String normalizedText,
    List<_AliasGroup> groups, {
    bool exactOnly = true,
  }) {
    _AliasMatch? bestMatch;
    for (final group in groups) {
      for (final alias in group.aliases) {
        final normalizedAlias = VoiceCommandNormalizer.normalize(alias);
        if (normalizedText == normalizedAlias) {
          return _AliasMatch(group.intent, 1);
        }
        if (exactOnly) continue;
        if (group.intent == VoiceIntent.confirmSubmit) {
          continue;
        }
        final confidence = _similarity(normalizedText, normalizedAlias);
        if (bestMatch == null || confidence > bestMatch.confidence) {
          bestMatch = _AliasMatch(group.intent, confidence);
        }
      }
    }
    if (bestMatch == null ||
        bestMatch.confidence < confirmationConfidenceThreshold) {
      return null;
    }
    return bestMatch;
  }

  static bool _isIntentAvailable(QuizVoiceScreen screen, VoiceIntent intent) {
    return _aliasesFor(screen).any((group) => group.intent == intent);
  }

  static String _normalizeForScreen(String heardText) {
    var normalizedText = VoiceCommandNormalizer.normalize(heardText);
    for (final phrase in _fillerPhrases) {
      normalizedText = normalizedText.replaceAll(
        RegExp('(^|\\s)${RegExp.escape(phrase)}(?=\\s|\$)'),
        ' ',
      );
    }
    return normalizedText.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<_AliasGroup> _aliasesFor(QuizVoiceScreen screen) {
    return [
      ..._globalAliases,
      ...switch (screen) {
        QuizVoiceScreen.quizSettings => _settingsAliases,
        QuizVoiceScreen.examSession => _sessionAliases,
        QuizVoiceScreen.examLoading => _loadingAliases,
        QuizVoiceScreen.mcq => _mcqAliases,
        QuizVoiceScreen.examReview => _reviewAliases,
        QuizVoiceScreen.none => const <_AliasGroup>[],
      },
    ];
  }

  static double _executionThresholdFor(
    VoiceIntent intent,
    CommandSensitivity sensitivity,
  ) {
    if (intent == VoiceIntent.submit) return submitConfidenceThreshold;
    return switch (sensitivity) {
      CommandSensitivity.strict => 0.86,
      CommandSensitivity.normal => executeConfidenceThreshold,
      CommandSensitivity.flexible => 0.70,
    };
  }

  static double _confirmationThresholdFor(CommandSensitivity sensitivity) {
    return switch (sensitivity) {
      CommandSensitivity.strict => 0.68,
      CommandSensitivity.normal => confirmationConfidenceThreshold,
      CommandSensitivity.flexible => 0.52,
    };
  }

  static double _similarity(String first, String second) {
    if (first == second) return 1;
    if (first.isEmpty || second.isEmpty) return 0;

    final distance = _levenshtein(first, second);
    final longest = first.length > second.length ? first.length : second.length;
    return 1 - (distance / longest);
  }

  static int _levenshtein(String first, String second) {
    if (first == second) return 0;
    if (first.isEmpty) return second.length;
    if (second.isEmpty) return first.length;

    final previous = List<int>.generate(second.length + 1, (index) => index);
    final current = List<int>.filled(second.length + 1, 0);

    for (int i = 0; i < first.length; i++) {
      current[0] = i + 1;
      for (int j = 0; j < second.length; j++) {
        final substitutionCost = first[i] == second[j] ? 0 : 1;
        final insertion = current[j] + 1;
        final deletion = previous[j + 1] + 1;
        final substitution = previous[j] + substitutionCost;
        current[j + 1] = [
          insertion,
          deletion,
          substitution,
        ].reduce((a, b) => a < b ? a : b);
      }
      for (int j = 0; j <= second.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[second.length];
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

    final tokens = rawValue
        .replaceAll(RegExp(r'[^a-z\s]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;

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
      if (token == 'and') continue;
      return null;
    }

    total += current;
    if (!matchedAny || total <= 0) return null;
    return total;
  }

  static const List<String> _fillerPhrases = [
    // Politeness / filler that adds no intent
    'please',
    'can you',
    'could you',
    'would you',
    'kindly',
    'maybe',
    'um',
    'uh',
    'er',
    'hmm',
    'well',
    'okay',
    'ok',
    'yeah',
    'yes please',
    // Self-reference / answer prefixes — strip so "the answer is B" -> "b"
    'the answer is',
    'answer is',
    'my answer is',
    "it's",
    'it is',
    "i'll go with",
    'i go with',
    'go with',
    "i'll pick",
    'i pick',
    "i'll choose",
    'i choose',
    "i'll select",
    'i select',
    'i think',
    "i think it's",
    'i think the answer is',
    'i believe',
    "i believe it's",
    "i'd say",
    'maybe its',
    'probably',
    "let's go with",
    "let's pick",
    "let's try",
    // Wishes / requests
    'i want to',
    'i want two',
    'i wanna',
    'i want',
    'let me',
    'show me',
    'give me',
    'take me to',
    'take me two',
    'go ahead and',
    'i would like to',
    'i would like two',
    'i would like',
  ];

  static const List<_AliasGroup> _globalAliases = [
    _AliasGroup(VoiceIntent.stopVoice, [
      'stop voice',
      'voice off',
      'stop voice mode',
      'turn off voice',
      'disable voice',
      'exit voice mode',
      'quit voice',
      'end voice',
      'kill voice',
      'voice mode off',
    ]),
    _AliasGroup(VoiceIntent.pauseAssistant, [
      // "stop" alone is the most natural way to silence the assistant
      // without turning voice mode off. Map it to pause, not stopVoice.
      'stop',
      'stop it',
      'stop now',
      'stop please',
      'stop talking',
      'stop reading',
      'stop speaking',
      // Frustrated user
      'shut up',
      'shut it',
      'be quiet',
      'quiet please',
      'silence',
      'hush',
      // Conversational pause
      'wait',
      'hold on',
      'one moment',
      'one second',
      'give me a second',
      'pause',
      'pause it',
      'pause please',
    ]),
    _AliasGroup(VoiceIntent.resumeAssistant, [
      'resume',
      'continue',
      'continue listening',
      'continue practice',
      'keep going',
      'go on',
      'unpause',
      'start again',
      "i'm back",
    ]),
    _AliasGroup(VoiceIntent.help, [
      'help',
      'help me',
      'what can i say',
      'what are the commands',
      'show commands',
      'show me commands',
      'what now',
      'i need help',
      'commands',
      'voice commands',
    ]),
    _AliasGroup(VoiceIntent.speakFaster, [
      'faster',
      'speak faster',
      'read faster',
      'speed up',
      'too slow',
      'go faster',
      'increase speed',
      'increase pace',
    ]),
    _AliasGroup(VoiceIntent.speakSlower, [
      'slower',
      'speak slower',
      'read slower',
      'slow down',
      'too fast',
      'go slower',
      'decrease speed',
      'decrease pace',
    ]),
    _AliasGroup(VoiceIntent.speakNormal, [
      'normal speed',
      'reset speed',
      'default speed',
      'normal pace',
      'reset pace',
    ]),
  ];

  static const List<_AliasGroup> _settingsAliases = [
    _AliasGroup(VoiceIntent.startQuiz, [
      'start quiz',
      'start',
      'begin quiz',
      'begin exam',
      'start exam',
    ]),
    _AliasGroup(VoiceIntent.back, ['back', 'previous', 'go home', 'home']),
    _AliasGroup(VoiceIntent.timedModeOn, [
      'timed mode on',
      'turn timed mode on',
      'enable timed mode',
      'timer on',
    ]),
    _AliasGroup(VoiceIntent.timedModeOff, [
      'timed mode off',
      'turn timed mode off',
      'disable timed mode',
      'timer off',
      'untimed mode',
    ]),
    _AliasGroup(VoiceIntent.maxQuestions, [
      'maximum questions',
      'max questions',
      'all questions',
    ]),
    _AliasGroup(VoiceIntent.minQuestions, [
      'minimum questions',
      'min questions',
      'one question',
    ]),
    _AliasGroup(VoiceIntent.increaseQuestions, [
      'increase questions',
      'more questions',
      'next questions',
    ]),
    _AliasGroup(VoiceIntent.decreaseQuestions, [
      'decrease questions',
      'less questions',
      'fewer questions',
    ]),
  ];

  static const List<_AliasGroup> _sessionAliases = [
    _AliasGroup(VoiceIntent.startTest, [
      'start test',
      'start quiz',
      'start',
      'begin test',
      'begin quiz',
      'begin exam',
      'continue',
    ]),
    _AliasGroup(VoiceIntent.back, [
      'back',
      'previous',
      'return',
      'return to settings',
      'back to settings',
    ]),
  ];

  static const List<_AliasGroup> _loadingAliases = [
    _AliasGroup(VoiceIntent.status, [
      'status',
      'repeat',
      'again',
      'read',
      'whats happening',
      "what's happening",
      'are you there',
      'how long',
    ]),
    _AliasGroup(VoiceIntent.retry, [
      'retry',
      'try again',
      'start again',
      'reload',
      'restart',
      'one more time',
    ]),
    _AliasGroup(VoiceIntent.cancel, [
      'cancel',
      'stop',
      "don't",
      'abort',
    ]),
    _AliasGroup(VoiceIntent.back, [
      'back',
      'go back',
      'previous',
      'return',
      'return question',
      'return to question',
      'go home',
      'home',
    ]),
  ];

  static const List<_AliasGroup> _mcqAliases = [
    _AliasGroup(VoiceIntent.optionA, [
      // Plain
      '1',
      'a',
      'ay',
      'eh',
      'hey',
      'one',
      'first',
      // Already-filler-stripped natural forms
      'option a',
      'answer a',
      'select a',
      'select option a',
      'choose a',
      'choose option a',
      'pick a',
      'pick option a',
      'letter a',
      'the letter a',
      'first option',
      'first one',
      'number one',
      'option one',
      'option 1',
      'a please',
      'just a',
    ]),
    _AliasGroup(VoiceIntent.optionB, [
      '2',
      'b',
      'bee',
      'be',
      'two',
      'to',
      'too',
      'second',
      'option b',
      'answer b',
      'select b',
      'select option b',
      'choose b',
      'choose option b',
      'pick b',
      'pick option b',
      'letter b',
      'the letter b',
      'second option',
      'second one',
      'number two',
      'option two',
      'option 2',
      'b please',
      'just b',
    ]),
    _AliasGroup(VoiceIntent.optionC, [
      '3',
      'c',
      'cee',
      'see',
      'sea',
      'three',
      'third',
      'option c',
      'answer c',
      'select c',
      'select option c',
      'choose c',
      'choose option c',
      'pick c',
      'pick option c',
      'letter c',
      'the letter c',
      'third option',
      'third one',
      'number three',
      'option three',
      'option 3',
      'c please',
      'just c',
    ]),
    _AliasGroup(VoiceIntent.optionD, [
      '4',
      'd',
      'dee',
      'di',
      'the',
      'four',
      'for',
      'fore',
      'fourth',
      'option d',
      'answer d',
      'select d',
      'select option d',
      'choose d',
      'choose option d',
      'pick d',
      'pick option d',
      'letter d',
      'the letter d',
      'fourth option',
      'fourth one',
      'last option',
      'number four',
      'option four',
      'option 4',
      'd please',
      'just d',
    ]),
    _AliasGroup(VoiceIntent.trueAnswer, [
      'true',
      'troo',
      'thats true',
      "that's true",
      'true answer',
      'correct',
      'true please',
      'i say true',
    ]),
    _AliasGroup(VoiceIntent.falseAnswer, [
      'false',
      'fals',
      'fall',
      'foul',
      'thats false',
      "that's false",
      'false answer',
      'wrong',
      'incorrect',
      'not true',
      'false please',
      'i say false',
    ]),
    _AliasGroup(VoiceIntent.next, [
      'next',
      'nex',
      'neckst',
      'next question',
      'next one',
      'go next',
      'move on',
      'move forward',
      'move ahead',
      'forward',
      'continue',
      'carry on',
      'proceed',
      'skip',
      'skip this',
      'skip it',
      'skip question',
    ]),
    _AliasGroup(VoiceIntent.back, [
      'back',
      'go back',
      'previous',
      'previous question',
      'last question',
      'one back',
      'go previous',
      'move back',
      'move backward',
      'backward',
      'return',
    ]),
    _AliasGroup(VoiceIntent.repeat, [
      'repeat',
      'repeat question',
      'repeat please',
      'again',
      'one more time',
      'say it again',
      'say that again',
      'read',
      'read it',
      'read again',
      'read question',
      'read the question',
      'read it again',
      'what was that',
      'what did you say',
      'come again',
      'huh',
      'sorry',
      "didn't catch that",
      "i didn't hear",
    ]),
    _AliasGroup(VoiceIntent.flag, [
      'flag',
      'flag it',
      'flag this',
      'flag question',
      'mark',
      'mark it',
      'mark this',
      'mark for review',
      'bookmark',
      'bookmark this',
      'save it',
      'save this',
      'remember this',
    ]),
    _AliasGroup(VoiceIntent.explain, [
      'explain',
      'explain it',
      'explain please',
      'why',
      'why is that',
      'tell me why',
      'tell me more',
      'explanation',
      'the explanation',
      'show explanation',
      'view explanation',
      'show me why',
      'show answer',
      'show the answer',
    ]),
    _AliasGroup(VoiceIntent.review, [
      'review',
      'revue',
      'ree view',
      'open review',
      'show review',
      'go to review',
      'review answers',
      'review my answers',
    ]),
    _AliasGroup(VoiceIntent.submit, [
      'submit',
      'sabmit',
      'sabit',
      'sub mit',
      'submit it',
      'submit exam',
      'submit quiz',
      'submit my answers',
      'submit answers',
      'finish',
      'finis',
      'fenish',
      'finish quiz',
      'finish exam',
      'finalize',
      'finalize quiz',
      'done',
      "i'm done",
      'all done',
      'complete',
      "i'm finished",
      'send it',
    ]),
  ];

  static const List<_AliasGroup> _reviewAliases = [
    _AliasGroup(VoiceIntent.confirmSubmit, [
      'confirm',
      'confirm submit',
      'confirm it',
      'yes',
      'yes submit',
      'yes confirm',
      'yes please',
      'yeah',
      'yep',
      'sure',
      'go ahead',
      'okay submit',
      'ok submit',
      'submit confirm',
      "i'm sure",
    ]),
    _AliasGroup(VoiceIntent.cancel, [
      'cancel',
      'cancel submit',
      'no',
      'nope',
      'not yet',
      "don't submit",
      'wait',
      'nevermind',
      'never mind',
      'go back',
    ]),
    _AliasGroup(VoiceIntent.submit, [
      'submit',
      'sabmit',
      'sabit',
      'sub mit',
      'submit it',
      'submit exam',
      'submit quiz',
      'submit answers',
      'submit my answers',
      'finish',
      'finis',
      'fenish',
      'finish quiz',
      'finish exam',
      'final submit',
      'finalize',
      'done',
      "i'm done",
      "i'm finished",
      'complete',
      'send it',
    ]),
    _AliasGroup(VoiceIntent.back, [
      'back',
      'go back',
      'previous',
      'return',
      'return question',
      'return to question',
      'go to question',
      'return to quiz',
      'back to quiz',
      'back to questions',
    ]),
    _AliasGroup(VoiceIntent.unanswered, [
      'unanswered',
      'show unanswered',
      'show unanswered questions',
      'what did i miss',
      'missing answers',
      'skipped',
    ]),
    _AliasGroup(VoiceIntent.flag, [
      'flag',
      'flagged',
      'show flagged',
      'mark',
      'bookmark',
      'marked',
    ]),
    _AliasGroup(VoiceIntent.repeat, [
      'repeat',
      'again',
      'read',
      'read again',
      'say it again',
      'summary',
      'show summary',
      'read summary',
    ]),
  ];
}

class _AliasGroup {
  final VoiceIntent intent;
  final List<String> aliases;

  const _AliasGroup(this.intent, this.aliases);
}

class _AliasMatch {
  final VoiceIntent intent;
  final double confidence;

  const _AliasMatch(this.intent, this.confidence);
}
