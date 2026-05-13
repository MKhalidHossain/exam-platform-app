import 'package:ej_flutter/voice/core/voice_command_context.dart';
import 'package:ej_flutter/voice/core/voice_intent.dart';
import 'package:ej_flutter/voice/learning/voice_learning_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VoiceLearningService', () {
    test('saves confirmed safe corrections per device namespace', () async {
      final firstDevice = VoiceLearningService(userOrDeviceId: 'device-a');
      final secondDevice = VoiceLearningService(userOrDeviceId: 'device-b');
      final saved = await firstDevice.saveCorrection(
        rawHeardText: 'reed question',
        intent: const VoiceIntent(
          type: VoiceIntentType.readQuestion,
          confidence: 0.7,
          isRisky: false,
          rawText: 'reed question',
          normalizedText: 'reed question',
          source: 'test',
        ),
        screenContext: VoiceScreenContext.quiz,
        userConfirmed: true,
      );

      expect(saved, isTrue);
      expect(
        await firstDevice.findCorrection(
          'reed question',
          VoiceScreenContext.quiz,
        ),
        isNotNull,
      );
      expect(
        await secondDevice.findCorrection(
          'reed question',
          VoiceScreenContext.quiz,
        ),
        isNull,
      );
    });

    test('does not save unconfirmed corrections', () async {
      final service = VoiceLearningService();
      final saved = await service.saveCorrection(
        rawHeardText: 'reed question',
        intent: const VoiceIntent(
          type: VoiceIntentType.readQuestion,
          confidence: 0.7,
          isRisky: false,
          rawText: 'reed question',
          normalizedText: 'reed question',
          source: 'test',
        ),
        screenContext: VoiceScreenContext.quiz,
        userConfirmed: false,
      );

      expect(saved, isFalse);
      expect(await service.getCorrections(VoiceScreenContext.quiz), isEmpty);
    });

    test('does not auto-learn risky commands', () async {
      final service = VoiceLearningService();
      final saved = await service.saveCorrection(
        rawHeardText: 'submt quiz',
        intent: const VoiceIntent(
          type: VoiceIntentType.submit,
          confidence: 0.7,
          isRisky: true,
          rawText: 'submt quiz',
          normalizedText: 'submt quiz',
          source: 'test',
        ),
        screenContext: VoiceScreenContext.quiz,
        userConfirmed: true,
      );

      expect(saved, isFalse);
      expect(await service.getCorrections(VoiceScreenContext.quiz), isEmpty);
    });

    test('findCorrection is screen-aware and updates usage metadata', () async {
      final service = VoiceLearningService();
      await service.saveCorrection(
        rawHeardText: 'reed question',
        intent: const VoiceIntent(
          type: VoiceIntentType.readQuestion,
          confidence: 0.7,
          isRisky: false,
          rawText: 'reed question',
          normalizedText: 'reed question',
          source: 'test',
        ),
        screenContext: VoiceScreenContext.quiz,
        userConfirmed: true,
        now: DateTime.utc(2026, 1, 1),
      );

      final reviewMatch = await service.findCorrection(
        'reed question',
        VoiceScreenContext.review,
      );
      final quizMatch = await service.findCorrection(
        'reed question',
        VoiceScreenContext.quiz,
      );

      expect(reviewMatch, isNull);
      expect(quizMatch, isNotNull);
      expect(quizMatch?.useCount, 1);
      expect(
        quizMatch
            ?.toIntent(
              rawText: 'reed question',
              normalizedText: 'reed question',
            )
            .type,
        VoiceIntentType.readQuestion,
      );
    });

    test('caps saved corrections to 200', () async {
      final service = VoiceLearningService();
      for (var index = 0; index < 205; index++) {
        await service.saveCorrection(
          rawHeardText: 'custom phrase $index',
          intent: const VoiceIntent(
            type: VoiceIntentType.next,
            confidence: 0.7,
            isRisky: false,
            rawText: 'custom phrase',
            normalizedText: 'custom phrase',
            source: 'test',
          ),
          screenContext: VoiceScreenContext.quiz,
          userConfirmed: true,
        );
      }

      final corrections = await service.getCorrections(VoiceScreenContext.quiz);
      expect(corrections.length, VoiceLearningService.maxCorrections);
      expect(corrections.first.normalizedText, 'custom phrase 204');
      expect(
        await service.findCorrection(
          'custom phrase 0',
          VoiceScreenContext.quiz,
        ),
        isNull,
      );
    });

    test('clears corrections for the current namespace', () async {
      final service = VoiceLearningService(userOrDeviceId: 'device-a');
      await service.saveCorrection(
        rawHeardText: 'reed question',
        intent: const VoiceIntent(
          type: VoiceIntentType.readQuestion,
          confidence: 0.7,
          isRisky: false,
          rawText: 'reed question',
          normalizedText: 'reed question',
          source: 'test',
        ),
        screenContext: VoiceScreenContext.quiz,
        userConfirmed: true,
      );

      await service.clearCorrections();

      expect(await service.getCorrections(VoiceScreenContext.quiz), isEmpty);
    });
  });
}
