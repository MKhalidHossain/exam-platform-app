import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum VoiceAudioRecorderStatus { idle, recording, permissionDenied, error }

class VoiceAudioRecorderResult {
  final File? file;
  final VoiceAudioRecorderStatus status;
  final String? errorMessage;

  const VoiceAudioRecorderResult({
    required this.status,
    this.file,
    this.errorMessage,
  });

  bool get hasAudio => file != null && status == VoiceAudioRecorderStatus.idle;
}

class VoiceAudioRecorder {
  static const Duration defaultMaxDuration = Duration(seconds: 20);

  final AudioRecorder _recorder;
  final Duration maxDuration;

  File? _currentFile;
  bool _isRecording = false;

  VoiceAudioRecorder({
    AudioRecorder? recorder,
    this.maxDuration = defaultMaxDuration,
  }) : _recorder = recorder ?? AudioRecorder();

  bool get isRecording => _isRecording;
  File? get currentFile => _currentFile;

  Future<bool> hasMicrophonePermission({bool request = false}) async {
    try {
      return _recorder.hasPermission(request: request);
    } catch (_) {
      return false;
    }
  }

  Future<VoiceAudioRecorderResult> start() async {
    try {
      final hasPermission = await hasMicrophonePermission(request: true);
      if (!hasPermission) {
        return const VoiceAudioRecorderResult(
          status: VoiceAudioRecorderStatus.permissionDenied,
          errorMessage: 'Microphone permission denied.',
        );
      }

      await deleteTempFile();
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/voice-fallback-${DateTime.now().microsecondsSinceEpoch}.m4a',
      );

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 16000,
        ),
        path: file.path,
      );

      _currentFile = file;
      _isRecording = true;
      return VoiceAudioRecorderResult(
        status: VoiceAudioRecorderStatus.recording,
        file: file,
      );
    } catch (error) {
      _isRecording = false;
      return VoiceAudioRecorderResult(
        status: VoiceAudioRecorderStatus.error,
        errorMessage: 'Unable to start voice recording: $error',
      );
    }
  }

  Future<VoiceAudioRecorderResult> stop() async {
    if (!_isRecording) {
      return VoiceAudioRecorderResult(
        status: VoiceAudioRecorderStatus.idle,
        file: _currentFile,
      );
    }

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      final file = path == null ? _currentFile : File(path);
      _currentFile = file;

      return VoiceAudioRecorderResult(
        status: VoiceAudioRecorderStatus.idle,
        file: file,
      );
    } catch (error) {
      _isRecording = false;
      return VoiceAudioRecorderResult(
        status: VoiceAudioRecorderStatus.error,
        errorMessage: 'Unable to stop voice recording: $error',
      );
    }
  }

  Future<VoiceAudioRecorderResult> cancel() async {
    try {
      await _recorder.cancel();
      _isRecording = false;
      await deleteTempFile();
      return const VoiceAudioRecorderResult(
        status: VoiceAudioRecorderStatus.idle,
      );
    } catch (error) {
      _isRecording = false;
      return VoiceAudioRecorderResult(
        status: VoiceAudioRecorderStatus.error,
        errorMessage: 'Unable to cancel voice recording: $error',
      );
    }
  }

  Future<void> stopAfterTimeout() async {
    if (!_isRecording) return;
    await Future<void>.delayed(maxDuration);
    if (_isRecording) {
      await stop();
    }
  }

  Future<double?> getAmplitudeDb() async {
    try {
      final amplitude = await _recorder.getAmplitude();
      return amplitude.current;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteTempFile() async {
    final file = _currentFile;
    _currentFile = null;
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup for short-lived fallback audio.
    }
  }

  Future<void> dispose() async {
    if (_isRecording) {
      await cancel();
    } else {
      await deleteTempFile();
    }
    await _recorder.dispose();
  }
}
