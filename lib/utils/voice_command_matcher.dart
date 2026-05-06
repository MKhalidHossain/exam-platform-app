import 'dart:math' as math;

class VoiceCommandMatcher {
  static const Map<String, String> _commonCorrections = {
    'summit': 'submit',
    'sumit': 'submit',
    'submitt': 'submit',
    'submmit': 'submit',
    'sumbit': 'submit',
    'confrim': 'confirm',
    'comfirm': 'confirm',
    'cnfirm': 'confirm',
    'reveiw': 'review',
    'revie': 'review',
    'flaged': 'flagged',
    'flagd': 'flagged',
    'bak': 'back',
    'bac': 'back',
    'unanswerd': 'unanswered',
    'unaswered': 'unanswered',
    'lstening': 'listening',
    'speeking': 'speaking',
  };

  static bool matchesAny(String text, List<String> keywords) {
    final normalizedText = _normalize(text);
    if (normalizedText.isEmpty) return false;
    return keywords.any((keyword) => _matchesPhrase(normalizedText, keyword));
  }

  static String normalizeText(String text) => _normalize(text);

  static bool _matchesPhrase(String text, String phrase) {
    final normalizedPhrase = _normalize(phrase);
    if (normalizedPhrase.isEmpty) return false;
    if (text == normalizedPhrase) return true;

    final escaped = RegExp.escape(normalizedPhrase);
    if (RegExp('(^|\\s)$escaped(\\s|\$)').hasMatch(text)) {
      return true;
    }

    final textWords = text.split(' ');
    final phraseWords = normalizedPhrase.split(' ');

    if (phraseWords.length == 1) {
      return textWords.any((word) => _wordsAreClose(word, phraseWords.first));
    }

    if (textWords.length < phraseWords.length) return false;
    for (
      int start = 0;
      start <= textWords.length - phraseWords.length;
      start++
    ) {
      bool matched = true;
      for (int i = 0; i < phraseWords.length; i++) {
        if (!_wordsAreClose(textWords[start + i], phraseWords[i])) {
          matched = false;
          break;
        }
      }
      if (matched) return true;
    }
    return false;
  }

  static bool _wordsAreClose(String actual, String expected) {
    if (actual == expected) return true;
    if (actual.isEmpty || expected.isEmpty) return false;

    final maxLen = math.max(actual.length, expected.length);
    if (maxLen <= 2) return false;

    // Keep fuzzy matching conservative so commands don't misfire.
    if (actual[0] != expected[0]) return false;

    final distance = _levenshtein(actual, expected);
    if (maxLen <= 4) {
      return distance <= 1;
    }

    return distance <= 2 && (distance / maxLen) <= 0.34;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previous = List<int>.generate(b.length + 1, (index) => index);
    final current = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final substitutionCost = a[i] == b[j] ? 0 : 1;
        current[j + 1] = math.min(
          math.min(current[j] + 1, previous[j + 1] + 1),
          previous[j] + substitutionCost,
        );
      }
      for (int j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[b.length];
  }

  static String _normalize(String value) {
    final tokens = value
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) => _commonCorrections[token] ?? token)
        .toList();
    return tokens.join(' ');
  }
}
