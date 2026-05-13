import '../core/voice_command_context.dart';
import '../core/voice_intent.dart';
import 'voice_command_aliases.dart';
import 'voice_text_normalizer.dart';

class FuzzyMatchCandidate {
  final String phrase;
  final VoiceIntent? intent;

  const FuzzyMatchCandidate({required this.phrase, this.intent});
}

class FuzzyMatchResult {
  final String matchedPhrase;
  final String normalizedQuery;
  final String normalizedMatchedPhrase;
  final double score;
  final VoiceIntent? intent;

  const FuzzyMatchResult({
    required this.matchedPhrase,
    required this.normalizedQuery,
    required this.normalizedMatchedPhrase,
    required this.score,
    this.intent,
  });

  bool get hasIntent => intent != null;
  bool get isRisky => intent?.isRisky ?? false;
}

class FuzzyMatcher {
  const FuzzyMatcher._();

  static FuzzyMatchResult? match(
    String query,
    Iterable<FuzzyMatchCandidate> candidates,
  ) {
    final normalizedQuery = VoiceTextNormalizer.normalize(query);
    if (normalizedQuery.isEmpty) return null;

    FuzzyMatchResult? bestResult;
    for (final candidate in candidates) {
      final normalizedPhrase = VoiceTextNormalizer.normalize(candidate.phrase);
      if (normalizedPhrase.isEmpty) continue;

      final score = similarity(normalizedQuery, normalizedPhrase);
      final result = FuzzyMatchResult(
        matchedPhrase: candidate.phrase,
        normalizedQuery: normalizedQuery,
        normalizedMatchedPhrase: normalizedPhrase,
        score: score,
        intent: candidate.intent,
      );

      if (_isBetterMatch(result, bestResult)) {
        bestResult = result;
      }
    }

    return bestResult;
  }

  static FuzzyMatchResult? matchAliases(
    String query,
    VoiceScreenContext context, {
    bool includeGlobal = true,
  }) {
    final candidates =
        VoiceCommandAliases.forContext(
          context,
          includeGlobal: includeGlobal,
        ).map(
          (alias) =>
              FuzzyMatchCandidate(phrase: alias.phrase, intent: alias.intent),
        );
    return match(query, candidates);
  }

  static double similarity(String first, String second) {
    if (first == second) return 1.0;
    if (first.isEmpty || second.isEmpty) return 0.0;

    final distance = _levenshteinDistance(first, second);
    final longest = first.length > second.length ? first.length : second.length;
    if (longest == 0) return 1.0;
    return (1 - (distance / longest)).clamp(0.0, 1.0).toDouble();
  }

  static bool _isBetterMatch(
    FuzzyMatchResult result,
    FuzzyMatchResult? currentBest,
  ) {
    if (currentBest == null) return true;
    if (result.score != currentBest.score) {
      return result.score > currentBest.score;
    }

    final resultLengthDelta =
        (result.normalizedMatchedPhrase.length - result.normalizedQuery.length)
            .abs();
    final bestLengthDelta =
        (currentBest.normalizedMatchedPhrase.length -
                currentBest.normalizedQuery.length)
            .abs();
    if (resultLengthDelta != bestLengthDelta) {
      return resultLengthDelta < bestLengthDelta;
    }

    return result.normalizedMatchedPhrase.compareTo(
          currentBest.normalizedMatchedPhrase,
        ) <
        0;
  }

  static int _levenshteinDistance(String first, String second) {
    if (first == second) return 0;
    if (first.isEmpty) return second.length;
    if (second.isEmpty) return first.length;

    final previous = List<int>.generate(second.length + 1, (index) => index);
    final current = List<int>.filled(second.length + 1, 0);

    for (var i = 0; i < first.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < second.length; j++) {
        final substitutionCost = first[i] == second[j] ? 0 : 1;
        final insertion = current[j] + 1;
        final deletion = previous[j + 1] + 1;
        final substitution = previous[j] + substitutionCost;
        current[j + 1] = _min(insertion, deletion, substitution);
      }

      for (var j = 0; j <= second.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[second.length];
  }

  static int _min(int first, int second, int third) {
    if (first <= second && first <= third) return first;
    if (second <= first && second <= third) return second;
    return third;
  }
}
