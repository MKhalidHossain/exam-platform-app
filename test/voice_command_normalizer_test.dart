import 'package:ej_flutter/utils/voice_command_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceCommandNormalizer', () {
    test('lowercases text, removes punctuation, and normalizes spaces', () {
      expect(
        VoiceCommandNormalizer.normalize('  NEXT,   Question!!!  '),
        'next',
      );
    });

    test('fixes common spoken word mistakes', () {
      expect(
        VoiceCommandNormalizer.normalize('won too tree for fore nex explan'),
        'one two three four four next explain',
      );
    });

    test('fixes submit speech mistakes', () {
      expect(VoiceCommandNormalizer.normalize('sub meet'), 'submit');
      expect(VoiceCommandNormalizer.normalize('sub mid'), 'submit');
    });

    test('converts common command phrases', () {
      expect(VoiceCommandNormalizer.normalize('go next'), 'next');
      expect(VoiceCommandNormalizer.normalize('go back'), 'back');
      expect(VoiceCommandNormalizer.normalize('read again'), 'repeat');
      expect(VoiceCommandNormalizer.normalize('say again'), 'repeat');
      expect(VoiceCommandNormalizer.normalize('mark question'), 'flag');
    });
  });
}
