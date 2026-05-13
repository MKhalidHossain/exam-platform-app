import 'dart:io';

import '../controllers/quiz_voice_controller.dart';
import '../services/voice_assistant_settings_service.dart';
import '../voice/core/voice_command_context.dart' as core_context;
import '../voice/core/voice_command_result.dart' as core_result;
import '../voice/core/voice_intent.dart' as core_intent;
import '../voice/parsing/voice_command_parser.dart' as core_parser;
import '../voice/parsing/voice_text_normalizer.dart';
import '../voice/recognition/cloud_speech_service.dart';
import 'quiz_voice_intent_parser.dart';

class VoiceCommandDecision {
  final VoiceParseResult parseResult;
  final VoiceIntent? intent;
  final String? feedback;
  final bool shouldExecute;
  final int? questionNumber;
  final int? requestedQuestionCount;
  final Map<String, dynamic> analytics;

  const VoiceCommandDecision({
    required this.parseResult,
    required this.intent,
    required this.feedback,
    required this.shouldExecute,
    this.questionNumber,
    this.requestedQuestionCount,
    this.analytics = const <String, dynamic>{},
  });
}

class VoiceCommandProcessor {
  _PendingVoiceConfirmation? _pendingConfirmation;

  Future<VoiceCommandDecision> process({
    required QuizVoiceScreen screen,
    required String heardText,
    required CommandSensitivity sensitivity,
    // TODO: Wire this to persisted voice settings when the settings step lands.
    bool cloudFallbackEnabled = false,
    CloudSpeechTranscriber? cloudSpeechService,
    File? fallbackAudioFile,
    String locale = 'en-US',
    List<String> availableCommands = const <String>[],
  }) async {
    final pendingConfirmation = _pendingConfirmation;
    if (pendingConfirmation != null) {
      if (_isYesText(heardText)) {
        _pendingConfirmation = null;
        if (!pendingConfirmation.isRisky &&
            QuizVoiceIntentParser.canLearnCorrection(
              pendingConfirmation.parseResult.intent,
            )) {
          await QuizVoiceIntentParser.rememberCorrection(
            pendingConfirmation.parseResult.heardText,
            pendingConfirmation.parseResult.intent!,
          );
        }
        return _decisionFromParseResult(
          pendingConfirmation.parseResult,
          feedback: null,
          analytics: _voiceAnalytics(
            screen: pendingConfirmation.screen,
            rawText: pendingConfirmation.parseResult.heardText,
            normalizedText: pendingConfirmation.parseResult.normalizedText,
            coreResult: pendingConfirmation.coreResult,
            parseResult: pendingConfirmation.parseResult,
            locale: locale,
            sensitivity: sensitivity,
            source: 'correction',
            fallbackUsed: pendingConfirmation.fallbackUsed,
            confirmationShown: true,
            confirmationAccepted: true,
            confirmationTranscript: heardText,
            decisionName: core_result.VoiceCommandDecision.execute.name,
          ),
        );
      }

      if (_isNoText(heardText)) {
        _pendingConfirmation = null;
        return _decisionFromParseResult(
          pendingConfirmation.parseResult,
          feedback: 'Okay. Please repeat the command.',
          analytics: _voiceAnalytics(
            screen: pendingConfirmation.screen,
            rawText: pendingConfirmation.parseResult.heardText,
            normalizedText: pendingConfirmation.parseResult.normalizedText,
            coreResult: pendingConfirmation.coreResult,
            parseResult: pendingConfirmation.parseResult,
            locale: locale,
            sensitivity: sensitivity,
            source: pendingConfirmation.source,
            fallbackUsed: pendingConfirmation.fallbackUsed,
            confirmationShown: true,
            confirmationRejected: true,
            confirmationTranscript: heardText,
            decisionName: core_result.VoiceCommandDecision.ignored.name,
          ),
        );
      }

      _pendingConfirmation = null;
    }

    var outcome = await _parseWithCoreParser(
      screen: screen,
      heardText: heardText,
      sensitivity: sensitivity,
    );
    var fallbackAttempted = false;
    var fallbackUsed = false;
    String? errorType;

    if (_shouldTryCloudFallback(
      outcome.coreResult,
      cloudFallbackEnabled: cloudFallbackEnabled,
      cloudSpeechService: cloudSpeechService,
      fallbackAudioFile: fallbackAudioFile,
    )) {
      fallbackAttempted = true;
      final cloudOutcome = await _tryCloudFallback(
        screen: screen,
        sensitivity: sensitivity,
        cloudSpeechService: cloudSpeechService!,
        fallbackAudioFile: fallbackAudioFile!,
        locale: locale,
        availableCommands: availableCommands,
      );
      if (cloudOutcome != null) {
        outcome = cloudOutcome;
        fallbackUsed = true;
      } else {
        errorType = 'cloudFallbackFailed';
      }
    }

    var result = outcome.parseResult;
    final feedback = _feedbackForCoreDecision(outcome.coreResult, result);
    final source = outcome.coreResult.intent?.source == 'learned_correction'
        ? 'correction'
        : fallbackUsed
        ? 'cloud'
        : 'native';
    final analytics = _voiceAnalytics(
      screen: screen,
      rawText: result.heardText,
      normalizedText: result.normalizedText,
      coreResult: outcome.coreResult,
      parseResult: result,
      locale: locale,
      sensitivity: sensitivity,
      source: source,
      fallbackAttempted: fallbackAttempted,
      fallbackUsed: fallbackUsed,
      confirmationShown:
          outcome.coreResult.decision ==
          core_result.VoiceCommandDecision.askConfirmation,
      riskyCommandBlocked:
          outcome.coreResult.intent?.isRisky == true &&
          outcome.coreResult.decision !=
              core_result.VoiceCommandDecision.execute,
      errorType: errorType ?? _errorTypeFor(outcome.coreResult.decision),
    );

    if (feedback != null &&
        outcome.coreResult.decision ==
            core_result.VoiceCommandDecision.askConfirmation &&
        outcome.coreResult.intent?.isRisky != true &&
        QuizVoiceIntentParser.canLearnCorrection(result.intent) &&
        feedback.startsWith('Did you mean')) {
      _pendingConfirmation = _PendingVoiceConfirmation(
        parseResult: result,
        coreResult: outcome.coreResult,
        screen: screen,
        isRisky: false,
        fallbackUsed: fallbackUsed,
        source: source,
      );
    }

    return _decisionFromParseResult(
      result,
      feedback: feedback,
      analytics: analytics,
    );
  }

  VoiceCommandDecision _decisionFromParseResult(
    VoiceParseResult result, {
    required String? feedback,
    Map<String, dynamic> analytics = const <String, dynamic>{},
  }) {
    return VoiceCommandDecision(
      parseResult: result,
      intent: result.intent,
      feedback: feedback,
      shouldExecute: feedback == null,
      questionNumber: QuizVoiceIntentParser.questionNumberFrom(
        result.normalizedText,
      ),
      requestedQuestionCount: QuizVoiceIntentParser.requestedQuestionCountFrom(
        result.normalizedText,
      ),
      analytics: analytics,
    );
  }

  void clearPendingCorrection() {
    _pendingConfirmation = null;
  }

  bool _isYesText(String text) =>
      QuizVoiceIntentParser.isConfirmationText(text);

  bool _isNoText(String text) {
    final normalizedText = VoiceTextNormalizer.normalize(text);
    return const {
      'no',
      'nope',
      'nah',
      'cancel',
      'wrong',
      'incorrect',
      'not correct',
      'do not',
      'dont',
      'don t',
    }.contains(normalizedText);
  }

  bool _shouldTryCloudFallback(
    core_result.VoiceCommandResult result, {
    required bool cloudFallbackEnabled,
    required CloudSpeechTranscriber? cloudSpeechService,
    required File? fallbackAudioFile,
  }) {
    if (!cloudFallbackEnabled) return false;
    if (cloudSpeechService == null || fallbackAudioFile == null) return false;
    if (!fallbackAudioFile.existsSync()) return false;

    return result.decision ==
            core_result.VoiceCommandDecision.fallbackToCloud ||
        result.decision == core_result.VoiceCommandDecision.notUnderstood;
  }

  Future<_CoreVoiceParseOutcome?> _tryCloudFallback({
    required QuizVoiceScreen screen,
    required CommandSensitivity sensitivity,
    required CloudSpeechTranscriber cloudSpeechService,
    required File fallbackAudioFile,
    required String locale,
    required List<String> availableCommands,
  }) async {
    final cloudResult = await cloudSpeechService.transcribeCommand(
      audioFile: fallbackAudioFile,
      locale: locale,
      screenContext: _coreContextFor(screen),
      availableCommands: availableCommands,
    );
    if (!cloudResult.isSuccess || cloudResult.transcript.trim().isEmpty) {
      return null;
    }

    return _parseWithCoreParser(
      screen: screen,
      heardText: cloudResult.transcript,
      sensitivity: sensitivity,
    );
  }

  Future<_CoreVoiceParseOutcome> _parseWithCoreParser({
    required QuizVoiceScreen screen,
    required String heardText,
    required CommandSensitivity sensitivity,
  }) async {
    final normalizedText = VoiceTextNormalizer.normalize(heardText);
    final decision = core_parser.VoiceCommandParser.parse(
      rawText: heardText,
      context: _coreContextFor(screen),
      sensitivity: _coreSensitivityFor(sensitivity),
    );
    final coreIntent = decision.intent;
    final legacyIntent = coreIntent == null
        ? null
        : _legacyIntentFor(coreIntent.type);

    return _CoreVoiceParseOutcome(
      coreResult: decision,
      parseResult: VoiceParseResult(
        intent: legacyIntent,
        confidence: coreIntent?.confidence ?? 0,
        normalizedText: coreIntent?.normalizedText ?? normalizedText,
        heardText: heardText,
      ),
    );
  }

  String? _feedbackForCoreDecision(
    core_result.VoiceCommandResult coreDecision,
    VoiceParseResult result,
  ) {
    return switch (coreDecision.decision) {
      core_result.VoiceCommandDecision.execute => null,
      core_result.VoiceCommandDecision.askConfirmation =>
        coreDecision.message ??
            (result.intent == null
                ? 'Did you mean that command?'
                : 'Did you mean ${QuizVoiceIntentParser.commandLabelFor(result.intent!)}?'),
      core_result.VoiceCommandDecision.fallbackToCloud ||
      core_result.VoiceCommandDecision.notUnderstood =>
        'I did not understand. Say help to hear commands.',
      core_result.VoiceCommandDecision.ignored => null,
    };
  }

  Map<String, dynamic> _voiceAnalytics({
    required QuizVoiceScreen screen,
    required String rawText,
    required String normalizedText,
    required core_result.VoiceCommandResult coreResult,
    required VoiceParseResult parseResult,
    required String locale,
    required CommandSensitivity sensitivity,
    required String source,
    bool fallbackAttempted = false,
    bool fallbackUsed = false,
    bool confirmationShown = false,
    bool confirmationAccepted = false,
    bool confirmationRejected = false,
    bool riskyCommandBlocked = false,
    String? confirmationTranscript,
    String? decisionName,
    String? errorType,
  }) {
    final coreIntent = coreResult.intent;
    return <String, dynamic>{
      'screenContext': _coreContextFor(screen).name,
      'rawTranscript': rawText,
      'normalizedTranscript': normalizedText,
      'detectedIntent': coreIntent?.type.name ?? parseResult.intent?.name,
      'confidence': coreIntent?.confidence ?? parseResult.confidence,
      'source': source,
      'parserSource': coreIntent?.source,
      'decision': decisionName ?? coreResult.decision.name,
      'fallbackAttempted': fallbackAttempted,
      'fallbackUsed': fallbackUsed,
      'confirmationShown': confirmationShown,
      'confirmationAccepted': confirmationAccepted,
      'confirmationRejected': confirmationRejected,
      'riskyCommandBlocked': riskyCommandBlocked,
      'selectedLocale': locale,
      'sensitivity': sensitivity.name,
      'confirmationTranscript': confirmationTranscript,
      'errorType': errorType,
    };
  }

  String? _errorTypeFor(core_result.VoiceCommandDecision decision) {
    return switch (decision) {
      core_result.VoiceCommandDecision.fallbackToCloud => 'fallbackToCloud',
      core_result.VoiceCommandDecision.notUnderstood => 'notUnderstood',
      core_result.VoiceCommandDecision.ignored => 'ignored',
      core_result.VoiceCommandDecision.execute ||
      core_result.VoiceCommandDecision.askConfirmation => null,
    };
  }

  core_context.VoiceScreenContext _coreContextFor(QuizVoiceScreen screen) {
    return switch (screen) {
      QuizVoiceScreen.mcq => core_context.VoiceScreenContext.quiz,
      QuizVoiceScreen.examReview => core_context.VoiceScreenContext.review,
      QuizVoiceScreen.quizSettings => core_context.VoiceScreenContext.settings,
      QuizVoiceScreen.examSession => core_context.VoiceScreenContext.session,
      QuizVoiceScreen.examLoading => core_context.VoiceScreenContext.loading,
      QuizVoiceScreen.none => core_context.VoiceScreenContext.global,
    };
  }

  core_parser.VoiceCommandSensitivity _coreSensitivityFor(
    CommandSensitivity sensitivity,
  ) {
    return switch (sensitivity) {
      CommandSensitivity.strict => core_parser.VoiceCommandSensitivity.strict,
      CommandSensitivity.normal => core_parser.VoiceCommandSensitivity.normal,
      CommandSensitivity.flexible =>
        core_parser.VoiceCommandSensitivity.flexible,
    };
  }

  VoiceIntent? _legacyIntentFor(core_intent.VoiceIntentType type) {
    return switch (type) {
      core_intent.VoiceIntentType.optionA => VoiceIntent.optionA,
      core_intent.VoiceIntentType.optionB => VoiceIntent.optionB,
      core_intent.VoiceIntentType.optionC => VoiceIntent.optionC,
      core_intent.VoiceIntentType.optionD => VoiceIntent.optionD,
      core_intent.VoiceIntentType.next ||
      core_intent.VoiceIntentType.skip => VoiceIntent.next,
      core_intent.VoiceIntentType.previous => VoiceIntent.back,
      core_intent.VoiceIntentType.repeat ||
      core_intent.VoiceIntentType.readQuestion ||
      core_intent.VoiceIntentType.readSummary => VoiceIntent.repeat,
      core_intent.VoiceIntentType.flag ||
      core_intent.VoiceIntentType.bookmark ||
      core_intent.VoiceIntentType.flagged => VoiceIntent.flag,
      core_intent.VoiceIntentType.explain => VoiceIntent.explain,
      core_intent.VoiceIntentType.review => VoiceIntent.review,
      core_intent.VoiceIntentType.unanswered => VoiceIntent.unanswered,
      core_intent.VoiceIntentType.questionNumber => VoiceIntent.questionNumber,
      core_intent.VoiceIntentType.submit => VoiceIntent.submit,
      core_intent.VoiceIntentType.confirmSubmit => VoiceIntent.confirmSubmit,
      core_intent.VoiceIntentType.startQuiz => VoiceIntent.startQuiz,
      core_intent.VoiceIntentType.startTest => VoiceIntent.startTest,
      core_intent.VoiceIntentType.timedModeOn => VoiceIntent.timedModeOn,
      core_intent.VoiceIntentType.timedModeOff => VoiceIntent.timedModeOff,
      core_intent.VoiceIntentType.maxQuestions => VoiceIntent.maxQuestions,
      core_intent.VoiceIntentType.minQuestions => VoiceIntent.minQuestions,
      core_intent.VoiceIntentType.increaseQuestions =>
        VoiceIntent.increaseQuestions,
      core_intent.VoiceIntentType.decreaseQuestions =>
        VoiceIntent.decreaseQuestions,
      core_intent.VoiceIntentType.setQuestionCount =>
        VoiceIntent.setQuestionCount,
      core_intent.VoiceIntentType.status => VoiceIntent.status,
      core_intent.VoiceIntentType.retry => VoiceIntent.retry,
      core_intent.VoiceIntentType.cancel ||
      core_intent.VoiceIntentType.cancelSubmit => VoiceIntent.cancel,
      core_intent.VoiceIntentType.back => VoiceIntent.back,
      core_intent.VoiceIntentType.help => VoiceIntent.help,
      core_intent.VoiceIntentType.stopVoice => VoiceIntent.stopVoice,
      core_intent.VoiceIntentType.pauseAssistant => VoiceIntent.pauseAssistant,
      core_intent.VoiceIntentType.resumeAssistant =>
        VoiceIntent.resumeAssistant,
      core_intent.VoiceIntentType.trueAnswer ||
      core_intent.VoiceIntentType.falseAnswer ||
      core_intent.VoiceIntentType.finalSubmit ||
      core_intent.VoiceIntentType.exitQuiz ||
      core_intent.VoiceIntentType.resetAnswers ||
      core_intent.VoiceIntentType.clearAnswer ||
      core_intent.VoiceIntentType.finishExam ||
      core_intent.VoiceIntentType.delete ||
      core_intent.VoiceIntentType.restartTest => null,
    };
  }
}

class _CoreVoiceParseOutcome {
  final core_result.VoiceCommandResult coreResult;
  final VoiceParseResult parseResult;

  const _CoreVoiceParseOutcome({
    required this.coreResult,
    required this.parseResult,
  });
}

class _PendingVoiceConfirmation {
  final VoiceParseResult parseResult;
  final core_result.VoiceCommandResult coreResult;
  final QuizVoiceScreen screen;
  final bool isRisky;
  final bool fallbackUsed;
  final String source;

  const _PendingVoiceConfirmation({
    required this.parseResult,
    required this.coreResult,
    required this.screen,
    required this.isRisky,
    required this.fallbackUsed,
    required this.source,
  });
}
