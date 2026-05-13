import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/voice_command_context.dart';
import 'speech_recognition_result.dart';

abstract class CloudSpeechTranscriber {
  Future<SpeechRecognitionResult> transcribeCommand({
    required File audioFile,
    required String locale,
    required VoiceScreenContext screenContext,
    required List<String> availableCommands,
  });
}

class CloudSpeechService implements CloudSpeechTranscriber {
  static const String defaultEndpointPath = '/api/voice/transcribe-command';
  static const Duration defaultTimeout = Duration(seconds: 20);

  final Uri endpoint;
  final http.Client _client;
  final Duration timeout;
  final Map<String, String> headers;

  CloudSpeechService({
    required this.endpoint,
    http.Client? client,
    this.timeout = defaultTimeout,
    this.headers = const <String, String>{},
  }) : _client = client ?? http.Client();

  factory CloudSpeechService.withBaseUri({
    required Uri baseUri,
    http.Client? client,
    Duration timeout = defaultTimeout,
    Map<String, String> headers = const <String, String>{},
  }) {
    return CloudSpeechService(
      endpoint: baseUri.replace(path: defaultEndpointPath),
      client: client,
      timeout: timeout,
      headers: headers,
    );
  }

  @override
  Future<SpeechRecognitionResult> transcribeCommand({
    required File audioFile,
    required String locale,
    required VoiceScreenContext screenContext,
    required List<String> availableCommands,
  }) async {
    if (!await audioFile.exists()) {
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.invalidResponse,
        message: 'Audio file does not exist.',
      );
    }

    final request = http.MultipartRequest('POST', endpoint)
      ..headers.addAll({'Accept': 'application/json', ...headers})
      ..fields['locale'] = locale
      ..fields['screenContext'] = screenContext.name
      ..fields['availableCommands'] = jsonEncode(availableCommands);

    request.files.add(
      await http.MultipartFile.fromPath('audio', audioFile.path),
    );

    try {
      final streamedResponse = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _parseResponse(response);
    } on TimeoutException {
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.timeout,
        message: 'Cloud speech request timed out.',
      );
    } on SocketException {
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.noInternet,
        message: 'No internet connection for cloud speech fallback.',
      );
    } on http.ClientException {
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.noInternet,
        message: 'Unable to reach cloud speech backend.',
      );
    } on FormatException {
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.invalidResponse,
        message: 'Cloud speech backend returned invalid data.',
      );
    } catch (_) {
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.serverError,
        message: 'Cloud speech request failed.',
      );
    }
  }

  SpeechRecognitionResult _parseResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.serverError,
        message: 'Cloud speech backend returned ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.invalidResponse,
        message: 'Cloud speech backend response was not an object.',
      );
    }

    final result = SpeechRecognitionResult.fromJson(decoded);
    if (result == null) {
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.invalidResponse,
        message: 'Cloud speech backend response is missing required fields.',
      );
    }

    return result;
  }

  void close() {
    _client.close();
  }
}
