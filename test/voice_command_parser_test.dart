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

    test('maps quiz option selection phrases to option intents', () {
      final cases = <String, VoiceIntentType>{
        'select a': VoiceIntentType.optionA,
        'select b': VoiceIntentType.optionB,
        'select option b': VoiceIntentType.optionB,
        'choose b': VoiceIntentType.optionB,
        'answer b': VoiceIntentType.optionB,
        'select bee': VoiceIntentType.optionB,
        'option si': VoiceIntentType.optionC,
        'option see': VoiceIntentType.optionC,
        'option sea': VoiceIntentType.optionC,
        'answer si': VoiceIntentType.optionC,
        'answer see': VoiceIntentType.optionC,
        'answer sea': VoiceIntentType.optionC,
        'select c': VoiceIntentType.optionC,
        'select sea': VoiceIntentType.optionC,
        'select d': VoiceIntentType.optionD,
        'select dee': VoiceIntentType.optionD,
      };

      for (final entry in cases.entries) {
        final result = VoiceCommandParser.parse(
          rawText: entry.key,
          context: VoiceScreenContext.quiz,
          sensitivity: VoiceCommandSensitivity.normal,
        );

        expect(
          result.decision,
          VoiceCommandDecision.execute,
          reason: entry.key,
        );
        expect(result.intent?.type, entry.value, reason: entry.key);
      }
    });

    test('learned corrections cannot override direct option grammar', () {
      final staleOptionA = VoiceCommandAliases.intentFor(
        type: VoiceIntentType.optionA,
        phrase: 'option a',
        value: 'a',
      );

      for (final phrase in ['option si', 'answer sea']) {
        final result = VoiceCommandParser.parse(
          rawText: phrase,
          context: VoiceScreenContext.quiz,
          sensitivity: VoiceCommandSensitivity.normal,
          learnedCorrections: [
            VoiceLearnedCorrection(
              context: VoiceScreenContext.quiz,
              phrase: phrase,
              intent: staleOptionA,
            ),
          ],
        );

        expect(result.decision, VoiceCommandDecision.execute, reason: phrase);
        expect(result.intent?.type, VoiceIntentType.optionC, reason: phrase);
      }
    });

    test('partial weak option text does not execute', () {
      final result = VoiceCommandParser.parse(
        rawText: 'option',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, isNot(VoiceCommandDecision.execute));
    });

    test('keeps option selection aliases quiz-screen only', () {
      final result = VoiceCommandParser.parse(
        rawText: 'select b',
        context: VoiceScreenContext.review,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.intent?.type, isNot(VoiceIntentType.optionB));
    });

    test('maps review return phrases to back intent', () {
      for (final phrase in ['return', 'return question', 'return to queston']) {
        final result = VoiceCommandParser.parse(
          rawText: phrase,
          context: VoiceScreenContext.review,
          sensitivity: VoiceCommandSensitivity.normal,
        );

        expect(result.decision, VoiceCommandDecision.execute, reason: phrase);
        expect(result.intent?.type, VoiceIntentType.back, reason: phrase);
      }
    });

    test('keeps review return phrases screen-aware', () {
      final result = VoiceCommandParser.parse(
        rawText: 'return to question',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.intent?.type, isNot(VoiceIntentType.back));
    });

    test('maps quiz explanation phrases to explain intent', () {
      for (final phrase in [
        'explain',
        'view explanation',
        'veiw explanation',
        'explanation',
      ]) {
        final result = VoiceCommandParser.parse(
          rawText: phrase,
          context: VoiceScreenContext.quiz,
          sensitivity: VoiceCommandSensitivity.normal,
        );

        expect(result.decision, VoiceCommandDecision.execute, reason: phrase);
        expect(result.intent?.type, VoiceIntentType.explain, reason: phrase);
      }
    });

    test('keeps explanation phrases quiz-screen only', () {
      final result = VoiceCommandParser.parse(
        rawText: 'explain',
        context: VoiceScreenContext.review,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.intent?.type, isNot(VoiceIntentType.explain));
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

    test('ambiguous fuzzy commands ask for retry instead of executing', () {
      final result = VoiceCommandParser.parse(
        rawText: 'go review',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, VoiceCommandDecision.notUnderstood);
      expect(result.message, contains('more than one command'));
    });

    test('falls back to cloud for unknown local commands', () {
      final result = VoiceCommandParser.parse(
        rawText: 'show me the moon',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, VoiceCommandDecision.fallbackToCloud);
    });

    test('submit and finish execute directly on quiz and review screens', () {
      final result = VoiceCommandParser.parse(
        rawText: 'submit quiz',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );
      final finish = VoiceCommandParser.parse(
        rawText: 'fenish',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );
      final finalSubmit = VoiceCommandParser.parse(
        rawText: 'final submit',
        context: VoiceScreenContext.review,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, VoiceCommandDecision.execute);
      expect(result.intent?.type, VoiceIntentType.submit);
      expect(result.intent?.type, isNot(VoiceIntentType.confirmSubmit));
      expect(result.intent?.isRisky, isTrue);
      expect(finish.decision, VoiceCommandDecision.execute);
      expect(finish.intent?.type, VoiceIntentType.submit);
      expect(finalSubmit.decision, VoiceCommandDecision.execute);
      expect(finalSubmit.intent?.type, VoiceIntentType.submit);
    });

    test('new speech aliases map to navigation commands', () {
      final next = VoiceCommandParser.parse(
        rawText: 'neckst',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );
      final review = VoiceCommandParser.parse(
        rawText: 'ree view',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(next.decision, VoiceCommandDecision.execute);
      expect(next.intent?.type, VoiceIntentType.next);
      expect(review.decision, VoiceCommandDecision.execute);
      expect(review.intent?.type, VoiceIntentType.review);
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
