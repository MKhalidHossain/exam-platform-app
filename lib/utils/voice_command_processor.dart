import '../controllers/quiz_voice_controller.dart';
import '../services/voice_assistant_settings_service.dart';
import 'quiz_voice_intent_parser.dart';

class VoiceCommandDecision {
  final VoiceParseResult parseResult;
  final VoiceIntent? intent;
  final String? feedback;
  final bool shouldExecute;
  final int? questionNumber;
  final int? requestedQuestionCount;

  const VoiceCommandDecision({
    required this.parseResult,
    required this.intent,
    required this.feedback,
    required this.shouldExecute,
    this.questionNumber,
    this.requestedQuestionCount,
  });
}

class VoiceCommandProcessor {
  VoiceParseResult? _pendingCorrection;

  Future<VoiceCommandDecision> process({
    required QuizVoiceScreen screen,
    required String heardText,
    required CommandSensitivity sensitivity,
  }) async {
    var result = await QuizVoiceIntentParser.parse(screen, heardText);
    var confirmedPendingCorrection = false;

    final pendingCorrection = _pendingCorrection;
    if (pendingCorrection?.intent != null &&
        QuizVoiceIntentParser.isConfirmationText(heardText)) {
      _pendingCorrection = null;
      await QuizVoiceIntentParser.rememberCorrection(
        pendingCorrection!.heardText,
        pendingCorrection.intent!,
      );
      result = pendingCorrection;
      confirmedPendingCorrection = true;
    } else {
      _pendingCorrection = null;
    }

    final feedback = confirmedPendingCorrection
        ? null
        : QuizVoiceIntentParser.confidenceFeedbackWithSensitivity(
            result,
            sensitivity,
          );

    if (feedback != null &&
        QuizVoiceIntentParser.canLearnCorrection(result.intent) &&
        feedback.startsWith('Did you mean')) {
      _pendingCorrection = result;
    }

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
    );
  }

  void clearPendingCorrection() {
    _pendingCorrection = null;
  }
}
