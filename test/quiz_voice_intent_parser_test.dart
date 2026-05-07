import 'package:ej_flutter/controllers/quiz_voice_controller.dart';
import 'package:ej_flutter/services/voice_assistant_settings_service.dart';
import 'package:ej_flutter/services/voice_command_learning_service.dart';
import 'package:ej_flutter/utils/quiz_voice_intent_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('QuizVoiceIntentParser', () {
    test('uses normalized option aliases on MCQ screens', () async {
      expect(
        (await QuizVoiceIntentParser.parse(
          QuizVoiceScreen.mcq,
          'Option A!',
        )).intent,
        VoiceIntent.optionA,
      );
      expect(
        (await QuizVoiceIntentParser.parse(QuizVoiceScreen.mcq, 'too')).intent,
        VoiceIntent.optionB,
      );
      expect(
        (await QuizVoiceIntentParser.parse(QuizVoiceScreen.mcq, 'free')).intent,
        VoiceIntent.optionC,
      );
      expect(
        (await QuizVoiceIntentParser.parse(QuizVoiceScreen.mcq, 'fore')).intent,
        VoiceIntent.optionD,
      );
    });

    test('maps common command aliases to canonical intents', () async {
      expect(
        (await QuizVoiceIntentParser.parse(
          QuizVoiceScreen.mcq,
          'next question',
        )).intent,
        VoiceIntent.next,
      );
      expect(
        (await QuizVoiceIntentParser.parse(
          QuizVoiceScreen.mcq,
          'read again',
        )).intent,
        VoiceIntent.repeat,
      );
      expect(
        (await QuizVoiceIntentParser.parse(
          QuizVoiceScreen.mcq,
          'mark question',
        )).intent,
        VoiceIntent.flag,
      );
      expect(
        (await QuizVoiceIntentParser.parse(QuizVoiceScreen.mcq, 'why')).intent,
        VoiceIntent.explain,
      );
    });

    test('returns normalized and heard text without UI side effects', () async {
      final result = await QuizVoiceIntentParser.parse(
        QuizVoiceScreen.mcq,
        '  Go Next!!! ',
      );

      expect(result.intent, VoiceIntent.next);
      expect(result.confidence, 1);
      expect(result.normalizedText, 'next');
      expect(result.heardText, '  Go Next!!! ');
    });

    test('returns null intent for unknown commands', () async {
      final result = await QuizVoiceIntentParser.parse(
        QuizVoiceScreen.mcq,
        'open the window',
      );

      expect(result.intent, isNull);
      expect(result.confidence, 0);
      expect(result.normalizedText, 'open the window');
    });

    test('executes fuzzy matches only above the command threshold', () async {
      final executable = await QuizVoiceIntentParser.parse(
        QuizVoiceScreen.mcq,
        'nexxt',
      );
      final needsConfirmation = await QuizVoiceIntentParser.parse(
        QuizVoiceScreen.mcq,
        'nexr',
      );

      expect(executable.intent, VoiceIntent.next);
      expect(executable.confidence, greaterThanOrEqualTo(0.78));
      expect(QuizVoiceIntentParser.shouldExecute(executable), isTrue);

      expect(needsConfirmation.intent, VoiceIntent.next);
      expect(needsConfirmation.confidence, inExclusiveRange(0.60, 0.78));
      expect(QuizVoiceIntentParser.shouldExecute(needsConfirmation), isFalse);
      expect(
        QuizVoiceIntentParser.confidenceFeedback(needsConfirmation),
        'Did you mean next?',
      );
    });

    test('uses fallback feedback below the confirmation threshold', () async {
      final result = await QuizVoiceIntentParser.parse(
        QuizVoiceScreen.mcq,
        'window',
      );

      expect(QuizVoiceIntentParser.shouldExecute(result), isFalse);
      expect(
        QuizVoiceIntentParser.confidenceFeedback(result),
        'I did not understand. Say help to hear commands.',
      );
    });

    test('honors command sensitivity thresholds', () async {
      final result = await QuizVoiceIntentParser.parse(
        QuizVoiceScreen.mcq,
        'nexr',
      );

      expect(
        QuizVoiceIntentParser.shouldExecuteWithSensitivity(
          result,
          CommandSensitivity.strict,
        ),
        isFalse,
      );
      expect(
        QuizVoiceIntentParser.shouldExecuteWithSensitivity(
          result,
          CommandSensitivity.flexible,
        ),
        isTrue,
      );
    });

    test(
      'does not execute dangerous fuzzy submit below high confidence',
      () async {
        final fuzzySubmit = await QuizVoiceIntentParser.parse(
          QuizVoiceScreen.mcq,
          'submt',
        );
        final exactSubmit = await QuizVoiceIntentParser.parse(
          QuizVoiceScreen.mcq,
          'submit',
        );

        expect(fuzzySubmit.intent, VoiceIntent.submit);
        expect(fuzzySubmit.confidence, lessThan(0.90));
        expect(QuizVoiceIntentParser.shouldExecute(fuzzySubmit), isFalse);
        expect(
          QuizVoiceIntentParser.confidenceFeedback(fuzzySubmit),
          'I did not understand. Say help to hear commands.',
        );

        expect(exactSubmit.intent, VoiceIntent.submit);
        expect(exactSubmit.confidence, 1);
        expect(QuizVoiceIntentParser.shouldExecute(exactSubmit), isTrue);
      },
    );

    test('uses learned correction before fuzzy matching', () async {
      final beforeLearning = await QuizVoiceIntentParser.parse(
        QuizVoiceScreen.mcq,
        'nexr',
      );
      expect(QuizVoiceIntentParser.shouldExecute(beforeLearning), isFalse);

      await QuizVoiceIntentParser.rememberCorrection('nexr', VoiceIntent.next);

      final afterLearning = await QuizVoiceIntentParser.parse(
        QuizVoiceScreen.mcq,
        'nexr',
      );
      final similarLearned = await QuizVoiceIntentParser.parse(
        QuizVoiceScreen.mcq,
        'nexrr',
      );

      expect(afterLearning.intent, VoiceIntent.next);
      expect(afterLearning.confidence, 0.95);
      expect(QuizVoiceIntentParser.shouldExecute(afterLearning), isTrue);
      expect(similarLearned.intent, VoiceIntent.next);
      expect(similarLearned.confidence, 0.95);
    });
  });

  group('VoiceCommandLearningService', () {
    late VoiceCommandLearningService service;

    setUp(() {
      service = VoiceCommandLearningService();
    });

    test('remembers exact and similar corrections', () async {
      await service.rememberCorrection('nexr', VoiceIntent.next);

      expect(await service.findLearnedIntent('nexr'), VoiceIntent.next);
      expect(await service.findLearnedIntent('nexrr'), VoiceIntent.next);
    });

    test('does not learn submit or confirm submit', () async {
      await service.rememberCorrection('submt', VoiceIntent.submit);
      await service.rememberCorrection('yes submt', VoiceIntent.confirmSubmit);

      expect(await service.findLearnedIntent('submt'), isNull);
      expect(await service.findLearnedIntent('yes submt'), isNull);
    });

    test('stores at most 100 corrections', () async {
      for (int i = 0; i < 105; i++) {
        await service.rememberCorrection('custom phrase $i', VoiceIntent.next);
      }

      final prefs = await SharedPreferences.getInstance();
      final stored =
          prefs.getStringList(VoiceCommandLearningService.storageKey) ??
          const <String>[];

      expect(stored.length, 100);
      expect(
        await service.findLearnedIntent('custom phrase 104'),
        VoiceIntent.next,
      );
    });
  });
}
