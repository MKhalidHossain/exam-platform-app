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
    'explan': 'explain',
  };

  static const Map<String, String> _phraseCorrections = {
    'sub meet': 'submit',
    'sub mid': 'submit',
  };

  static const Map<String, String> _commandPhrases = {
    'next question': 'next',
    'go next': 'next',
    'go back': 'back',
    'read again': 'repeat',
    'say again': 'repeat',
    'mark question': 'flag',
  };

  static String normalize(String text) {
    var normalized = text.toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    normalized = _normalizeSpaces(normalized);

    normalized = _replacePhrases(normalized, _phraseCorrections);
    normalized = normalized
        .split(' ')
        .map((word) => _wordCorrections[word] ?? word)
        .join(' ');
    normalized = _normalizeSpaces(normalized);

    normalized = _replacePhrases(normalized, _commandPhrases);
    return _normalizeSpaces(normalized);
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
