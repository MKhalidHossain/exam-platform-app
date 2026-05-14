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
        VoiceCommandNormalizer.normalize(
          'won too tree for fore nex neckst explan',
        ),
        'one two three four four next next explain',
      );
      expect(VoiceCommandNormalizer.normalize('queston'), 'question');
      expect(
        VoiceCommandNormalizer.normalize('return to queston'),
        'return to question',
      );
      expect(
        VoiceCommandNormalizer.normalize('veiw explanation'),
        'view explanation',
      );
    });

    test('fixes submit speech mistakes', () {
      expect(VoiceCommandNormalizer.normalize('sabmit'), 'submit');
      expect(VoiceCommandNormalizer.normalize('sabit'), 'submit');
      expect(VoiceCommandNormalizer.normalize('sub mit'), 'submit');
      expect(VoiceCommandNormalizer.normalize('sub meet'), 'submit');
      expect(VoiceCommandNormalizer.normalize('sub mid'), 'submit');
      expect(VoiceCommandNormalizer.normalize('finis'), 'finish');
      expect(VoiceCommandNormalizer.normalize('fenish'), 'finish');
      expect(VoiceCommandNormalizer.normalize('revue'), 'review');
      expect(VoiceCommandNormalizer.normalize('ree view'), 'review');
    });

    test('normalizes option letter variants after selection prefixes', () {
      expect(VoiceCommandNormalizer.normalize('select bee'), 'select b');
      expect(VoiceCommandNormalizer.normalize('choose bee'), 'choose b');
      expect(VoiceCommandNormalizer.normalize('answer bee'), 'answer b');
      expect(VoiceCommandNormalizer.normalize('select be'), 'select b');
      expect(VoiceCommandNormalizer.normalize('option bee'), 'option b');
      expect(VoiceCommandNormalizer.normalize('select sea'), 'select c');
      expect(VoiceCommandNormalizer.normalize('select see'), 'select c');
      expect(VoiceCommandNormalizer.normalize('choose sea'), 'choose c');
      expect(VoiceCommandNormalizer.normalize('choose see'), 'choose c');
      expect(VoiceCommandNormalizer.normalize('answer sea'), 'answer c');
      expect(VoiceCommandNormalizer.normalize('answer see'), 'answer c');
      expect(VoiceCommandNormalizer.normalize('select dee'), 'select d');
      expect(VoiceCommandNormalizer.normalize('choose dee'), 'choose d');
      expect(VoiceCommandNormalizer.normalize('answer dee'), 'answer d');
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
