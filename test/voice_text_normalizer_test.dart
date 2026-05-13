import 'package:ej_flutter/voice/parsing/voice_text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceTextNormalizer', () {
    test('lowercases, trims, removes punctuation, and collapses spaces', () {
      expect(
        VoiceTextNormalizer.normalize('  NEXT,   Question!!!  '),
        'next question',
      );
    });

    test('normalizes spoken option letter variants', () {
      expect(VoiceTextNormalizer.normalize('option bee'), 'option b');
      expect(VoiceTextNormalizer.normalize('option be'), 'option b');
      expect(VoiceTextNormalizer.normalize('of shun b'), 'option b');
      expect(VoiceTextNormalizer.normalize('opson bee'), 'option b');
      expect(VoiceTextNormalizer.normalize('answer sea'), 'answer c');
      expect(VoiceTextNormalizer.normalize('answer see'), 'answer c');
      expect(VoiceTextNormalizer.normalize('option dee'), 'option d');
    });

    test('normalizes common accent and STT mistakes', () {
      expect(VoiceTextNormalizer.normalize('tree'), 'three');
      expect(VoiceTextNormalizer.normalize('free'), 'three');
      expect(VoiceTextNormalizer.normalize('fals'), 'false');
      expect(VoiceTextNormalizer.normalize('falls'), 'false');
      expect(VoiceTextNormalizer.normalize('kweschen'), 'question');
      expect(VoiceTextNormalizer.normalize('nex'), 'next');
    });

    test('normalizes useful number words in question references', () {
      expect(VoiceTextNormalizer.normalize('question five'), 'question 5');
      expect(VoiceTextNormalizer.normalize('question third'), 'question 3');
      expect(VoiceTextNormalizer.normalize('number ten'), 'number 10');
    });

    test('does not over-normalize risky command misspellings', () {
      expect(VoiceTextNormalizer.normalize('sub meet'), 'sub meet');
      expect(VoiceTextNormalizer.normalize('confarm submit'), 'confarm submit');
      expect(VoiceTextNormalizer.normalize('summit quiz'), 'summit quiz');
    });
  });
}
