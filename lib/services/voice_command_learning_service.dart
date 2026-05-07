import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/voice_command_normalizer.dart';
import '../utils/voice_intent.dart';

class VoiceCommandLearningService {
  static const int _maxCorrections = 100;
  static const double _similarityThreshold = 0.80;
  static const String storageKey = 'voice_command_learned_corrections';

  Future<void> rememberCorrection(String heardText, VoiceIntent intent) async {
    if (_isUnsafeToLearn(intent)) return;

    final normalizedText = VoiceCommandNormalizer.normalize(heardText);
    if (normalizedText.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final corrections = await _readCorrections(prefs);
    corrections.removeWhere((entry) => entry.normalizedText == normalizedText);
    corrections.insert(0, _LearnedCorrection(normalizedText, intent.name));

    final capped = corrections.take(_maxCorrections).toList();
    await prefs.setStringList(
      storageKey,
      capped.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  Future<VoiceIntent?> findLearnedIntent(String heardText) async {
    final normalizedText = VoiceCommandNormalizer.normalize(heardText);
    if (normalizedText.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final corrections = await _readCorrections(prefs);

    for (final correction in corrections) {
      if (correction.normalizedText == normalizedText) {
        return _intentFromName(correction.intentName);
      }
    }

    _LearnedCorrection? bestCorrection;
    double bestScore = 0;
    for (final correction in corrections) {
      final score = _similarity(normalizedText, correction.normalizedText);
      if (score > bestScore) {
        bestScore = score;
        bestCorrection = correction;
      }
    }

    if (bestCorrection == null || bestScore < _similarityThreshold) {
      return null;
    }
    return _intentFromName(bestCorrection.intentName);
  }

  Future<List<_LearnedCorrection>> _readCorrections(
    SharedPreferences prefs,
  ) async {
    final stored = prefs.getStringList(storageKey) ?? const <String>[];
    final corrections = <_LearnedCorrection>[];
    for (final rawEntry in stored) {
      try {
        final decoded = jsonDecode(rawEntry);
        if (decoded is! Map<String, dynamic>) continue;
        final correction = _LearnedCorrection.fromJson(decoded);
        if (correction == null) continue;
        if (_intentFromName(correction.intentName) == null) continue;
        corrections.add(correction);
      } catch (_) {
        continue;
      }
    }
    return corrections;
  }

  bool _isUnsafeToLearn(VoiceIntent intent) {
    return intent == VoiceIntent.submit || intent == VoiceIntent.confirmSubmit;
  }

  VoiceIntent? _intentFromName(String name) {
    for (final intent in VoiceIntent.values) {
      if (intent.name == name) return intent;
    }
    return null;
  }

  double _similarity(String first, String second) {
    if (first == second) return 1;
    if (first.isEmpty || second.isEmpty) return 0;

    final distance = _levenshtein(first, second);
    final longest = first.length > second.length ? first.length : second.length;
    return 1 - (distance / longest);
  }

  int _levenshtein(String first, String second) {
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
}

class _LearnedCorrection {
  final String normalizedText;
  final String intentName;

  const _LearnedCorrection(this.normalizedText, this.intentName);

  Map<String, dynamic> toJson() => {
    'heardText': normalizedText,
    'intent': intentName,
  };

  static _LearnedCorrection? fromJson(Map<String, dynamic> json) {
    final heardText = json['heardText'];
    final intent = json['intent'];
    if (heardText is! String || intent is! String) return null;
    if (heardText.isEmpty || intent.isEmpty) return null;
    return _LearnedCorrection(heardText, intent);
  }
}
