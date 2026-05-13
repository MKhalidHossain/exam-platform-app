import '../core/voice_command_context.dart';
import '../core/voice_intent.dart';
import '../core/voice_safety_policy.dart';

class VoiceCommandAlias {
  final VoiceScreenContext context;
  final String phrase;
  final VoiceIntent intent;
  final double baseConfidence;
  final bool isSingleLetter;

  const VoiceCommandAlias({
    required this.context,
    required this.phrase,
    required this.intent,
    this.baseConfidence = 1.0,
    this.isSingleLetter = false,
  });
}

class VoiceCommandPatternAlias {
  final VoiceScreenContext context;
  final RegExp pattern;
  final VoiceIntentType intentType;
  final String phraseTemplate;

  const VoiceCommandPatternAlias({
    required this.context,
    required this.pattern,
    required this.intentType,
    required this.phraseTemplate,
  });

  VoiceIntent toIntent({
    required String rawText,
    required String normalizedText,
    required int number,
    double confidence = 1.0,
  }) {
    return VoiceCommandAliases.intentFor(
      type: intentType,
      phrase: normalizedText,
      rawText: rawText,
      normalizedText: normalizedText,
      number: number,
      confidence: confidence,
    );
  }
}

class VoiceCommandAliases {
  static const double singleLetterConfidence = 0.62;

  const VoiceCommandAliases._();

  static List<VoiceCommandAlias> forContext(
    VoiceScreenContext context, {
    bool includeGlobal = true,
  }) {
    return aliases
        .where(
          (alias) =>
              alias.context == context ||
              (includeGlobal && alias.context == VoiceScreenContext.global),
        )
        .toList(growable: false);
  }

  static List<VoiceCommandPatternAlias> patternsForContext(
    VoiceScreenContext context,
  ) {
    return patternAliases
        .where((alias) => alias.context == context)
        .toList(growable: false);
  }

  static VoiceIntent intentFor({
    required VoiceIntentType type,
    required String phrase,
    String? rawText,
    String? normalizedText,
    String? value,
    int? number,
    double confidence = 1.0,
  }) {
    return VoiceIntent(
      type: type,
      value: value,
      number: number,
      confidence: confidence,
      isRisky:
          VoiceSafetyPolicy.isRiskyIntentType(type) ||
          VoiceSafetyPolicy.isRiskyText(phrase),
      rawText: rawText ?? phrase,
      normalizedText: normalizedText ?? phrase,
      source: 'alias_registry',
    );
  }

  static VoiceCommandAlias _alias(
    VoiceScreenContext context,
    String phrase,
    VoiceIntentType type, {
    String? value,
    double confidence = 1.0,
    bool isSingleLetter = false,
  }) {
    return VoiceCommandAlias(
      context: context,
      phrase: phrase,
      intent: intentFor(
        type: type,
        phrase: phrase,
        value: value,
        confidence: confidence,
      ),
      baseConfidence: confidence,
      isSingleLetter: isSingleLetter,
    );
  }

  static final List<VoiceCommandAlias> aliases = [
    ..._quizAliases,
    ..._reviewAliases,
    ..._settingsAliases,
    ..._sessionAliases,
    ..._loadingAliases,
    ..._globalAliases,
  ];

  static final List<VoiceCommandPatternAlias> patternAliases = [
    VoiceCommandPatternAlias(
      context: VoiceScreenContext.quiz,
      pattern: RegExp(r'^(?:question|go to question|go to|number|q)\s+(\d+)$'),
      intentType: VoiceIntentType.questionNumber,
      phraseTemplate: 'question <number>',
    ),
    VoiceCommandPatternAlias(
      context: VoiceScreenContext.review,
      pattern: RegExp(r'^(?:question|go to question|go to|number|q)\s+(\d+)$'),
      intentType: VoiceIntentType.questionNumber,
      phraseTemplate: 'question <number>',
    ),
    VoiceCommandPatternAlias(
      context: VoiceScreenContext.settings,
      pattern: RegExp(
        r'^(?:set|choose|make|use)?\s*(?:questions?|question count)\s+(?:to\s+)?(\d+)$',
      ),
      intentType: VoiceIntentType.setQuestionCount,
      phraseTemplate: 'set questions to <number>',
    ),
  ];

  static final List<VoiceCommandAlias> _quizAliases = [
    _alias(
      VoiceScreenContext.quiz,
      'option a',
      VoiceIntentType.optionA,
      value: 'a',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'answer a',
      VoiceIntentType.optionA,
      value: 'a',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'select a',
      VoiceIntentType.optionA,
      value: 'a',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'first option',
      VoiceIntentType.optionA,
      value: 'a',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'a',
      VoiceIntentType.optionA,
      value: 'a',
      confidence: singleLetterConfidence,
      isSingleLetter: true,
    ),
    _alias(
      VoiceScreenContext.quiz,
      'option b',
      VoiceIntentType.optionB,
      value: 'b',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'answer b',
      VoiceIntentType.optionB,
      value: 'b',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'select b',
      VoiceIntentType.optionB,
      value: 'b',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'second option',
      VoiceIntentType.optionB,
      value: 'b',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'b',
      VoiceIntentType.optionB,
      value: 'b',
      confidence: singleLetterConfidence,
      isSingleLetter: true,
    ),
    _alias(
      VoiceScreenContext.quiz,
      'option c',
      VoiceIntentType.optionC,
      value: 'c',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'answer c',
      VoiceIntentType.optionC,
      value: 'c',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'select c',
      VoiceIntentType.optionC,
      value: 'c',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'third option',
      VoiceIntentType.optionC,
      value: 'c',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'c',
      VoiceIntentType.optionC,
      value: 'c',
      confidence: singleLetterConfidence,
      isSingleLetter: true,
    ),
    _alias(
      VoiceScreenContext.quiz,
      'option d',
      VoiceIntentType.optionD,
      value: 'd',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'answer d',
      VoiceIntentType.optionD,
      value: 'd',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'select d',
      VoiceIntentType.optionD,
      value: 'd',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'fourth option',
      VoiceIntentType.optionD,
      value: 'd',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'd',
      VoiceIntentType.optionD,
      value: 'd',
      confidence: singleLetterConfidence,
      isSingleLetter: true,
    ),
    _alias(
      VoiceScreenContext.quiz,
      'true',
      VoiceIntentType.trueAnswer,
      value: 'true',
    ),
    _alias(
      VoiceScreenContext.quiz,
      'false',
      VoiceIntentType.falseAnswer,
      value: 'false',
    ),
    _alias(VoiceScreenContext.quiz, 'next question', VoiceIntentType.next),
    _alias(VoiceScreenContext.quiz, 'next', VoiceIntentType.next),
    _alias(
      VoiceScreenContext.quiz,
      'previous question',
      VoiceIntentType.previous,
    ),
    _alias(VoiceScreenContext.quiz, 'previous', VoiceIntentType.previous),
    _alias(VoiceScreenContext.quiz, 'back', VoiceIntentType.previous),
    _alias(VoiceScreenContext.quiz, 'skip question', VoiceIntentType.skip),
    _alias(VoiceScreenContext.quiz, 'skip', VoiceIntentType.skip),
    _alias(
      VoiceScreenContext.quiz,
      'read question',
      VoiceIntentType.readQuestion,
    ),
    _alias(VoiceScreenContext.quiz, 'repeat question', VoiceIntentType.repeat),
    _alias(VoiceScreenContext.quiz, 'explain answer', VoiceIntentType.explain),
    _alias(VoiceScreenContext.quiz, 'flag question', VoiceIntentType.flag),
    _alias(
      VoiceScreenContext.quiz,
      'bookmark question',
      VoiceIntentType.bookmark,
    ),
    _alias(VoiceScreenContext.quiz, 'open review', VoiceIntentType.review),
    _alias(VoiceScreenContext.quiz, 'submit quiz', VoiceIntentType.submit),
  ];

  static final List<VoiceCommandAlias> _reviewAliases = [
    _alias(VoiceScreenContext.review, 'unanswered', VoiceIntentType.unanswered),
    _alias(VoiceScreenContext.review, 'flagged', VoiceIntentType.flagged),
    _alias(
      VoiceScreenContext.review,
      'read summary',
      VoiceIntentType.readSummary,
    ),
    _alias(VoiceScreenContext.review, 'summary', VoiceIntentType.readSummary),
    _alias(VoiceScreenContext.review, 'submit quiz', VoiceIntentType.submit),
    _alias(
      VoiceScreenContext.review,
      'confirm submit',
      VoiceIntentType.confirmSubmit,
    ),
    _alias(
      VoiceScreenContext.review,
      'cancel submit',
      VoiceIntentType.cancelSubmit,
    ),
  ];

  static final List<VoiceCommandAlias> _settingsAliases = [
    _alias(
      VoiceScreenContext.settings,
      'start quiz',
      VoiceIntentType.startQuiz,
    ),
    _alias(
      VoiceScreenContext.settings,
      'timed mode on',
      VoiceIntentType.timedModeOn,
    ),
    _alias(
      VoiceScreenContext.settings,
      'timed mode off',
      VoiceIntentType.timedModeOff,
    ),
    _alias(
      VoiceScreenContext.settings,
      'increase questions',
      VoiceIntentType.increaseQuestions,
    ),
    _alias(
      VoiceScreenContext.settings,
      'decrease questions',
      VoiceIntentType.decreaseQuestions,
    ),
    _alias(
      VoiceScreenContext.settings,
      'more questions',
      VoiceIntentType.increaseQuestions,
    ),
    _alias(
      VoiceScreenContext.settings,
      'fewer questions',
      VoiceIntentType.decreaseQuestions,
    ),
  ];

  static final List<VoiceCommandAlias> _sessionAliases = [
    _alias(VoiceScreenContext.session, 'start test', VoiceIntentType.startTest),
    _alias(VoiceScreenContext.session, 'start quiz', VoiceIntentType.startTest),
    _alias(VoiceScreenContext.session, 'retry', VoiceIntentType.retry),
    _alias(VoiceScreenContext.session, 'cancel', VoiceIntentType.cancel),
    _alias(VoiceScreenContext.session, 'back', VoiceIntentType.back),
    _alias(VoiceScreenContext.session, 'help', VoiceIntentType.help),
    _alias(VoiceScreenContext.session, 'status', VoiceIntentType.status),
  ];

  static final List<VoiceCommandAlias> _loadingAliases = [
    _alias(VoiceScreenContext.loading, 'start test', VoiceIntentType.startTest),
    _alias(VoiceScreenContext.loading, 'retry', VoiceIntentType.retry),
    _alias(VoiceScreenContext.loading, 'try again', VoiceIntentType.retry),
    _alias(VoiceScreenContext.loading, 'cancel', VoiceIntentType.cancel),
    _alias(VoiceScreenContext.loading, 'back', VoiceIntentType.back),
    _alias(VoiceScreenContext.loading, 'help', VoiceIntentType.help),
    _alias(VoiceScreenContext.loading, 'status', VoiceIntentType.status),
  ];

  static final List<VoiceCommandAlias> _globalAliases = [
    _alias(VoiceScreenContext.global, 'pause', VoiceIntentType.pauseAssistant),
    _alias(VoiceScreenContext.global, 'quiet', VoiceIntentType.pauseAssistant),
    _alias(
      VoiceScreenContext.global,
      'stop reading',
      VoiceIntentType.pauseAssistant,
    ),
    _alias(
      VoiceScreenContext.global,
      'resume',
      VoiceIntentType.resumeAssistant,
    ),
    _alias(
      VoiceScreenContext.global,
      'continue listening',
      VoiceIntentType.resumeAssistant,
    ),
    _alias(VoiceScreenContext.global, 'help', VoiceIntentType.help),
  ];
}
