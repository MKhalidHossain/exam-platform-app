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

  const VoiceCommandParser._();

  static VoiceCommandResult parse({
    required String rawText,
    required VoiceScreenContext context,
    required VoiceCommandSensitivity sensitivity,
    List<VoiceLearnedCorrection> learnedCorrections =
        const <VoiceLearnedCorrection>[],
  }) {
    final normalizedText = VoiceTextNormalizer.normalize(rawText);
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
    );
    if (directOptionIntent != null) {
      _logIgnoredLearnedCorrectionsForDirectOption(
        normalizedText: normalizedText,
        context: context,
        learnedCorrections: learnedCorrections,
        directOptionIntent: directOptionIntent,
      );
      return _decide(
        directOptionIntent,
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

    final exactAliasIntent = _matchExactAlias(
      rawText: rawText,
      normalizedText: normalizedText,
      context: context,
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

    final fuzzyResult = FuzzyMatcher.matchAliases(normalizedText, context);
    final fuzzyIntent = fuzzyResult?.intent?.copyWith(
      confidence: fuzzyResult.score,
      rawText: rawText,
      normalizedText: normalizedText,
      source: 'fuzzy_alias',
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
    );
  }

  static VoiceIntentType? directOptionTypeForText(String text) {
    final normalizedText = VoiceTextNormalizer.normalize(text);
    if (normalizedText.isEmpty) return null;
    return directOptionTypeForNormalized(normalizedText);
  }

  static VoiceIntentType? directOptionTypeForNormalized(String normalizedText) {
    for (final alias in VoiceCommandAliases.forContext(
      VoiceScreenContext.quiz,
      includeGlobal: false,
    )) {
      if (!_isOptionIntentType(alias.intent.type)) continue;
      if (VoiceTextNormalizer.normalize(alias.phrase) != normalizedText) {
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
    final directOptionType = directOptionTypeForText(phrase);
    return directOptionType != null && directOptionType != intentType;
  }

  static VoiceIntent? _matchDirectOption({
    required String rawText,
    required String normalizedText,
    required VoiceScreenContext context,
  }) {
    if (context != VoiceScreenContext.quiz) return null;

    for (final alias in VoiceCommandAliases.forContext(
      context,
      includeGlobal: false,
    )) {
      if (!_isOptionIntentType(alias.intent.type)) continue;
      final normalizedAlias = VoiceTextNormalizer.normalize(alias.phrase);
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
  }) {
    for (final correction in learnedCorrections) {
      if (correction.context != context &&
          correction.context != VoiceScreenContext.global) {
        continue;
      }

      final normalizedCorrection = VoiceTextNormalizer.normalize(
        correction.phrase,
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
  }) {
    for (final correction in learnedCorrections) {
      if (correction.context != context &&
          correction.context != VoiceScreenContext.global) {
        continue;
      }

      final normalizedCorrection = VoiceTextNormalizer.normalize(
        correction.phrase,
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
  }) {
    for (final alias in VoiceCommandAliases.forContext(context)) {
      final normalizedAlias = VoiceTextNormalizer.normalize(alias.phrase);
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
      return VoiceCommandResult(
        decision: VoiceCommandDecision.askConfirmation,
        intent: effectiveIntent,
        message: 'Did you mean ${effectiveIntent.normalizedText}?',
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
        message: 'Did you mean ${effectiveIntent.normalizedText}?',
      );
    }

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
      ),
      VoiceCommandSensitivity.normal => const _VoiceParserThresholds(
        execute: 0.85,
        confirm: 0.65,
        risky: 0.90,
      ),
      VoiceCommandSensitivity.flexible => const _VoiceParserThresholds(
        execute: 0.78,
        confirm: 0.58,
        risky: 0.86,
      ),
    };
  }

  static bool _isOptionIntentType(VoiceIntentType type) {
    return type == VoiceIntentType.optionA ||
        type == VoiceIntentType.optionB ||
        type == VoiceIntentType.optionC ||
        type == VoiceIntentType.optionD;
  }
}

class _VoiceParserThresholds {
  final double execute;
  final double confirm;
  final double risky;

  const _VoiceParserThresholds({
    required this.execute,
    required this.confirm,
    required this.risky,
  });
}
