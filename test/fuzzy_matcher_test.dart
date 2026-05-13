import 'package:ej_flutter/voice/core/voice_command_context.dart';
import 'package:ej_flutter/voice/core/voice_intent.dart';
import 'package:ej_flutter/voice/parsing/fuzzy_matcher.dart';
import 'package:ej_flutter/voice/parsing/voice_command_aliases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FuzzyMatcher', () {
    test('matches close option text against alias registry', () {
      final result = FuzzyMatcher.matchAliases(
        'opton b',
        VoiceScreenContext.quiz,
      );

      expect(result?.matchedPhrase, 'option b');
      expect(result?.intent?.type, VoiceIntentType.optionB);
      expect(result?.score, greaterThan(0.80));
    });

    test('matches normalized option text after accent cleanup', () {
      final result = FuzzyMatcher.matchAliases(
        'opson bee',
        VoiceScreenContext.quiz,
      );

      expect(result?.matchedPhrase, 'option b');
      expect(result?.normalizedQuery, 'option b');
      expect(result?.score, 1.0);
    });

    test('matches navigation and reading phrases', () {
      final next = FuzzyMatcher.matchAliases(
        'nex question',
        VoiceScreenContext.quiz,
      );
      final read = FuzzyMatcher.matchAliases(
        'reed question',
        VoiceScreenContext.quiz,
      );

      expect(next?.matchedPhrase, 'next question');
      expect(next?.intent?.type, VoiceIntentType.next);
      expect(read?.matchedPhrase, 'read question');
      expect(read?.intent?.type, VoiceIntentType.readQuestion);
    });

    test('matches custom candidates and returns associated intent', () {
      final result = FuzzyMatcher.match('revue answers', [
        FuzzyMatchCandidate(
          phrase: 'review answers',
          intent: VoiceCommandAliases.intentFor(
            type: VoiceIntentType.review,
            phrase: 'review answers',
          ),
        ),
        const FuzzyMatchCandidate(phrase: 'read summary'),
      ]);

      expect(result?.matchedPhrase, 'review answers');
      expect(result?.intent?.type, VoiceIntentType.review);
      expect(result?.score, greaterThan(0.75));
    });

    test('keeps risky submit matches marked for safety review', () {
      final result = FuzzyMatcher.matchAliases(
        'confarm submit',
        VoiceScreenContext.review,
      );

      expect(result?.matchedPhrase, 'confirm submit');
      expect(result?.intent?.type, VoiceIntentType.confirmSubmit);
      expect(result?.isRisky, isTrue);
      expect(result?.intent?.type, isNot(VoiceIntentType.finalSubmit));
    });
  });
}
