import 'package:flutter_tts/flutter_tts.dart' hide ErrorHandler;

/// Picks a known high-quality TTS voice for the requested locale and applies
/// it to [tts]. Always calls [FlutterTts.setLanguage] as a baseline; tries
/// [FlutterTts.setVoice] when a voice matching the locale is installed.
///
/// Today flutter_tts is configured with only setLanguage(), which lets the
/// system pick *any* installed voice for the language tag. On many Android
/// builds that defaults to a low-quality "compact" voice. Selecting an
/// explicit voice when one is available gives noticeably clearer narration
/// for UK / US / African English without changing the engine.
class TtsVoicePicker {
  static const Map<String, List<String>> _preferredVoicesByLocale =
      <String, List<String>>{
    'en-US': <String>[
      'en-us-x-iol-network',
      'en-us-x-tpf-network',
      'en-us-x-sfg-network',
      'en-US-language',
      'Samantha',
    ],
    'en-GB': <String>[
      'en-gb-x-fis-network',
      'en-gb-x-rjs-network',
      'en-GB-language',
      'Daniel',
    ],
    'en-NG': <String>[
      'en-ng-x-ngm-network',
      'en-NG-language',
    ],
    'en-KE': <String>[
      'en-ke-x-kel-network',
      'en-KE-language',
    ],
    'en-ZA': <String>[
      'en-za-x-zaf-network',
      'en-ZA-language',
    ],
    'en-IN': <String>[
      'en-in-x-ene-network',
      'en-IN-language',
      'Rishi',
    ],
  };

  /// Applies the language, then attempts to set an explicit voice. Returns the
  /// voice map that was applied (or `null` if only [setLanguage] succeeded).
  /// Never throws — voice availability varies wildly across devices.
  static Future<Map<String, String>?> applyBestVoice(
    FlutterTts tts, {
    required String languageCode,
  }) async {
    final normalizedLocale = _normalizeLocale(languageCode);
    try {
      await tts.setLanguage(normalizedLocale);
    } catch (_) {
      // setLanguage occasionally throws if the platform engine is mid-init;
      // the caller already configured pitch/rate so we silently continue.
    }

    final preferredNames = _preferredVoicesByLocale[normalizedLocale];
    if (preferredNames == null || preferredNames.isEmpty) return null;

    final List<Map<String, String>> voices;
    try {
      final dynamic raw = await tts.getVoices;
      voices = _coerceVoiceList(raw);
    } catch (_) {
      return null;
    }
    if (voices.isEmpty) return null;

    Map<String, String>? chosen;
    for (final preferred in preferredNames) {
      chosen = _firstWhere(
        voices,
        (voice) =>
            (voice['name'] ?? '').toLowerCase() == preferred.toLowerCase(),
      );
      if (chosen != null) break;
    }

    chosen ??= _firstWhere(
      voices,
      (voice) {
        final locale = (voice['locale'] ?? '').toLowerCase();
        return locale == normalizedLocale.toLowerCase() ||
            locale == normalizedLocale.replaceAll('-', '_').toLowerCase();
      },
    );

    if (chosen == null) return null;
    try {
      await tts.setVoice(chosen);
      return chosen;
    } catch (_) {
      return null;
    }
  }

  static String _normalizeLocale(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return 'en-US';
    return trimmed.replaceAll('_', '-');
  }

  static List<Map<String, String>> _coerceVoiceList(dynamic raw) {
    if (raw is! List) return const <Map<String, String>>[];
    return raw
        .whereType<Map>()
        .map<Map<String, String>>((entry) {
          final map = <String, String>{};
          entry.forEach((key, value) {
            if (key is String && value != null) {
              map[key] = value.toString();
            }
          });
          return map;
        })
        .toList(growable: false);
  }

  static Map<String, String>? _firstWhere(
    List<Map<String, String>> voices,
    bool Function(Map<String, String> voice) predicate,
  ) {
    for (final voice in voices) {
      if (predicate(voice)) return voice;
    }
    return null;
  }
}
