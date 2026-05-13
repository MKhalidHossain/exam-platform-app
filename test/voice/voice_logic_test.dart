import 'dart:io';

import 'package:ej_flutter/controllers/quiz_voice_controller.dart';
import 'package:ej_flutter/services/voice_assistant_settings_service.dart';
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
      expect(VoiceTextNormalizer.normalize('nex question'), 'next question');
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
      expect(
        await service.findCorrection('reset answers', VoiceScreenContext.quiz),
        isNull,
      );
    });
  });

  group('cloud fallback guard', () {
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
