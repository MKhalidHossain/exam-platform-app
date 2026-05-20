import 'package:ej_flutter/controllers/quiz_voice_controller.dart';
import 'package:ej_flutter/services/voice_assistant_settings_service.dart';
import 'package:ej_flutter/utils/quiz_voice_intent_parser.dart';
import 'package:ej_flutter/utils/voice_submit_confirmation_guard.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('speech mistakes parse as answer options', () async {
    expect(
      (await QuizVoiceIntentParser.parse(QuizVoiceScreen.mcq, 'won')).intent,
      VoiceIntent.optionA,
    );
    expect(
      (await QuizVoiceIntentParser.parse(QuizVoiceScreen.mcq, 'too')).intent,
      VoiceIntent.optionB,
    );
    expect(
      (await QuizVoiceIntentParser.parse(QuizVoiceScreen.mcq, 'tree')).intent,
      VoiceIntent.optionC,
    );
    expect(
      (await QuizVoiceIntentParser.parse(QuizVoiceScreen.mcq, 'for')).intent,
      VoiceIntent.optionD,
    );
  });

  test('letter answer commands parse only on MCQ screens', () async {
    final cases = <String, VoiceIntent>{
      'a': VoiceIntent.optionA,
      'ay': VoiceIntent.optionA,
      'b': VoiceIntent.optionB,
      'bee': VoiceIntent.optionB,
      'c': VoiceIntent.optionC,
      'see': VoiceIntent.optionC,
      'd': VoiceIntent.optionD,
      'dee': VoiceIntent.optionD,
      'option a': VoiceIntent.optionA,
      'answer b': VoiceIntent.optionB,
      'letter c': VoiceIntent.optionC,
      'select d': VoiceIntent.optionD,
      'one': VoiceIntent.optionA,
      'first': VoiceIntent.optionA,
      'two': VoiceIntent.optionB,
      'second': VoiceIntent.optionB,
      'three': VoiceIntent.optionC,
      'third': VoiceIntent.optionC,
      'four': VoiceIntent.optionD,
      'fourth': VoiceIntent.optionD,
    };

    for (final entry in cases.entries) {
      expect(
        (await QuizVoiceIntentParser.parse(
          QuizVoiceScreen.mcq,
          entry.key,
        )).intent,
        entry.value,
        reason: entry.key,
      );
    }

    for (final screen in [
      QuizVoiceScreen.quizSettings,
      QuizVoiceScreen.examSession,
      QuizVoiceScreen.examLoading,
      QuizVoiceScreen.examReview,
    ]) {
      expect(
        (await QuizVoiceIntentParser.parse(screen, 'a')).intent,
        isNot(VoiceIntent.optionA),
        reason: screen.name,
      );
      expect(
        (await QuizVoiceIntentParser.parse(screen, 'b')).intent,
        isNot(VoiceIntent.optionB),
        reason: screen.name,
      );
      expect(
        (await QuizVoiceIntentParser.parse(screen, 'c')).intent,
        isNot(VoiceIntent.optionC),
        reason: screen.name,
      );
      expect(
        (await QuizVoiceIntentParser.parse(screen, 'd')).intent,
        isNot(VoiceIntent.optionD),
        reason: screen.name,
      );
    }
  });

  test('common navigation and repeat phrases parse correctly', () async {
    expect(
      (await QuizVoiceIntentParser.parse(QuizVoiceScreen.mcq, 'go nex')).intent,
      VoiceIntent.next,
    );
    expect(
      (await QuizVoiceIntentParser.parse(
        QuizVoiceScreen.mcq,
        'read again',
      )).intent,
      VoiceIntent.repeat,
    );
  });

  test('low confidence command does not execute', () async {
    final result = await QuizVoiceIntentParser.parse(
      QuizVoiceScreen.mcq,
      'nexr',
    );

    expect(result.intent, VoiceIntent.next);
    expect(result.confidence, lessThan(0.78));
    expect(QuizVoiceIntentParser.shouldExecute(result), isFalse);
  });

  test('submit requires high confidence', () async {
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
    expect(QuizVoiceIntentParser.shouldExecute(exactSubmit), isTrue);
  });

  test('confirm submit only works after submit is pending', () {
    final guard = VoiceSubmitConfirmationGuard();

    expect(guard.confirmSubmit(), isFalse);
    guard.requestSubmit();
    expect(guard.isPending, isTrue);
    expect(guard.confirmSubmit(), isTrue);
    expect(guard.isPending, isFalse);
    expect(guard.confirmSubmit(), isFalse);
  });

  test('voice next opens review only at the last question', () {
    final controller = QuizVoiceController();

    expect(
      controller.shouldOpenReviewForVoiceNext(
        currentIndex: 0,
        questionCount: 2,
      ),
      isFalse,
    );
    expect(
      controller.shouldOpenReviewForVoiceNext(
        currentIndex: 1,
        questionCount: 2,
      ),
      isTrue,
    );
    expect(
      controller.shouldOpenReviewForVoiceNext(
        currentIndex: 0,
        questionCount: 0,
      ),
      isTrue,
    );
  });

  test('speakOnce skips duplicate automatic reads', () {
    final controller = QuizVoiceController();

    expect(
      controller.speakOnce(
        key: 'question_exam_0',
        text: 'Question one',
        screen: QuizVoiceScreen.mcq,
      ),
      isTrue,
    );
    expect(
      controller.speakOnce(
        key: 'question_exam_0',
        text: 'Question one',
        screen: QuizVoiceScreen.mcq,
      ),
      isFalse,
    );
  });

  test('speakOnce allows forced repeat', () {
    final controller = QuizVoiceController();

    expect(
      controller.speakOnce(
        key: 'question_exam_0',
        text: 'Question one',
        screen: QuizVoiceScreen.mcq,
      ),
      isTrue,
    );
    expect(
      controller.speakOnce(
        key: 'question_exam_0',
        text: 'Question one',
        force: true,
        screen: QuizVoiceScreen.mcq,
      ),
      isTrue,
    );
  });

  test('old screen tokens cannot run recovery', () async {
    final controller = QuizVoiceController();
    var oldRecoveryCount = 0;
    var currentRecoveryCount = 0;

    controller.activateScreen(QuizVoiceScreen.quizSettings, 'old-token');
    controller.bindScreen(
      screen: QuizVoiceScreen.quizSettings,
      screenToken: 'old-token',
      onRecoverListening: () async {
        oldRecoveryCount++;
      },
    );
    controller.activateScreen(QuizVoiceScreen.mcq, 'current-token');
    controller.bindScreen(
      screen: QuizVoiceScreen.mcq,
      screenToken: 'current-token',
      onRecoverListening: () async {
        currentRecoveryCount++;
      },
    );
    controller.setVoiceEnabled(true, screen: QuizVoiceScreen.mcq);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    currentRecoveryCount = 0;

    controller.requestRecovery(force: true, screenToken: 'old-token');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(oldRecoveryCount, 0);

    controller.requestRecovery(force: true, screenToken: 'current-token');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(currentRecoveryCount, 1);
  });

  testWidgets('lifecycle resume restarts listening', (tester) async {
    final controller = QuizVoiceController();
    var recoveryCount = 0;

    controller.onInit();

    controller.bindScreen(
      screen: QuizVoiceScreen.mcq,
      onRecoverListening: () async {
        recoveryCount++;
      },
    );
    controller.setVoiceEnabled(true, screen: QuizVoiceScreen.mcq);
    await tester.pump(const Duration(milliseconds: 20));

    recoveryCount = 0;
    controller.setVoiceState(VoiceState.paused, screen: QuizVoiceScreen.mcq);
    controller.onScreenActivated(QuizVoiceScreen.mcq.name);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 700));

    expect(recoveryCount, greaterThan(0));
    controller.onClose();
  });

  testWidgets('lifecycle background hard stops voice and blocks recovery', (
    tester,
  ) async {
    final controller = QuizVoiceController();
    var deactivateCount = 0;
    var recoveryCount = 0;

    controller.onInit();
    controller.activateScreen(
      QuizVoiceScreen.mcq,
      'current-token',
      onDeactivate: () async {
        deactivateCount++;
      },
    );
    controller.bindScreen(
      screen: QuizVoiceScreen.mcq,
      screenToken: 'current-token',
      onRecoverListening: () async {
        recoveryCount++;
      },
    );
    controller.setVoiceEnabled(true, screen: QuizVoiceScreen.mcq);
    await tester.pump(const Duration(milliseconds: 20));
    recoveryCount = 0;

    controller.setVoiceState(VoiceState.listening, screen: QuizVoiceScreen.mcq);
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();

    expect(deactivateCount, 1);
    expect(controller.currentStateValue, VoiceState.paused);

    controller.requestRecovery(force: true, screenToken: 'current-token');
    await tester.pump(const Duration(milliseconds: 700));
    expect(recoveryCount, 0);

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 700));
    expect(recoveryCount, greaterThan(0));

    controller.onClose();
  });

  test('strict sensitivity keeps borderline command from executing', () async {
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
  });
}
