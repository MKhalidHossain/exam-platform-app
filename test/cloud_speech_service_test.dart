import 'dart:convert';
import 'dart:io';

import 'package:ej_flutter/voice/core/voice_command_context.dart';
import 'package:ej_flutter/voice/recognition/cloud_speech_service.dart';
import 'package:ej_flutter/voice/recognition/speech_recognition_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  late File audioFile;

  setUp(() async {
    audioFile = await File(
      '${Directory.systemTemp.path}/voice-test-${DateTime.now().microsecondsSinceEpoch}.wav',
    ).writeAsBytes(<int>[1, 2, 3, 4]);
  });

  tearDown(() async {
    if (await audioFile.exists()) {
      await audioFile.delete();
    }
  });

  group('CloudSpeechService', () {
    test(
      'posts command context and audio to configured backend endpoint',
      () async {
        final service = CloudSpeechService(
          endpoint: Uri.parse(
            'https://backend.example.com/api/voice/transcribe-command',
          ),
          client: _FakeCloudSpeechClient((request) async {
            expect(request.method, 'POST');
            expect(
              request.url.toString(),
              'https://backend.example.com/api/voice/transcribe-command',
            );
            expect(request, isA<http.MultipartRequest>());

            final multipart = request as http.MultipartRequest;
            expect(multipart.fields['locale'], 'en-US');
            expect(
              multipart.fields['screenContext'],
              VoiceScreenContext.quiz.name,
            );
            expect(
              jsonDecode(multipart.fields['availableCommands'] ?? ''),
              <String>['option b', 'next question'],
            );
            expect(multipart.files.single.field, 'audio');

            return http.Response(
              jsonEncode({
                'transcript': 'option b',
                'confidence': 0.91,
                'provider': 'backend-proxy',
                'language': 'en-US',
                'durationMs': 830,
              }),
              200,
            );
          }),
        );

        final result = await service.transcribeCommand(
          audioFile: audioFile,
          locale: 'en-US',
          screenContext: VoiceScreenContext.quiz,
          availableCommands: const <String>['option b', 'next question'],
        );

        expect(result.isSuccess, isTrue);
        expect(result.transcript, 'option b');
        expect(result.confidence, 0.91);
        expect(result.provider, 'backend-proxy');
        expect(result.language, 'en-US');
        expect(result.durationMs, 830);
      },
    );

    test('handles server errors', () async {
      final service = CloudSpeechService(
        endpoint: Uri.parse(
          'https://backend.example.com/api/voice/transcribe-command',
        ),
        client: _FakeCloudSpeechClient(
          (request) async => http.Response('Oops', 500),
        ),
      );

      final result = await service.transcribeCommand(
        audioFile: audioFile,
        locale: 'en-US',
        screenContext: VoiceScreenContext.review,
        availableCommands: const <String>['confirm submit'],
      );

      expect(result.status, SpeechRecognitionStatus.serverError);
    });

    test('handles invalid responses', () async {
      final service = CloudSpeechService(
        endpoint: Uri.parse(
          'https://backend.example.com/api/voice/transcribe-command',
        ),
        client: _FakeCloudSpeechClient(
          (request) async => http.Response(jsonEncode({'text': 'next'}), 200),
        ),
      );

      final result = await service.transcribeCommand(
        audioFile: audioFile,
        locale: 'en-US',
        screenContext: VoiceScreenContext.quiz,
        availableCommands: const <String>['next question'],
      );

      expect(result.status, SpeechRecognitionStatus.invalidResponse);
    });

    test('handles missing audio files', () async {
      final service = CloudSpeechService(
        endpoint: Uri.parse(
          'https://backend.example.com/api/voice/transcribe-command',
        ),
        client: _FakeCloudSpeechClient(
          (request) async => http.Response('{}', 200),
        ),
      );

      final result = await service.transcribeCommand(
        audioFile: File('${Directory.systemTemp.path}/missing-audio.wav'),
        locale: 'en-US',
        screenContext: VoiceScreenContext.quiz,
        availableCommands: const <String>['next question'],
      );

      expect(result.status, SpeechRecognitionStatus.invalidResponse);
    });
  });
}

class _FakeCloudSpeechClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;

  _FakeCloudSpeechClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}
