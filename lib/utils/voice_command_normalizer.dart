class VoiceCommandNormalizer {
  static const Map<String, String> _wordCorrections = {
    'won': 'one',
    'too': 'two',
    'to': 'two',
    'tree': 'three',
    'free': 'three',
    'for': 'four',
    'fore': 'four',
    'nex': 'next',
    'neckst': 'next',
    'queston': 'question',
    'sabmit': 'submit',
    'sabit': 'submit',
    'finis': 'finish',
    'fenish': 'finish',
    'revue': 'review',
    'explan': 'explain',
  };

  static const Map<String, String> _phraseCorrections = {
    'sub mit': 'submit',
    'sub meet': 'submit',
    'sub mid': 'submit',
    'ree view': 'review',
  };

  static const Map<String, String> _optionLetterCorrections = {
    'ay': 'a',
    'hey': 'a',
    'bee': 'b',
    'be': 'b',
    'sea': 'c',
    'see': 'c',
    'dee': 'd',
  };

  static const Set<String> _optionPrefixes = {
    'option',
    'answer',
    'select',
    'choose',
    'letter',
  };

  static const Map<String, String> _commandPhrases = {
    'next question': 'next',
    'go next': 'next',
    'go back': 'back',
    'return two question': 'return to question',
    'read again': 'repeat',
    'say again': 'repeat',
    'mark question': 'flag',
  };

  static String normalize(String text) {
    var normalized = text.toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    normalized = _normalizeSpaces(normalized);

    normalized = _replacePhrases(normalized, _phraseCorrections);
    final tokens = normalized
        .split(' ')
        .map((word) => _wordCorrections[word] ?? word)
        .toList(growable: false);
    normalized = _normalizeContextualTokens(tokens).join(' ');
    normalized = _normalizeSpaces(normalized);

    normalized = _replacePhrases(normalized, _commandPhrases);
    return _normalizeSpaces(normalized);
  }

  static List<String> _normalizeContextualTokens(List<String> tokens) {
    final normalized = <String>[];
    for (final token in tokens) {
      final previous = normalized.isEmpty ? null : normalized.last;
      if (previous != null &&
          _optionPrefixes.contains(previous) &&
          _optionLetterCorrections.containsKey(token)) {
        normalized.add(_optionLetterCorrections[token]!);
        continue;
      }

      normalized.add(token);
    }
    return normalized;
  }

  static String _replacePhrases(String text, Map<String, String> phrases) {
    var normalized = text;
    phrases.forEach((from, to) {
      normalized = normalized.replaceAllMapped(
        RegExp('(^|\\s)${RegExp.escape(from)}(?=\\s|\$)'),
        (match) => '${match.group(1) ?? ''}$to',
      );
    });
    return normalized;
  }

  static String _normalizeSpaces(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ');
}
