import 'voice_intent.dart';

enum VoiceCommandDecision {
  execute,
  askConfirmation,
  fallbackToCloud,
  notUnderstood,
  ignored,
}

class VoiceCommandResult {
  final VoiceCommandDecision decision;
  final VoiceIntent? intent;
  final String? message;

  const VoiceCommandResult({required this.decision, this.intent, this.message});
}
