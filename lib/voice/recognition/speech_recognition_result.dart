enum SpeechRecognitionStatus {
  success,
  speechUnavailable,
  permissionDenied,
  timeout,
  canceled,
  emptyResult,
  noInternet,
  serverError,
  invalidResponse,
}

class SpeechRecognitionResult {
  final SpeechRecognitionStatus status;
  final String transcript;
  final double confidence;
  final String provider;
  final String source;
  final String language;
  final int durationMs;
  final String? errorMessage;

  const SpeechRecognitionResult({
    required this.status,
    this.transcript = '',
    this.confidence = 0,
    this.provider = '',
    this.source = '',
    this.language = '',
    this.durationMs = 0,
    this.errorMessage,
  });

  bool get isSuccess => status == SpeechRecognitionStatus.success;

  factory SpeechRecognitionResult.success({
    required String transcript,
    required double confidence,
    required String provider,
    String? source,
    required String language,
    required int durationMs,
  }) {
    return SpeechRecognitionResult(
      status: SpeechRecognitionStatus.success,
      transcript: transcript,
      confidence: confidence,
      provider: provider,
      source: source ?? provider,
      language: language,
      durationMs: durationMs,
    );
  }

  factory SpeechRecognitionResult.failure({
    required SpeechRecognitionStatus status,
    required String message,
  }) {
    return SpeechRecognitionResult(status: status, errorMessage: message);
  }

  static SpeechRecognitionResult? fromJson(Map<String, dynamic> json) {
    final transcript = json['transcript'];
    final confidence = json['confidence'];
    final provider = json['provider'];
    final language = json['language'];
    final durationMs = json['durationMs'];

    if (transcript is! String ||
        confidence is! num ||
        provider is! String ||
        language is! String ||
        durationMs is! num) {
      return null;
    }

    return SpeechRecognitionResult.success(
      transcript: transcript,
      confidence: confidence.toDouble().clamp(0.0, 1.0),
      provider: provider,
      language: language,
      durationMs: durationMs.toInt(),
    );
  }
}
