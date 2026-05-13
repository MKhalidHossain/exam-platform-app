enum VoiceIntentType {
  optionA,
  optionB,
  optionC,
  optionD,
  trueAnswer,
  falseAnswer,
  next,
  previous,
  skip,
  repeat,
  readQuestion,
  readSummary,
  flag,
  bookmark,
  explain,
  review,
  unanswered,
  flagged,
  questionNumber,
  submit,
  confirmSubmit,
  cancelSubmit,
  finalSubmit,
  exitQuiz,
  resetAnswers,
  clearAnswer,
  finishExam,
  delete,
  restartTest,
  startQuiz,
  startTest,
  timedModeOn,
  timedModeOff,
  maxQuestions,
  minQuestions,
  increaseQuestions,
  decreaseQuestions,
  setQuestionCount,
  status,
  retry,
  cancel,
  back,
  help,
  stopVoice,
  pauseAssistant,
  resumeAssistant,
}

class VoiceIntent {
  final VoiceIntentType type;
  final String? value;
  final int? number;
  final double confidence;
  final bool isRisky;
  final String rawText;
  final String normalizedText;
  final String source;

  const VoiceIntent({
    required this.type,
    this.value,
    this.number,
    required this.confidence,
    required this.isRisky,
    required this.rawText,
    required this.normalizedText,
    required this.source,
  });

  VoiceIntent copyWith({
    VoiceIntentType? type,
    String? value,
    int? number,
    double? confidence,
    bool? isRisky,
    String? rawText,
    String? normalizedText,
    String? source,
  }) {
    return VoiceIntent(
      type: type ?? this.type,
      value: value ?? this.value,
      number: number ?? this.number,
      confidence: confidence ?? this.confidence,
      isRisky: isRisky ?? this.isRisky,
      rawText: rawText ?? this.rawText,
      normalizedText: normalizedText ?? this.normalizedText,
      source: source ?? this.source,
    );
  }
}
