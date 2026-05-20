import 'dart:convert';
import 'dart:io';

import 'package:ej_flutter/controllers/quiz_voice_controller.dart';
import 'package:ej_flutter/services/voice_assistant_settings_service.dart';
import 'package:ej_flutter/utils/quiz_voice_intent_parser.dart' as legacy;
import 'package:ej_flutter/utils/voice_command_processor.dart';
import 'package:ej_flutter/voice/core/voice_command_context.dart';
import 'package:ej_flutter/voice/core/voice_command_result.dart' as core;
import 'package:ej_flutter/voice/core/voice_intent.dart';
import 'package:ej_flutter/voice/core/voice_safety_policy.dart';
import 'package:ej_flutter/voice/learning/voice_learning_service.dart';
import 'package:ej_flutter/voice/parsing/fuzzy_matcher.dart';
import 'package:ej_flutter/voice/parsing/voice_command_parser.dart';
import 'package:ej_flutter/voice/parsing/voice_text_normalizer.dart';
import 'package:ej_flutter/voice/recognition/cloud_speech_service.dart';
import 'package:ej_flutter/voice/recognition/speech_recognition_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VoiceTextNormalizer', () {
    test('normalizes common option and number transcripts', () {
      expect(VoiceTextNormalizer.normalize('option bee'), 'option b');
      expect(VoiceTextNormalizer.normalize('opson bee'), 'option b');
      expect(VoiceTextNormalizer.normalize('option si'), 'option c');
      expect(VoiceTextNormalizer.normalize('option see'), 'option c');
      expect(VoiceTextNormalizer.normalize('option sea'), 'option c');
      expect(VoiceTextNormalizer.normalize('select see'), 'select c');
      expect(VoiceTextNormalizer.normalize('select sea'), 'select c');
      expect(VoiceTextNormalizer.normalize('select si'), 'select c');
      expect(VoiceTextNormalizer.normalize('sylhetse'), 'select c');
      expect(VoiceTextNormalizer.normalize('sylhet see'), 'select c');
      expect(VoiceTextNormalizer.normalize('sylhet c'), 'select c');
      expect(VoiceTextNormalizer.normalize('sylet see'), 'select c');
      expect(VoiceTextNormalizer.normalize('syletse'), 'select c');
      expect(VoiceTextNormalizer.normalize('sylnetse'), 'select c');
      expect(VoiceTextNormalizer.normalize('sylentse'), 'select c');
      expect(VoiceTextNormalizer.normalize('syllet see'), 'select c');
      expect(VoiceTextNormalizer.normalize('sillect c'), 'select c');
      expect(VoiceTextNormalizer.normalize('go nest'), 'go next');
      expect(VoiceTextNormalizer.normalize('nex question'), 'next question');
      expect(VoiceTextNormalizer.normalize('reed question'), 'read question');
      expect(VoiceTextNormalizer.normalize('flug'), 'flag');
      expect(VoiceTextNormalizer.normalize('flak'), 'flag');
      expect(VoiceTextNormalizer.normalize('question five'), 'question 5');
    });
  });

  group('FuzzyMatcher', () {
    test('matches misspelled local aliases deterministically', () {
      expect(
        FuzzyMatcher.matchAliases(
          'opton b',
          VoiceScreenContext.quiz,
        )?.matchedPhrase,
        'option b',
      );
      expect(
        FuzzyMatcher.matchAliases(
          'nex question',
          VoiceScreenContext.quiz,
        )?.matchedPhrase,
        'next question',
      );
    });
  });

  group('VoiceCommandParser', () {
    test('maps normalized option B transcript to select B', () {
      final result = VoiceCommandParser.parse(
        rawText: 'opson bee',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, core.VoiceCommandDecision.execute);
      expect(result.intent?.type, VoiceIntentType.optionB);
      expect(result.intent?.value, 'b');
    });

    test('maps common safe aliases and accent variants', () {
      final cases = <String, VoiceIntentType>{
        'next': VoiceIntentType.next,
        'go nest': VoiceIntentType.next,
        'nex question': VoiceIntentType.next,
        'reed question': VoiceIntentType.readQuestion,
        'repeat': VoiceIntentType.repeat,
        'flug': VoiceIntentType.flag,
        'flak': VoiceIntentType.flag,
        'bookmark': VoiceIntentType.bookmark,
        'sillect c': VoiceIntentType.optionC,
        'choose sea': VoiceIntentType.optionC,
        'select see': VoiceIntentType.optionC,
        'select sea': VoiceIntentType.optionC,
        'select si': VoiceIntentType.optionC,
        'go back': VoiceIntentType.previous,
        'back': VoiceIntentType.previous,
        'previous question': VoiceIntentType.previous,
        'prev': VoiceIntentType.previous,
        'move back': VoiceIntentType.previous,
      };

      for (final entry in cases.entries) {
        final result = VoiceCommandParser.parse(
          rawText: entry.key,
          context: VoiceScreenContext.quiz,
          sensitivity: VoiceCommandSensitivity.normal,
        );

        expect(
          result.decision,
          core.VoiceCommandDecision.execute,
          reason: entry.key,
        );
        expect(result.intent?.type, entry.value, reason: entry.key);
      }
    });

    test('distorted select C transcripts execute option C', () {
      for (final phrase in const [
        'sylhetse',
        'sylhet see',
        'sylhet c',
        'sylet see',
        'syletse',
        'sylnetse',
        'sylentse',
        'syllet see',
        'sillect c',
        'select see',
        'select sea',
        'select si',
      ]) {
        final result = VoiceCommandParser.parse(
          rawText: phrase,
          context: VoiceScreenContext.quiz,
          sensitivity: VoiceCommandSensitivity.normal,
        );

        expect(
          result.decision,
          core.VoiceCommandDecision.execute,
          reason: phrase,
        );
        expect(result.intent?.type, VoiceIntentType.optionC, reason: phrase);
        expect(result.intent?.value, 'c', reason: phrase);
      }
    });

    test('exact safe alias executes with high local confidence', () {
      final result = VoiceCommandParser.parse(
        rawText: 'next',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.strict,
      );

      expect(result.decision, core.VoiceCommandDecision.execute);
      expect(result.intent?.type, VoiceIntentType.next);
      expect(result.intent?.confidence, 1);
      expect(result.intent?.source, 'exact_alias');
    });

    test('direct option C variants override stale learned option A', () {
      for (final phrase in const [
        'option si',
        'option see',
        'option sea',
        'sylhetse',
        'sylhet see',
        'sylhet c',
        'sylet see',
        'syletse',
        'sylnetse',
        'sylentse',
        'answer si',
        'answer see',
        'answer sea',
      ]) {
        final result = VoiceCommandParser.parse(
          rawText: phrase,
          context: VoiceScreenContext.quiz,
          sensitivity: VoiceCommandSensitivity.normal,
          learnedCorrections: [
            VoiceLearnedCorrection(
              context: VoiceScreenContext.quiz,
              phrase: phrase,
              intent: VoiceIntent(
                type: VoiceIntentType.optionA,
                value: 'a',
                confidence: 0.95,
                isRisky: false,
                rawText: phrase,
                normalizedText: VoiceTextNormalizer.normalize(phrase),
                source: 'test_stale_correction',
              ),
            ),
          ],
        );

        expect(
          result.decision,
          core.VoiceCommandDecision.execute,
          reason: phrase,
        );
        expect(result.intent?.type, VoiceIntentType.optionC, reason: phrase);
        expect(result.intent?.value, 'c', reason: phrase);
      }
    });

    test(
      'canonical quiz answer grammar maps C-like transcripts to index C',
      () {
        for (final phrase in const [
          'option si',
          'option see',
          'option sea',
          'sylhetse',
          'sylhet see',
          'sylhet c',
          'sylet see',
          'syletse',
          'sylnetse',
          'sylentse',
          'answer si',
          'answer see',
          'answer sea',
        ]) {
          expect(
            VoiceCommandParser.quizAnswerIndexesForText(
              rawText: phrase,
              optionCount: 4,
              isTrueFalse: false,
              isMultiSelect: false,
            ),
            {2},
            reason: phrase,
          );
        }
      },
    );

    test('maps next question transcript to next', () {
      final result = VoiceCommandParser.parse(
        rawText: 'nex question',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, core.VoiceCommandDecision.execute);
      expect(result.intent?.type, VoiceIntentType.next);
    });

    test('maps question five to jumpToQuestion(5)', () {
      final result = VoiceCommandParser.parse(
        rawText: 'question five',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(result.decision, core.VoiceCommandDecision.execute);
      expect(result.intent?.type, VoiceIntentType.questionNumber);
      expect(result.intent?.number, 5);
    });

    test('maps set questions to ten to setQuestionCount(10)', () {
      final result = VoiceCommandParser.parse(
        rawText: 'set questions to ten',
        context: VoiceScreenContext.settings,
        sensitivity: VoiceCommandSensitivity.normal,
        learnedCorrections: const <VoiceLearnedCorrection>[
          VoiceLearnedCorrection(
            context: VoiceScreenContext.settings,
            phrase: 'set questions to ten',
            intent: VoiceIntent(
              type: VoiceIntentType.setQuestionCount,
              number: 10,
              confidence: 0.95,
              isRisky: false,
              rawText: 'set questions to ten',
              normalizedText: 'set questions to ten',
              source: 'test',
            ),
          ),
        ],
      );

      expect(result.decision, core.VoiceCommandDecision.execute);
      expect(result.intent?.type, VoiceIntentType.setQuestionCount);
      expect(result.intent?.number, 10);
    });

    test('weak submit match must not execute', () {
      final result = VoiceCommandParser.parse(
        rawText: 'sub quiz',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.strict,
      );

      expect(result.intent?.type, VoiceIntentType.submit);
      expect(result.decision, isNot(core.VoiceCommandDecision.execute));
    });

    test('quiz submit executes, review strong submit executes immediately', () {
      final quizSubmit = VoiceCommandParser.parse(
        rawText: 'sabmit',
        context: VoiceScreenContext.quiz,
        sensitivity: VoiceCommandSensitivity.normal,
      );
      final reviewFinish = VoiceCommandParser.parse(
        rawText: 'finish',
        context: VoiceScreenContext.review,
        sensitivity: VoiceCommandSensitivity.normal,
      );
      final reviewFinalSubmit = VoiceCommandParser.parse(
        rawText: 'final submit',
        context: VoiceScreenContext.review,
        sensitivity: VoiceCommandSensitivity.normal,
      );

      expect(quizSubmit.intent?.type, VoiceIntentType.submit);
      expect(quizSubmit.decision, core.VoiceCommandDecision.execute);
      expect(
        VoiceSafetyPolicy.submitLikeTypes,
        contains(reviewFinish.intent?.type),
      );
      expect(reviewFinish.decision, core.VoiceCommandDecision.execute);
      expect(
        VoiceSafetyPolicy.submitLikeTypes,
        contains(reviewFinalSubmit.intent?.type),
      );
      expect(reviewFinalSubmit.decision, core.VoiceCommandDecision.execute);
    });

    test('confirm submit requires strong confidence before execution', () {
      final weakResult = VoiceCommandParser.parse(
        rawText: 'confarm submit',
        context: VoiceScreenContext.review,
        sensitivity: VoiceCommandSensitivity.strict,
      );
      final strongResult = VoiceCommandParser.parse(
        rawText: 'confirm submit',
        context: VoiceScreenContext.review,
        sensitivity: VoiceCommandSensitivity.strict,
      );

      expect(weakResult.intent?.type, VoiceIntentType.confirmSubmit);
      expect(weakResult.decision, isNot(core.VoiceCommandDecision.execute));
      expect(strongResult.intent?.type, VoiceIntentType.confirmSubmit);
      expect(strongResult.intent?.confidence, greaterThanOrEqualTo(0.9));
      expect(strongResult.decision, core.VoiceCommandDecision.execute);
    });
  });

  group('VoiceSafetyPolicy', () {
    test('marks risky submit and reset commands', () {
      expect(VoiceSafetyPolicy.isRiskyText('submit quiz'), isTrue);
      expect(VoiceSafetyPolicy.isRiskyText('reset answers'), isTrue);
      expect(
        VoiceSafetyPolicy.isRiskyIntentType(VoiceIntentType.confirmSubmit),
        isTrue,
      );
      expect(
        VoiceSafetyPolicy.isRiskyIntentType(VoiceIntentType.next),
        isFalse,
      );
    });
  });

  group('VoiceLearningService', () {
    test('does not learn risky commands automatically', () async {
      SharedPreferences.setMockInitialValues({});
      const service = VoiceLearningService(userOrDeviceId: 'voice-test');

      final saved = await service.saveCorrection(
        rawHeardText: 'reset answers',
        intent: const VoiceIntent(
          type: VoiceIntentType.resetAnswers,
          confidence: 1,
          isRisky: true,
          rawText: 'reset answers',
          normalizedText: 'reset answers',
          source: 'test',
        ),
        screenContext: VoiceScreenContext.quiz,
        userConfirmed: true,
      );

      expect(saved, isFalse);
      final submitSaved = await service.saveCorrection(
        rawHeardText: 'submit',
        intent: const VoiceIntent(
          type: VoiceIntentType.submit,
          confidence: 1,
          isRisky: true,
          rawText: 'submit',
          normalizedText: 'submit',
          source: 'test',
        ),
        screenContext: VoiceScreenContext.quiz,
        userConfirmed: true,
      );
      final finalSubmitSaved = await service.saveCorrection(
        rawHeardText: 'final submit',
        intent: const VoiceIntent(
          type: VoiceIntentType.finalSubmit,
          confidence: 1,
          isRisky: true,
          rawText: 'final submit',
          normalizedText: 'final submit',
          source: 'test',
        ),
        screenContext: VoiceScreenContext.review,
        userConfirmed: true,
      );

      expect(submitSaved, isFalse);
      expect(finalSubmitSaved, isFalse);
      expect(
        await service.findCorrection('reset answers', VoiceScreenContext.quiz),
        isNull,
      );
    });

    test('does not save conflicting C-like option corrections', () async {
      SharedPreferences.setMockInitialValues({});
      const service = VoiceLearningService(userOrDeviceId: 'voice-test');

      for (final phrase in const [
        'option si',
        'option see',
        'option sea',
        'select see',
        'sylhetse',
        'sylhet see',
        'sylhet c',
        'sylet see',
        'syletse',
        'syllet see',
        'sylnetse',
        'sylentse',
        'galaxy',
        'answer sea',
      ]) {
        final saved = await service.saveCorrection(
          rawHeardText: phrase,
          intent: VoiceIntent(
            type: VoiceIntentType.optionA,
            value: 'a',
            confidence: 1,
            isRisky: false,
            rawText: phrase,
            normalizedText: VoiceTextNormalizer.normalize(phrase),
            source: 'test_stale_correction',
          ),
          screenContext: VoiceScreenContext.quiz,
          userConfirmed: true,
        );

        expect(saved, isFalse, reason: phrase);
      }
      for (final targetType in const [
        VoiceIntentType.optionA,
        VoiceIntentType.optionB,
        VoiceIntentType.optionD,
      ]) {
        for (final phrase in const ['sylhetse', 'galaxy']) {
          final saved = await service.saveCorrection(
            rawHeardText: phrase,
            intent: VoiceIntent(
              type: targetType,
              value: switch (targetType) {
                VoiceIntentType.optionA => 'a',
                VoiceIntentType.optionB => 'b',
                VoiceIntentType.optionD => 'd',
                _ => null,
              },
              confidence: 1,
              isRisky: false,
              rawText: phrase,
              normalizedText: VoiceTextNormalizer.normalize(phrase),
              source: 'test_stale_correction',
            ),
            screenContext: VoiceScreenContext.quiz,
            userConfirmed: true,
          );

          expect(saved, isFalse, reason: '$phrase ${targetType.name}');
        }
      }
      expect(await service.getCorrections(VoiceScreenContext.quiz), isEmpty);
    });

    test('deletes stored C-like corrections that point to option A', () async {
      const service = VoiceLearningService(userOrDeviceId: 'voice-test');
      final now = DateTime.utc(2026, 1, 1).toIso8601String();
      SharedPreferences.setMockInitialValues({
        service.storageKey: [
          jsonEncode({
            'rawHeardText': 'option si',
            'normalizedText': 'option si',
            'intentType': VoiceIntentType.optionA.name,
            'value': 'a',
            'number': null,
            'screenContext': VoiceScreenContext.quiz.name,
            'createdAt': now,
            'lastUsedAt': now,
            'useCount': 0,
            'isRisky': false,
          }),
          jsonEncode({
            'rawHeardText': 'answer sea',
            'normalizedText': 'answer sea',
            'intentType': VoiceIntentType.optionA.name,
            'value': 'a',
            'number': null,
            'screenContext': VoiceScreenContext.quiz.name,
            'createdAt': now,
            'lastUsedAt': now,
            'useCount': 0,
            'isRisky': false,
          }),
          jsonEncode({
            'rawHeardText': 'syllet see',
            'normalizedText': 'syllet see',
            'intentType': VoiceIntentType.optionA.name,
            'value': 'a',
            'number': null,
            'screenContext': VoiceScreenContext.quiz.name,
            'createdAt': now,
            'lastUsedAt': now,
            'useCount': 0,
            'isRisky': false,
          }),
          jsonEncode({
            'rawHeardText': 'sylhetse',
            'normalizedText': 'sylhetse',
            'intentType': VoiceIntentType.optionA.name,
            'value': 'a',
            'number': null,
            'screenContext': VoiceScreenContext.quiz.name,
            'createdAt': now,
            'lastUsedAt': now,
            'useCount': 0,
            'isRisky': false,
          }),
          jsonEncode({
            'rawHeardText': 'sylnetse',
            'normalizedText': 'sylnetse',
            'intentType': VoiceIntentType.optionA.name,
            'value': 'a',
            'number': null,
            'screenContext': VoiceScreenContext.quiz.name,
            'createdAt': now,
            'lastUsedAt': now,
            'useCount': 0,
            'isRisky': false,
          }),
          jsonEncode({
            'rawHeardText': 'galaxy',
            'normalizedText': 'galaxy',
            'intentType': VoiceIntentType.optionB.name,
            'value': 'b',
            'number': null,
            'screenContext': VoiceScreenContext.quiz.name,
            'createdAt': now,
            'lastUsedAt': now,
            'useCount': 0,
            'isRisky': false,
          }),
        ],
      });

      expect(
        await service.getParserCorrections(VoiceScreenContext.quiz),
        isEmpty,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(service.storageKey), isEmpty);
    });

    test('processor applies safe learned corrections screen-aware', () async {
      SharedPreferences.setMockInitialValues({});
      const service = VoiceLearningService(userOrDeviceId: 'voice-test');
      await service.saveCorrection(
        rawHeardText: 'open notes',
        intent: const VoiceIntent(
          type: VoiceIntentType.explain,
          confidence: 1,
          isRisky: false,
          rawText: 'explain',
          normalizedText: 'explain',
          source: 'test',
        ),
        screenContext: VoiceScreenContext.quiz,
        userConfirmed: true,
      );

      final quizResult = await VoiceCommandProcessor(learningService: service)
          .process(
            screen: QuizVoiceScreen.mcq,
            heardText: 'open notes',
            sensitivity: CommandSensitivity.normal,
          );
      final reviewResult = await VoiceCommandProcessor(learningService: service)
          .process(
            screen: QuizVoiceScreen.examReview,
            heardText: 'open notes',
            sensitivity: CommandSensitivity.normal,
          );

      expect(quizResult.shouldExecute, isTrue);
      expect(quizResult.intent, legacy.VoiceIntent.explain);
      expect(quizResult.analytics['source'], 'correction');
      expect(reviewResult.shouldExecute, isFalse);
    });

    test(
      'yes saves suggestion and next time executes learned option C',
      () async {
        SharedPreferences.setMockInitialValues({});
        const service = VoiceLearningService(userOrDeviceId: 'voice-test');
        final processor = VoiceCommandProcessor(learningService: service);

        final suggestion = await processor.process(
          screen: QuizVoiceScreen.mcq,
          heardText: 'galaxy',
          sensitivity: CommandSensitivity.normal,
        );

        expect(suggestion.shouldExecute, isFalse);
        expect(suggestion.intent, legacy.VoiceIntent.optionC);
        expect(suggestion.feedback, contains('Did you mean'));
        expect(suggestion.analytics['parserSource'], 'suggestion');

        final accepted = await processor.process(
          screen: QuizVoiceScreen.mcq,
          heardText: 'yes',
          sensitivity: CommandSensitivity.normal,
        );

        expect(accepted.shouldExecute, isTrue);
        expect(accepted.intent, legacy.VoiceIntent.optionC);
        expect(accepted.analytics['correctionSaved'], isTrue);

        final learned = await processor.process(
          screen: QuizVoiceScreen.mcq,
          heardText: 'galaxy',
          sensitivity: CommandSensitivity.normal,
        );

        expect(learned.shouldExecute, isTrue);
        expect(learned.intent, legacy.VoiceIntent.optionC);
        expect(learned.analytics['parserSource'], 'learned_correction');
        expect(learned.analytics['source'], 'correction');
      },
    );
  });

  group('cloud fallback guard', () {
    test('processor executes review strong submit immediately', () async {
      final result = await VoiceCommandProcessor().process(
        screen: QuizVoiceScreen.examReview,
        heardText: 'final submit',
        sensitivity: CommandSensitivity.normal,
      );

      expect(result.shouldExecute, isTrue);
      expect(result.intent, legacy.VoiceIntent.submit);
      expect(result.feedback, isNull);
      expect(result.analytics['confirmationShown'], isFalse);
    });

    test('processor asks yes/no for fuzzy review submit', () async {
      final result = await VoiceCommandProcessor().process(
        screen: QuizVoiceScreen.examReview,
        heardText: 'finnal submmit',
        sensitivity: CommandSensitivity.normal,
      );

      expect(result.shouldExecute, isFalse);
      expect(result.feedback, isNotNull);
      expect(result.analytics['confirmationShown'], isTrue);
    });

    test('cloud disabled means no upload', () async {
      final tempDir = await Directory.systemTemp.createTemp('voice_test_');
      final audioFile = File('${tempDir.path}/sample.wav');
      await audioFile.writeAsBytes(<int>[0, 1, 2, 3]);
      final cloudService = _CountingCloudSpeechTranscriber();

      try {
        final result = await VoiceCommandProcessor().process(
          screen: QuizVoiceScreen.mcq,
          heardText: 'unknown local command',
          sensitivity: CommandSensitivity.flexible,
          cloudFallbackEnabled: false,
          cloudSpeechService: cloudService,
          fallbackAudioFile: audioFile,
        );

        expect(cloudService.calls, 0);
        expect(result.analytics['fallbackUsed'], isFalse);
        expect(
          result.feedback,
          "I didn't understand. Try saying Option A, Option B, Option C, Next question, or Go back.",
        );
      } finally {
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
        if (await tempDir.exists()) {
          await tempDir.delete();
        }
      }
    });

    test('cloud risky transcript asks confirmation', () async {
      final tempDir = await Directory.systemTemp.createTemp('voice_test_');
      final audioFile = File('${tempDir.path}/sample.wav');
      await audioFile.writeAsBytes(<int>[0, 1, 2, 3]);

      try {
        final result = await VoiceCommandProcessor().process(
          screen: QuizVoiceScreen.examReview,
          heardText: '',
          sensitivity: CommandSensitivity.flexible,
          cloudFallbackEnabled: true,
          cloudSpeechService: _SubmitCloudSpeechTranscriber(),
          fallbackAudioFile: audioFile,
        );

        expect(result.shouldExecute, isFalse);
        expect(
          result.intent,
          isIn(<legacy.VoiceIntent>[
            legacy.VoiceIntent.submit,
            legacy.VoiceIntent.confirmSubmit,
          ]),
        );
        expect(result.analytics['fallbackUsed'], isTrue);
        expect(result.analytics['riskyCommandBlocked'], isTrue);
      } finally {
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
        if (await tempDir.exists()) {
          await tempDir.delete();
        }
      }
    });
  });
}

class _CountingCloudSpeechTranscriber implements CloudSpeechTranscriber {
  int calls = 0;

  @override
  Future<SpeechRecognitionResult> transcribeCommand({
    required File audioFile,
    required String locale,
    required VoiceScreenContext screenContext,
    required List<String> availableCommands,
  }) async {
    calls++;
    return SpeechRecognitionResult.success(
      transcript: 'option a',
      confidence: 1,
      provider: 'test',
      language: locale,
      durationMs: 1,
    );
  }
}

class _SubmitCloudSpeechTranscriber implements CloudSpeechTranscriber {
  @override
  Future<SpeechRecognitionResult> transcribeCommand({
    required File audioFile,
    required String locale,
    required VoiceScreenContext screenContext,
    required List<String> availableCommands,
  }) async {
    return SpeechRecognitionResult.success(
      transcript: 'final submit',
      confidence: 1,
      provider: 'test',
      language: locale,
      durationMs: 1,
    );
  }
}
