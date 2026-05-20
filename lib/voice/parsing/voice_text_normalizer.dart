enum VoiceAccentProfile {
  defaultEnglish,
  africanEnglish,
  indianEnglish,
  ukEnglish,
  usEnglish,
  customLearned,
}

extension VoiceAccentProfileLabel on VoiceAccentProfile {
  String get label => switch (this) {
    VoiceAccentProfile.defaultEnglish => 'Default English',
    VoiceAccentProfile.africanEnglish => 'African English',
    VoiceAccentProfile.indianEnglish => 'Indian English',
    VoiceAccentProfile.ukEnglish => 'UK English',
    VoiceAccentProfile.usEnglish => 'US English',
    VoiceAccentProfile.customLearned => 'Custom Learned',
  };
}

class VoiceTextNormalizer {
  static const Map<String, String> _phraseCorrections = {
    'of shun': 'option',
    'of sun': 'option',
    'of son': 'option',
    'op shun': 'option',
    'op sun': 'option',
    'opson': 'option',
    'opshun': 'option',
    'go nest': 'go next',
    'go nex': 'go next',
    'kweshen': 'question',
    'kweschen': 'question',
    'queshan': 'question',
    'queshen': 'question',
    'queschen': 'question',
    'kwestion': 'question',
    'queston': 'question',
    'sylhetse': 'select c',
    'syletse': 'select c',
    'sylnetse': 'select c',
    'sylentse': 'select c',
    'sub mit': 'submit',
    'ree view': 'review',
  };

  static const Map<VoiceAccentProfile, Map<String, String>>
  _profilePhraseCorrections = {
    VoiceAccentProfile.africanEnglish: {
      'kweshen': 'question',
      'queshen': 'question',
      'queshan': 'question',
      'sub meet': 'submit',
      'sum mit': 'submit',
    },
    VoiceAccentProfile.indianEnglish: {
      'sub meet': 'submit',
      'kweshen': 'question',
    },
    VoiceAccentProfile.ukEnglish: {},
    VoiceAccentProfile.usEnglish: {},
    VoiceAccentProfile.customLearned: {},
  };

  static const Map<String, String> _wordCorrections = {
    'nex': 'next',
    'neckst': 'next',
    'nest': 'next',
    'reed': 'read',
    'flug': 'flag',
    'flak': 'flag',
    'flagged': 'flag',
    'syllet': 'select',
    'sillect': 'select',
    'sylhet': 'select',
    'sylet': 'select',
    'slect': 'select',
    'sellect': 'select',
    'sabmit': 'submit',
    'sabit': 'submit',
    'finis': 'finish',
    'fenish': 'finish',
    'revue': 'review',
    'veiw': 'view',
    'fals': 'false',
    'falls': 'false',
    'tru': 'true',
    'through': 'true',
    'tree': 'three',
    'free': 'three',
    'won': 'one',
    'too': 'two',
    'for': 'four',
    'fore': 'four',
  };

  static const Map<VoiceAccentProfile, Map<String, String>>
  _profileWordCorrections = {
    VoiceAccentProfile.africanEnglish: {
      'summit': 'submit',
      'kweshen': 'question',
      'queshen': 'question',
      'queshan': 'question',
    },
    VoiceAccentProfile.indianEnglish: {'summit': 'submit'},
    VoiceAccentProfile.ukEnglish: {},
    VoiceAccentProfile.usEnglish: {},
    VoiceAccentProfile.customLearned: {},
  };

  static const Map<String, String> _optionLetterCorrections = {
    'ay': 'a',
    'hey': 'a',
    'bee': 'b',
    'be': 'b',
    'bi': 'b',
    'si': 'c',
    'sea': 'c',
    'see': 'c',
    'dee': 'd',
    'de': 'd',
    'the': 'd',
  };

  static const Map<String, String> _numberWords = {
    'zero': '0',
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
    'first': '1',
    'second': '2',
    'third': '3',
    'fourth': '4',
    'fifth': '5',
    'sixth': '6',
    'seventh': '7',
    'eighth': '8',
    'ninth': '9',
    'tenth': '10',
  };

  static const Set<String> _optionPrefixes = {
    'option',
    'answer',
    'select',
    'choose',
    'letter',
  };

  static const Set<String> _numberPrefixes = {
    'question',
    'questions',
    'number',
    'count',
    'total',
    'max',
    'maximum',
    'min',
    'minimum',
    'to',
    'q',
  };

  const VoiceTextNormalizer._();

  static String normalize(
    String text, {
    VoiceAccentProfile accentProfile = VoiceAccentProfile.defaultEnglish,
  }) {
    var normalized = text.toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    normalized = _normalizeSpaces(normalized);
    if (normalized.isEmpty) return normalized;

    normalized = _replacePhrases(normalized, _phraseCorrections);
    normalized = _replacePhrases(
      normalized,
      _profilePhraseCorrections[accentProfile] ?? const <String, String>{},
    );
    normalized = _normalizeSpaces(normalized);

    final wordCorrections = {
      ..._wordCorrections,
      ...?_profileWordCorrections[accentProfile],
    };
    final tokens = normalized
        .split(' ')
        .map((token) => wordCorrections[token] ?? token)
        .toList(growable: false);

    return _normalizeSpaces(_normalizeContextualTokens(tokens).join(' '));
  }

  static List<String> _normalizeContextualTokens(List<String> tokens) {
    final normalized = <String>[];
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      final previous = normalized.isEmpty ? null : normalized.last;

      if (previous != null &&
          _optionPrefixes.contains(previous) &&
          _optionLetterCorrections.containsKey(token)) {
        normalized.add(_optionLetterCorrections[token]!);
        continue;
      }

      if (previous != null &&
          _numberPrefixes.contains(previous) &&
          _numberWords.containsKey(token)) {
        normalized.add(_numberWords[token]!);
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

  static String _normalizeSpaces(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
