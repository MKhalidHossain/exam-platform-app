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

    final learnedIntent = _matchLearnedCorrection(
      rawText: rawText,
      normalizedText: normalizedText,
      context: context,
      learnedCorrections: learnedCorrections,
    );
    if (learnedIntent != null) {
      return _decide(
        learnedIntent,
        sensitivity: sensitivity,
        isFuzzyMatch: false,
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

    return _decide(fuzzyIntent, sensitivity: sensitivity, isFuzzyMatch: true);
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
    required VoiceCommandSensitivity sensitivity,
    required bool isFuzzyMatch,
  }) {
    final thresholds = _thresholdsFor(sensitivity);
    final isRisky = VoiceSafetyPolicy.isRiskyIntent(intent);
    final effectiveIntent = intent.copyWith(isRisky: isRisky);

    if (isRisky) {
      if (!_hasEnoughRiskyConfidence(effectiveIntent, thresholds)) {
        return VoiceCommandResult(
          decision: VoiceCommandDecision.askConfirmation,
          intent: effectiveIntent,
          message: 'Please confirm ${effectiveIntent.normalizedText}.',
        );
      }

      if (isFuzzyMatch) {
        return VoiceCommandResult(
          decision: VoiceCommandDecision.askConfirmation,
          intent: effectiveIntent,
          message: 'Please confirm ${effectiveIntent.normalizedText}.',
        );
      }

      if (_requiresExplicitConfirmation(effectiveIntent.type)) {
        return VoiceCommandResult(
          decision: VoiceCommandDecision.askConfirmation,
          intent: effectiveIntent,
          message: 'Please confirm ${effectiveIntent.normalizedText}.',
        );
      }

      return VoiceCommandResult(
        decision: VoiceCommandDecision.execute,
        intent: effectiveIntent,
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
    if (intent.type == VoiceIntentType.confirmSubmit) {
      return intent.confidence >= thresholds.execute;
    }
    return intent.confidence >= thresholds.confirm;
  }

  static bool _requiresExplicitConfirmation(VoiceIntentType type) {
    return type == VoiceIntentType.submit ||
        type == VoiceIntentType.finalSubmit ||
        type == VoiceIntentType.finishExam ||
        type == VoiceIntentType.exitQuiz ||
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
      ),
      VoiceCommandSensitivity.normal => const _VoiceParserThresholds(
        execute: 0.85,
        confirm: 0.65,
      ),
      VoiceCommandSensitivity.flexible => const _VoiceParserThresholds(
        execute: 0.78,
        confirm: 0.58,
      ),
    };
  }
}

class _VoiceParserThresholds {
  final double execute;
  final double confirm;

  const _VoiceParserThresholds({required this.execute, required this.confirm});
}
