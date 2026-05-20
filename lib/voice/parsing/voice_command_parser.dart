import 'package:flutter/foundation.dart';

import '../core/voice_command_context.dart';
import '../core/voice_command_result.dart';
import '../core/voice_intent.dart';
import '../core/voice_safety_policy.dart';
import 'fuzzy_matcher.dart';
import 'voice_command_aliases.dart';
import 'voice_text_normalizer.dart';

enum VoiceCommandSensitivity { strict, normal, flexible }

class VoiceLearnedCorrection {
  final VoiceScreenContext context;
  final String phrase;
  final VoiceIntent intent;

  const VoiceLearnedCorrection({
    required this.context,
    required this.phrase,
    required this.intent,
  });
}

class VoiceCommandParser {
  static const double _learnedCorrectionConfidence = 0.95;
  static const double _patternConfidence = 1.0;
  static const double _suggestionConfidence = 0.72;
  static const Set<String> _selectCCompactSuggestionVariants = {
    'galaxy',
    'galaxi',
    'sylnetse',
    'sylentse',
    'silnetse',
  };

  const VoiceCommandParser._();

  static VoiceCommandResult parse({
    required String rawText,
    required VoiceScreenContext context,
    required VoiceCommandSensitivity sensitivity,
    VoiceAccentProfile accentProfile = VoiceAccentProfile.defaultEnglish,
    List<VoiceLearnedCorrection> learnedCorrections =
        const <VoiceLearnedCorrection>[],
  }) {
    final normalizedText = VoiceTextNormalizer.normalize(
      rawText,
      accentProfile: accentProfile,
    );
    if (normalizedText.isEmpty) {
      return const VoiceCommandResult(
        decision: VoiceCommandDecision.notUnderstood,
        message: 'No speech was recognized.',
      );
    }

    final directOptionIntent = _matchDirectOption(
      rawText: rawText,
      normalizedText: normalizedText,
      context: context,
      accentProfile: accentProfile,
    );
    if (directOptionIntent != null) {
      _logIgnoredLearnedCorrectionsForDirectOption(
        normalizedText: normalizedText,
        context: context,
        learnedCorrections: learnedCorrections,
        directOptionIntent: directOptionIntent,
        accentProfile: accentProfile,
      );
      return _decide(
        directOptionIntent,
        context: context,
        sensitivity: sensitivity,
        isFuzzyMatch: false,
      );
    }

    final exactAliasIntent = _matchExactAlias(
      rawText: rawText,
      normalizedText: normalizedText,
      context: context,
      accentProfile: accentProfile,
    );
    if (exactAliasIntent != null) {
      return _decide(
        exactAliasIntent,
        context: context,
        sensitivity: sensitivity,
        isFuzzyMatch: false,
      );
    }

    final patternIntent = _matchPattern(
      rawText: rawText,
      normalizedText: normalizedText,
      context: context,
    );
    if (patternIntent != null) {
      return _decide(
        patternIntent,
        context: context,
        sensitivity: sensitivity,
        isFuzzyMatch: false,
      );
    }

    final learnedIntent = _matchLearnedCorrection(
      rawText: rawText,
      normalizedText: normalizedText,
      context: context,
      learnedCorrections: learnedCorrections,
      accentProfile: accentProfile,
    );
    if (learnedIntent != null) {
      return _decide(
        learnedIntent,
        context: context,
        sensitivity: sensitivity,
        isFuzzyMatch: false,
        isLearnedCorrection: true,
      );
    }

    final fuzzyResult = FuzzyMatcher.matchAliases(
      normalizedText,
      context,
      accentProfile: accentProfile,
    );
    final fuzzyIntent = fuzzyResult?.intent?.copyWith(
      confidence: _requiresSuggestionBeforeLearning(rawText)
          ? fuzzyResult.score.clamp(0.0, _suggestionConfidence).toDouble()
          : fuzzyResult.score,
      rawText: rawText,
      normalizedText: normalizedText,
      source: _requiresSuggestionBeforeLearning(rawText)
          ? 'suggestion'
          : 'fuzzy_alias',
    );
    if (fuzzyIntent == null) {
      return const VoiceCommandResult(
        decision: VoiceCommandDecision.fallbackToCloud,
        message: 'No local command matched.',
      );
    }

    return _decide(
      fuzzyIntent,
      context: context,
      sensitivity: sensitivity,
      isFuzzyMatch: true,
      isAmbiguousFuzzyMatch: fuzzyResult?.isAmbiguous ?? false,
      forceSuggestion: _requiresSuggestionBeforeLearning(rawText),
    );
  }

  static VoiceIntentType? directOptionTypeForText(String text) {
    return directOptionTypeForTextWithProfile(text);
  }

  static VoiceIntentType? directOptionTypeForTextWithProfile(
    String text, {
    VoiceAccentProfile accentProfile = VoiceAccentProfile.defaultEnglish,
  }) {
    final normalizedText = VoiceTextNormalizer.normalize(
      text,
      accentProfile: accentProfile,
    );
    if (normalizedText.isEmpty) return null;
    return directOptionTypeForNormalized(
      normalizedText,
      accentProfile: accentProfile,
    );
  }

  static VoiceIntentType? directOptionTypeForNormalized(
    String normalizedText, {
    VoiceAccentProfile accentProfile = VoiceAccentProfile.defaultEnglish,
  }) {
    for (final alias in VoiceCommandAliases.forContext(
      VoiceScreenContext.quiz,
      includeGlobal: false,
    )) {
      if (!_isOptionIntentType(alias.intent.type)) continue;
      if (VoiceTextNormalizer.normalize(
            alias.phrase,
            accentProfile: accentProfile,
          ) !=
          normalizedText) {
        continue;
      }
      return alias.intent.type;
    }
    return null;
  }

  static bool isConflictingDirectOptionCorrection({
    required String phrase,
    required VoiceIntentType intentType,
  }) {
    final optionType =
        directOptionTypeForText(phrase) ?? suggestedOptionTypeForText(phrase);
    return optionType != null && optionType != intentType;
  }

  static VoiceIntentType? suggestedOptionTypeForText(
    String text, {
    VoiceAccentProfile accentProfile = VoiceAccentProfile.defaultEnglish,
  }) {
    final directType = directOptionTypeForTextWithProfile(
      text,
      accentProfile: accentProfile,
    );
    if (directType != null) return directType;

    final compactText = _compactRawText(text);
    if (_selectCCompactSuggestionVariants.contains(compactText)) {
      return VoiceIntentType.optionC;
    }
    return null;
  }

  static Set<int> quizAnswerIndexesForText({
    required String rawText,
    required int optionCount,
    required bool isTrueFalse,
    required bool isMultiSelect,
    List<String> optionTexts = const <String>[],
    VoiceAccentProfile accentProfile = VoiceAccentProfile.defaultEnglish,
  }) {
    if (optionCount <= 0) return const <int>{};
    final directType = directOptionTypeForTextWithProfile(
      rawText,
      accentProfile: accentProfile,
    );
    final directIndex = _optionIndexForType(directType);
    if (directIndex != null && directIndex < optionCount) {
      return {directIndex};
    }

    final normalized =
        VoiceTextNormalizer.normalize(rawText, accentProfile: accentProfile)
            .replaceAll(
              RegExp(
                r'\b(answer|answers|option|options|select|choose|letter|and)\b',
              ),
              ' ',
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (normalized.isEmpty) return const <int>{};

    if (isTrueFalse) {
      final wantsTrue = RegExp(r'\btrue\b').hasMatch(normalized);
      final wantsFalse = RegExp(r'\bfalse\b').hasMatch(normalized);
      if (wantsTrue == wantsFalse) return const <int>{};
      final target = wantsTrue ? 'true' : 'false';
      final optionIndex = optionTexts.indexWhere(
        (option) =>
            VoiceTextNormalizer.normalize(
              option,
              accentProfile: accentProfile,
            ) ==
            target,
      );
      final index = optionIndex >= 0 ? optionIndex : (wantsTrue ? 0 : 1);
      return index < optionCount ? {index} : const <int>{};
    }

    final indexes = <int>{};
    final tokens = normalized.split(RegExp(r'\s+'));
    const wordIndexes = <String, int>{
      'a': 0,
      'ay': 0,
      'one': 0,
      'first': 0,
      'b': 1,
      'bee': 1,
      'be': 1,
      'two': 1,
      'second': 1,
      'c': 2,
      'si': 2,
      'see': 2,
      'sea': 2,
      'three': 2,
      'third': 2,
      'd': 3,
      'dee': 3,
      'four': 3,
      'fourth': 3,
    };
    for (final token in tokens) {
      final index = wordIndexes[token];
      if (index != null && index < optionCount) {
        indexes.add(index);
      }
    }
    if (!isMultiSelect && indexes.length > 1) return const <int>{};
    return indexes;
  }

  static VoiceIntent? _matchDirectOption({
    required String rawText,
    required String normalizedText,
    required VoiceScreenContext context,
    required VoiceAccentProfile accentProfile,
  }) {
    if (context != VoiceScreenContext.quiz) return null;

    for (final alias in VoiceCommandAliases.forContext(
      context,
      includeGlobal: false,
    )) {
      if (!_isOptionIntentType(alias.intent.type)) continue;
      final normalizedAlias = VoiceTextNormalizer.normalize(
        alias.phrase,
        accentProfile: accentProfile,
      );
      if (normalizedAlias != normalizedText) continue;

      return alias.intent.copyWith(
        confidence: alias.baseConfidence,
        rawText: rawText,
        normalizedText: normalizedText,
        source: 'direct_option',
      );
    }
    return null;
  }

  static void _logIgnoredLearnedCorrectionsForDirectOption({
    required String normalizedText,
    required VoiceScreenContext context,
    required List<VoiceLearnedCorrection> learnedCorrections,
    required VoiceIntent directOptionIntent,
    required VoiceAccentProfile accentProfile,
  }) {
    for (final correction in learnedCorrections) {
      if (correction.context != context &&
          correction.context != VoiceScreenContext.global) {
        continue;
      }

      final normalizedCorrection = VoiceTextNormalizer.normalize(
        correction.phrase,
        accentProfile: accentProfile,
      );
      if (normalizedCorrection != normalizedText) continue;

      debugPrint(
        '[Voice][${context.name}] learned correction ignored phrase="${correction.phrase}" normalized="$normalizedCorrection" reason=directOptionOverride intent=${correction.intent.type.name} directIntent=${directOptionIntent.type.name}',
      );
    }
  }

  static VoiceIntent? _matchLearnedCorrection({
    required String rawText,
    required String normalizedText,
    required VoiceScreenContext context,
    required List<VoiceLearnedCorrection> learnedCorrections,
    required VoiceAccentProfile accentProfile,
  }) {
    for (final correction in learnedCorrections) {
      if (correction.context != context &&
          correction.context != VoiceScreenContext.global) {
        continue;
      }

      final normalizedCorrection = VoiceTextNormalizer.normalize(
        correction.phrase,
        accentProfile: accentProfile,
      );
      if (normalizedCorrection != normalizedText) continue;
      if (VoiceSafetyPolicy.isRiskyIntent(correction.intent)) {
        debugPrint(
          '[Voice][${context.name}] learned correction ignored phrase="${correction.phrase}" normalized="$normalizedCorrection" reason=risky intent=${correction.intent.type.name}',
        );
        continue;
      }
      if (isConflictingDirectOptionCorrection(
        phrase: correction.phrase,
        intentType: correction.intent.type,
      )) {
        debugPrint(
          '[Voice][${context.name}] learned correction ignored phrase="${correction.phrase}" normalized="$normalizedCorrection" reason=directOptionConflict intent=${correction.intent.type.name}',
        );
        continue;
      }

      debugPrint(
        '[Voice][${context.name}] learned correction applied phrase="${correction.phrase}" normalized="$normalizedCorrection" intent=${correction.intent.type.name}',
      );
      return correction.intent.copyWith(
        confidence: _learnedCorrectionConfidence,
        rawText: rawText,
        normalizedText: normalizedText,
        source: 'learned_correction',
      );
    }
    return null;
  }

  static VoiceIntent? _matchExactAlias({
    required String rawText,
    required String normalizedText,
    required VoiceScreenContext context,
    required VoiceAccentProfile accentProfile,
  }) {
    for (final alias in VoiceCommandAliases.forContext(context)) {
      if (_requiresSuggestionBeforeLearning(rawText) &&
          _isOptionIntentType(alias.intent.type)) {
        continue;
      }
      final normalizedAlias = VoiceTextNormalizer.normalize(
        alias.phrase,
        accentProfile: accentProfile,
      );
      if (normalizedAlias != normalizedText) continue;

      return alias.intent.copyWith(
        confidence: alias.baseConfidence,
        rawText: rawText,
        normalizedText: normalizedText,
        source: 'exact_alias',
      );
    }
    return null;
  }

  static VoiceIntent? _matchPattern({
    required String rawText,
    required String normalizedText,
    required VoiceScreenContext context,
  }) {
    for (final patternAlias in VoiceCommandAliases.patternsForContext(
      context,
    )) {
      final match = patternAlias.pattern.firstMatch(normalizedText);
      if (match == null) continue;

      final number = int.tryParse(match.group(1) ?? '');
      if (number == null) continue;

      return patternAlias
          .toIntent(
            rawText: rawText,
            normalizedText: normalizedText,
            number: number,
            confidence: _patternConfidence,
          )
          .copyWith(source: 'pattern_alias');
    }
    return null;
  }

  static VoiceCommandResult _decide(
    VoiceIntent intent, {
    required VoiceScreenContext context,
    required VoiceCommandSensitivity sensitivity,
    required bool isFuzzyMatch,
    bool isAmbiguousFuzzyMatch = false,
    bool isLearnedCorrection = false,
    bool forceSuggestion = false,
  }) {
    final thresholds = _thresholdsFor(sensitivity);
    final isRisky = VoiceSafetyPolicy.isRiskyIntent(intent);
    final effectiveIntent = intent.copyWith(isRisky: isRisky);

    if (isRisky) {
      if (!_hasEnoughRiskyConfidence(effectiveIntent, thresholds)) {
        return VoiceCommandResult(
          decision: VoiceCommandDecision.askConfirmation,
          intent: effectiveIntent,
          message: _riskyConfirmMessage(effectiveIntent, context),
        );
      }

      if (isFuzzyMatch || isLearnedCorrection) {
        return VoiceCommandResult(
          decision: VoiceCommandDecision.askConfirmation,
          intent: effectiveIntent,
          message: _riskyConfirmMessage(effectiveIntent, context),
        );
      }

      if (_requiresExplicitConfirmation(effectiveIntent.type)) {
        return VoiceCommandResult(
          decision: VoiceCommandDecision.askConfirmation,
          intent: effectiveIntent,
          message: _riskyConfirmMessage(effectiveIntent, context),
        );
      }

      return VoiceCommandResult(
        decision: VoiceCommandDecision.execute,
        intent: effectiveIntent,
      );
    }

    if (isAmbiguousFuzzyMatch &&
        effectiveIntent.confidence >= thresholds.confirm) {
      debugPrint(
        '[Voice][${context.name}] fuzzy rejected raw="${effectiveIntent.rawText}" normalized="${effectiveIntent.normalizedText}" source=${effectiveIntent.source} confidence=${effectiveIntent.confidence.toStringAsFixed(2)} reason=ambiguous',
      );
      return VoiceCommandResult(
        decision: VoiceCommandDecision.notUnderstood,
        intent: effectiveIntent,
        message:
            'That sounded close to more than one command. Please repeat it.',
      );
    }

    if (forceSuggestion && effectiveIntent.confidence >= thresholds.confirm) {
      debugPrint(
        '[Voice][${context.name}] suggestion raw="${effectiveIntent.rawText}" normalized="${effectiveIntent.normalizedText}" source=${effectiveIntent.source} confidence=${effectiveIntent.confidence.toStringAsFixed(2)} suggestion=${effectiveIntent.type.name}',
      );
      return VoiceCommandResult(
        decision: VoiceCommandDecision.askConfirmation,
        intent: effectiveIntent,
        message: 'Did you mean ${_commandLabelForIntent(effectiveIntent)}?',
      );
    }

    if (effectiveIntent.confidence >= thresholds.execute) {
      return VoiceCommandResult(
        decision: VoiceCommandDecision.execute,
        intent: effectiveIntent,
      );
    }

    if (effectiveIntent.confidence >= thresholds.confirm) {
      return VoiceCommandResult(
        decision: VoiceCommandDecision.askConfirmation,
        intent: effectiveIntent,
        message: 'Did you mean ${_commandLabelForIntent(effectiveIntent)}?',
      );
    }

    if (isFuzzyMatch && effectiveIntent.confidence >= thresholds.suggest) {
      debugPrint(
        '[Voice][${context.name}] low confidence suggestion raw="${effectiveIntent.rawText}" normalized="${effectiveIntent.normalizedText}" source=${effectiveIntent.source} confidence=${effectiveIntent.confidence.toStringAsFixed(2)} suggestion=${effectiveIntent.type.name} reason=belowExecuteThreshold',
      );
      return VoiceCommandResult(
        decision: VoiceCommandDecision.askConfirmation,
        intent: effectiveIntent.copyWith(source: 'suggestion'),
        message: 'Did you mean ${_commandLabelForIntent(effectiveIntent)}?',
      );
    }

    debugPrint(
      '[Voice][${context.name}] low confidence rejected raw="${effectiveIntent.rawText}" normalized="${effectiveIntent.normalizedText}" bestSuggestion=${effectiveIntent.type.name} suggestionConfidence=${effectiveIntent.confidence.toStringAsFixed(2)} reason=belowSuggestionThreshold',
    );
    return VoiceCommandResult(
      decision: VoiceCommandDecision.fallbackToCloud,
      intent: effectiveIntent,
      message: 'Local confidence was too low.',
    );
  }

  static bool _hasEnoughRiskyConfidence(
    VoiceIntent intent,
    _VoiceParserThresholds thresholds,
  ) {
    return intent.confidence >= thresholds.risky;
  }

  static String _riskyConfirmMessage(
    VoiceIntent intent,
    VoiceScreenContext context,
  ) {
    if (context == VoiceScreenContext.review &&
        VoiceSafetyPolicy.submitLikeTypes.contains(intent.type)) {
      return 'Do you want to submit your quiz?';
    }
    return 'Please confirm ${intent.normalizedText}.';
  }

  static bool _requiresExplicitConfirmation(VoiceIntentType type) {
    return type == VoiceIntentType.exitQuiz ||
        type == VoiceIntentType.resetAnswers ||
        type == VoiceIntentType.clearAnswer ||
        type == VoiceIntentType.delete ||
        type == VoiceIntentType.restartTest;
  }

  static _VoiceParserThresholds _thresholdsFor(
    VoiceCommandSensitivity sensitivity,
  ) {
    return switch (sensitivity) {
      VoiceCommandSensitivity.strict => const _VoiceParserThresholds(
        execute: 0.90,
        confirm: 0.75,
        risky: 0.94,
        suggest: 0.60,
      ),
      VoiceCommandSensitivity.normal => const _VoiceParserThresholds(
        execute: 0.85,
        confirm: 0.65,
        risky: 0.90,
        suggest: 0.52,
      ),
      VoiceCommandSensitivity.flexible => const _VoiceParserThresholds(
        execute: 0.78,
        confirm: 0.58,
        risky: 0.86,
        suggest: 0.48,
      ),
    };
  }

  static bool _isOptionIntentType(VoiceIntentType type) {
    return type == VoiceIntentType.optionA ||
        type == VoiceIntentType.optionB ||
        type == VoiceIntentType.optionC ||
        type == VoiceIntentType.optionD;
  }

  static bool _requiresSuggestionBeforeLearning(String rawText) {
    final normalizedRaw = rawText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .trim();
    final compactRaw = _compactRawText(rawText);
    return RegExp(r'(^|\s)syllet(?=\s|$)').hasMatch(normalizedRaw) ||
        _selectCCompactSuggestionVariants.contains(compactRaw);
  }

  static String _compactRawText(String rawText) {
    return rawText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), '');
  }

  static String _commandLabelForIntent(VoiceIntent intent) {
    return switch (intent.type) {
      VoiceIntentType.optionA => 'Select A',
      VoiceIntentType.optionB => 'Select B',
      VoiceIntentType.optionC => 'Select C',
      VoiceIntentType.optionD => 'Select D',
      VoiceIntentType.trueAnswer => 'True',
      VoiceIntentType.falseAnswer => 'False',
      VoiceIntentType.next || VoiceIntentType.skip => 'Next question',
      VoiceIntentType.previous => 'Previous question',
      VoiceIntentType.repeat || VoiceIntentType.readQuestion => 'Read question',
      VoiceIntentType.flag || VoiceIntentType.bookmark => 'Flag question',
      VoiceIntentType.explain => 'Explain',
      VoiceIntentType.review => 'Open review',
      VoiceIntentType.questionNumber =>
        'Question ${intent.number ?? ''}'.trim(),
      VoiceIntentType.help => 'Help',
      _ => intent.normalizedText,
    };
  }

  static int? _optionIndexForType(VoiceIntentType? type) {
    return switch (type) {
      VoiceIntentType.optionA => 0,
      VoiceIntentType.optionB => 1,
      VoiceIntentType.optionC => 2,
      VoiceIntentType.optionD => 3,
      _ => null,
    };
  }
}

class _VoiceParserThresholds {
  final double execute;
  final double confirm;
  final double risky;
  final double suggest;

  const _VoiceParserThresholds({
    required this.execute,
    required this.confirm,
    required this.risky,
    required this.suggest,
  });
}
