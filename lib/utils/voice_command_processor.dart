import 'dart:io';

import 'package:flutter/foundation.dart';

import '../controllers/quiz_voice_controller.dart';
import '../services/voice_assistant_settings_service.dart';
import '../voice/core/voice_command_context.dart' as core_context;
import '../voice/core/voice_command_result.dart' as core_result;
import '../voice/core/voice_intent.dart' as core_intent;
import '../voice/learning/voice_learning_service.dart';
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
  final VoiceLearningService _learningService;

  VoiceCommandProcessor({VoiceLearningService? learningService})
    : _learningService = learningService ?? const VoiceLearningService();

  Future<VoiceCommandDecision> process({
    required QuizVoiceScreen screen,
    required String heardText,
    required CommandSensitivity sensitivity,
    // TODO: Wire this to persisted voice settings when the settings step lands.
    bool cloudFallbackEnabled = false,
    CloudSpeechTranscriber? cloudSpeechService,
    File? fallbackAudioFile,
    String locale = 'en-US',
    VoiceAccentProfile accentProfile = VoiceAccentProfile.defaultEnglish,
    List<String> availableCommands = const <String>[],
  }) async {
    final pendingConfirmation = _pendingConfirmation;
    if (pendingConfirmation != null) {
      if (_isYesText(heardText)) {
        _pendingConfirmation = null;
        var correctionSaved = false;
        if (!pendingConfirmation.isRisky &&
            QuizVoiceIntentParser.canLearnCorrection(
              pendingConfirmation.parseResult.intent,
            )) {
          final learnedIntent = pendingConfirmation.coreResult.intent;
          if (learnedIntent != null) {
            correctionSaved = await _learningService.saveCorrection(
              rawHeardText: pendingConfirmation.parseResult.heardText,
              intent: learnedIntent,
              screenContext: _coreContextFor(pendingConfirmation.screen),
              userConfirmed: true,
            );
          }
        }
        debugPrint(
          '[Voice][${pendingConfirmation.screen.name}] suggestion accepted raw="${pendingConfirmation.parseResult.heardText}" normalized="${pendingConfirmation.parseResult.normalizedText}" parserSource=${pendingConfirmation.coreResult.intent?.source} confidence=${pendingConfirmation.parseResult.confidence.toStringAsFixed(2)} suggestion=${pendingConfirmation.coreResult.intent?.type.name} correctionSaved=$correctionSaved',
        );
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
            accentProfile: accentProfile,
            source: 'correction',
            fallbackUsed: pendingConfirmation.fallbackUsed,
            confirmationShown: true,
            confirmationAccepted: true,
            confirmationTranscript: heardText,
            decisionName: core_result.VoiceCommandDecision.execute.name,
            suggestion: pendingConfirmation.coreResult.intent?.type.name,
            correctionSaved: correctionSaved,
          ),
        );
      }

      if (_isNoText(heardText)) {
        _pendingConfirmation = null;
        debugPrint(
          '[Voice][${pendingConfirmation.screen.name}] suggestion rejected raw="${pendingConfirmation.parseResult.heardText}" normalized="${pendingConfirmation.parseResult.normalizedText}" parserSource=${pendingConfirmation.coreResult.intent?.source} confidence=${pendingConfirmation.parseResult.confidence.toStringAsFixed(2)} suggestion=${pendingConfirmation.coreResult.intent?.type.name}',
        );
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
            accentProfile: accentProfile,
            source: pendingConfirmation.source,
            fallbackUsed: pendingConfirmation.fallbackUsed,
            confirmationShown: true,
            confirmationRejected: true,
            confirmationTranscript: heardText,
            decisionName: core_result.VoiceCommandDecision.ignored.name,
            suggestion: pendingConfirmation.coreResult.intent?.type.name,
          ),
        );
      }

      _pendingConfirmation = null;
    }

    var outcome = await _parseWithCoreParser(
      screen: screen,
      heardText: heardText,
      sensitivity: sensitivity,
      accentProfile: accentProfile,
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
        accentProfile: accentProfile,
        availableCommands: availableCommands,
      );
      if (cloudOutcome != null) {
        outcome = cloudOutcome;
        if (outcome.coreResult.intent?.isRisky == true) {
          outcome = _confirmationOutcome(
            outcome,
            message: _cloudRiskyConfirmationMessage(screen, outcome),
          );
        }
        fallbackUsed = true;
      } else {
        errorType = 'cloudFallbackFailed';
      }
    }

    var result = outcome.parseResult;
    final feedback = _feedbackForCoreDecision(
      outcome.coreResult,
      result,
      screen,
    );
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
      accentProfile: accentProfile,
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
      suggestion:
          outcome.coreResult.decision ==
              core_result.VoiceCommandDecision.askConfirmation
          ? outcome.coreResult.intent?.type.name
          : null,
    );
    debugPrint(
      '[Voice][${screen.name}] normalized="${result.normalizedText}" parserDecision=${outcome.coreResult.decision.name} source=$source intent=${result.intent?.name} confidence=${result.confidence.toStringAsFixed(2)} fallbackUsed=$fallbackUsed accentProfile=${accentProfile.name}',
    );
    if (result.intent == null) {
      debugPrint(
        '[Voice][${screen.name}] unknown command raw="$heardText" normalized="${result.normalizedText}" accentProfile=${accentProfile.name}',
      );
    }
    if (outcome.coreResult.decision ==
        core_result.VoiceCommandDecision.askConfirmation) {
      debugPrint(
        '[Voice][${screen.name}] suggestion raw="$heardText" normalized="${result.normalizedText}" parserSource=${outcome.coreResult.intent?.source} confidence=${result.confidence.toStringAsFixed(2)} suggestion=${outcome.coreResult.intent?.type.name}',
      );
    }

    if (feedback != null &&
        outcome.coreResult.decision ==
            core_result.VoiceCommandDecision.askConfirmation) {
      if (outcome.coreResult.intent?.isRisky != true &&
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
      } else if (screen == QuizVoiceScreen.examReview &&
          (result.intent == VoiceIntent.submit ||
              result.intent == VoiceIntent.confirmSubmit) &&
          outcome.coreResult.intent?.isRisky == true) {
        _pendingConfirmation = _PendingVoiceConfirmation(
          parseResult: result,
          coreResult: outcome.coreResult,
          screen: screen,
          isRisky: true,
          fallbackUsed: fallbackUsed,
          source: source,
        );
      }
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
    final normalizedText = result.normalizedText;
    return VoiceCommandDecision(
      parseResult: result,
      intent: result.intent,
      feedback: feedback,
      shouldExecute: feedback == null,
      questionNumber: _questionNumberFrom(normalizedText),
      requestedQuestionCount: _requestedQuestionCountFrom(normalizedText),
      analytics: analytics,
    );
  }

  void clearPendingCorrection() {
    _pendingConfirmation = null;
  }

  bool _isYesText(String text) {
    final normalizedText = VoiceTextNormalizer.normalize(text);
    return QuizVoiceIntentParser.isConfirmationText(normalizedText) ||
        const {'that s right', 'thats right'}.contains(normalizedText);
  }

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

  int? _questionNumberFrom(String normalizedText) {
    for (final pattern in const [
      r'\b(?:question|q)\s+(\d+)\b',
      r'\b(?:question\s+number|number)\s+(\d+)\b',
      r'\b(?:go|jump|move|return|back)\s+(?:to\s+)?(?:question\s+)?(\d+)\b',
    ]) {
      final match = RegExp(pattern).firstMatch(normalizedText);
      final number = int.tryParse(match?.group(1) ?? '');
      if (number != null) return number;
    }
    return null;
  }

  int? _requestedQuestionCountFrom(String normalizedText) {
    for (final pattern in const [
      r'\b(?:max|min|maximum|minimum)\s+(?:question|questions)\s+(\d+)\b',
      r'\b(?:set|select|choose|make|use)\s+(?:question|questions|count|total)\s+(?:to\s+)?(\d+)\b',
      r'\b(?:question|questions|count|total)\s+(?:count\s+)?(?:to\s+)?(\d+)\b',
      r'\b(\d+)\s+(?:question|questions)\b',
    ]) {
      final match = RegExp(pattern).firstMatch(normalizedText);
      final count = int.tryParse(match?.group(1) ?? '');
      if (count != null) return count;
    }
    return null;
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
    required VoiceAccentProfile accentProfile,
    required List<String> availableCommands,
  }) async {
    try {
      final cloudResult = await cloudSpeechService.transcribeCommand(
        audioFile: fallbackAudioFile,
        locale: locale,
        screenContext: _coreContextFor(screen),
        availableCommands: availableCommands,
      );
      if (!cloudResult.isSuccess || cloudResult.transcript.trim().isEmpty) {
        debugPrint(
          '[Voice][${screen.name}] cloud fallback failed status=${cloudResult.status.name}',
        );
        return null;
      }
      debugPrint(
        '[Voice][${screen.name}] cloud fallback transcript received locale=$locale',
      );

      return _parseWithCoreParser(
        screen: screen,
        heardText: cloudResult.transcript,
        sensitivity: sensitivity,
        accentProfile: accentProfile,
      );
    } finally {
      try {
        if (await fallbackAudioFile.exists()) {
          await fallbackAudioFile.delete();
        }
      } catch (_) {
        // Best-effort cleanup for temporary fallback audio.
      }
    }
  }

  Future<_CoreVoiceParseOutcome> _parseWithCoreParser({
    required QuizVoiceScreen screen,
    required String heardText,
    required CommandSensitivity sensitivity,
    required VoiceAccentProfile accentProfile,
  }) async {
    final normalizedText = VoiceTextNormalizer.normalize(
      heardText,
      accentProfile: accentProfile,
    );
    final context = _coreContextFor(screen);
    final learnedCorrections = await _learningService.getParserCorrections(
      context,
    );
    final decision = core_parser.VoiceCommandParser.parse(
      rawText: heardText,
      context: context,
      sensitivity: _coreSensitivityFor(sensitivity),
      accentProfile: accentProfile,
      learnedCorrections: learnedCorrections,
    );
    debugPrint(
      '[Voice][${screen.name}] parser normalized="$normalizedText" decision=${decision.decision.name} intent=${decision.intent?.type.name} source=${decision.intent?.source} corrections=${learnedCorrections.length} accentProfile=${accentProfile.name}',
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

  _CoreVoiceParseOutcome _confirmationOutcome(
    _CoreVoiceParseOutcome outcome, {
    required String message,
  }) {
    final intent = outcome.coreResult.intent;
    final updatedCoreResult = core_result.VoiceCommandResult(
      decision: core_result.VoiceCommandDecision.askConfirmation,
      intent: intent,
      message: message,
    );
    return _CoreVoiceParseOutcome(
      coreResult: updatedCoreResult,
      parseResult: outcome.parseResult,
    );
  }

  String? _feedbackForCoreDecision(
    core_result.VoiceCommandResult coreDecision,
    VoiceParseResult result,
    QuizVoiceScreen screen,
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
        _unknownCommandFeedbackForScreen(screen, coreDecision.message),
      core_result.VoiceCommandDecision.ignored => null,
    };
  }

  String _unknownCommandFeedbackForScreen(
    QuizVoiceScreen screen,
    String? message,
  ) {
    if (screen == QuizVoiceScreen.mcq &&
        (message == null ||
            message == 'Local confidence was too low.' ||
            message == 'No local command matched.')) {
      return "I didn't understand. Try saying Option A, Option B, Option C, Next question, or Go back.";
    }
    return message ?? 'I did not understand. Say help to hear commands.';
  }

  String _cloudRiskyConfirmationMessage(
    QuizVoiceScreen screen,
    _CoreVoiceParseOutcome outcome,
  ) {
    if (screen == QuizVoiceScreen.examReview &&
        (outcome.parseResult.intent == VoiceIntent.submit ||
            outcome.parseResult.intent == VoiceIntent.confirmSubmit)) {
      return 'Do you want to submit your quiz?';
    }
    final label = outcome.parseResult.intent == null
        ? 'that command'
        : QuizVoiceIntentParser.commandLabelFor(outcome.parseResult.intent!);
    return 'Please confirm $label.';
  }

  Map<String, dynamic> _voiceAnalytics({
    required QuizVoiceScreen screen,
    required String rawText,
    required String normalizedText,
    required core_result.VoiceCommandResult coreResult,
    required VoiceParseResult parseResult,
    required String locale,
    required CommandSensitivity sensitivity,
    required VoiceAccentProfile accentProfile,
    required String source,
    bool fallbackAttempted = false,
    bool fallbackUsed = false,
    bool confirmationShown = false,
    bool confirmationAccepted = false,
    bool confirmationRejected = false,
    bool riskyCommandBlocked = false,
    bool? correctionSaved,
    String? confirmationTranscript,
    String? decisionName,
    String? errorType,
    String? suggestion,
  }) {
    final coreIntent = coreResult.intent;
    return <String, dynamic>{
      'screenContext': _coreContextFor(screen).name,
      'platform': Platform.operatingSystem,
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
      'suggestion': suggestion,
      'correctionSaved': correctionSaved,
      'selectedLocale': locale,
      'accentProfile': accentProfile.name,
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
      core_intent.VoiceIntentType.finalSubmit ||
      core_intent.VoiceIntentType.finishExam => VoiceIntent.submit,
      core_intent.VoiceIntentType.trueAnswer ||
      core_intent.VoiceIntentType.falseAnswer ||
      core_intent.VoiceIntentType.exitQuiz ||
      core_intent.VoiceIntentType.resetAnswers ||
      core_intent.VoiceIntentType.clearAnswer ||
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
