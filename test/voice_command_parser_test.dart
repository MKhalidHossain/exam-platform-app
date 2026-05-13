import 'package:ej_flutter/voice/core/voice_command_context.dart';
import 'package:ej_flutter/voice/core/voice_command_result.dart';
import 'package:ej_flutter/voice/core/voice_intent.dart';
import 'package:ej_flutter/voice/parsing/voice_command_aliases.dart';
import 'package:ej_flutter/voice/parsing/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceCommandParser', () {
    test('executes exact safe aliases for the current screen', () {
      final result = VoiceCommandParser.parse(
        rawText: 'option bee',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, VoiceCommandDecision.execute);
      expect(result.intent?.type, VoiceIntentType.optionB);
      expect(result.intent?.normalizedText, 'option b');
    });

    test('uses learned corrections only for matching screen context', () {
      final learnedIntent = VoiceCommandAliases.intentFor(
        type: VoiceIntentType.next,
        phrase: 'next question',
      );
      final corrections = [
        VoiceLearnedCorrection(
          context: VoiceScreenContext.quiz,
          phrase: 'my next',
          intent: learnedIntent,
        ),
      ];

      final quizResult = VoiceCommandParser.parse(
        rawText: 'my next',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
        learnedCorrections: corrections,
      );
      final reviewResult = VoiceCommandParser.parse(
        rawText: 'my next',
        context: VoiceScreenContext.review,
        sensitivity: VoiceCommandSensitivity.normal,
        learnedCorrections: corrections,
      );

      expect(quizResult.decision, VoiceCommandDecision.execute);
      expect(quizResult.intent?.source, 'learned_correction');
      expect(reviewResult.intent?.source, isNot('learned_correction'));
    });

    test('matches question number jump patterns', () {
      final result = VoiceCommandParser.parse(
        rawText: 'question five',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, VoiceCommandDecision.execute);
      expect(result.intent?.type, VoiceIntentType.questionNumber);
      expect(result.intent?.number, 5);
    });

    test('matches set question count patterns', () {
      final result = VoiceCommandParser.parse(
        rawText: 'set questions to 10',
        context: VoiceScreenContext.settings,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, VoiceCommandDecision.execute);
      expect(result.intent?.type, VoiceIntentType.setQuestionCount);
      expect(result.intent?.number, 10);
    });

    test('executes high-confidence fuzzy safe aliases', () {
      final result = VoiceCommandParser.parse(
        rawText: 'reed question',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, VoiceCommandDecision.execute);
      expect(result.intent?.type, VoiceIntentType.readQuestion);
      expect(result.intent?.source, 'fuzzy_alias');
    });

    test('falls back to cloud for unknown local commands', () {
      final result = VoiceCommandParser.parse(
        rawText: 'show me the moon',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, VoiceCommandDecision.fallbackToCloud);
    });

    test('submit quiz asks confirmation even on exact match', () {
      final result = VoiceCommandParser.parse(
        rawText: 'submit quiz',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, VoiceCommandDecision.askConfirmation);
      expect(result.intent?.type, VoiceIntentType.submit);
      expect(result.intent?.isRisky, isTrue);
    });

    test('confirm submit requires strong confidence', () {
      final exact = VoiceCommandParser.parse(
        rawText: 'confirm submit',
        context: VoiceScreenContext.review,
        sensitivity: VoiceCommandSensitivity.normal,
      );
      final fuzzy = VoiceCommandParser.parse(
        rawText: 'confarm submit',
        context: VoiceScreenContext.review,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(exact.decision, VoiceCommandDecision.execute);
      expect(exact.intent?.type, VoiceIntentType.confirmSubmit);
      expect(fuzzy.decision, VoiceCommandDecision.askConfirmation);
      expect(fuzzy.intent?.type, VoiceIntentType.confirmSubmit);
    });
  });
}
