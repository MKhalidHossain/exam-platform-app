import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Continuous audio-recorder-driven voice capture with amplitude-based
/// voice activity detection (VAD).
///
/// Replaces the listen→silence-timeout→restart cycle of `speech_to_text`
/// with a single long-running audio stream and our own endpointing. Native
/// STT used to fire `NO_MATCH`/`SPEECH_TIMEOUT` errors after a few seconds of
/// silence, ending the session and creating a ~500 ms dead window during
/// which the user's speech was lost. The continuous capture has no such
/// timeouts and no restart gaps — the mic is genuinely always-on while voice
/// mode is enabled.
///
/// Pipeline:
///
///   `startStream` produces raw PCM bytes (16 kHz mono 16-bit) →
///   we buffer them and watch `onAmplitudeChanged` →
///   when amplitude crosses [speechStartThresholdDb] we enter the "speaking"
///   state and prepend a [preRoll] of buffered bytes (so we don't miss the
///   start of the word) →
///   when amplitude stays below [speechEndThresholdDb] for
///   [trailingSilenceDuration] after the last loud sample we emit the
///   buffered audio as a finished utterance, wrap it in a WAV header, and
///   hand it to [onUtterance] for cloud transcription.
///
/// The instance can be [mute]d while TTS is playing so the assistant's own
/// voice through the speaker doesn't get treated as user speech.
class ContinuousVoiceCapture {
  ContinuousVoiceCapture({
    AudioRecorder? recorder,
    this.sampleRate = 16000,
    this.speechStartThresholdDb = -38,
    this.speechEndThresholdDb = -45,
    this.trailingSilenceDuration = const Duration(milliseconds: 650),
    // Single-syllable confirmations ("yes", "no", "A", "B") and digits are
    // routinely 120-200ms. 250ms silently dropped them. 100ms still excludes
    // single-chunk taps/noise from the amplitude poller.
    this.minSpeechDuration = const Duration(milliseconds: 100),
    this.maxUtteranceDuration = const Duration(seconds: 20),
    this.preRoll = const Duration(milliseconds: 400),
    this.amplitudePollInterval = const Duration(milliseconds: 80),
    required this.onUtterance,
    this.onSpeechStart,
    this.onSpeechEnd,
    this.onError,
  }) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final int sampleRate;
  final double speechStartThresholdDb;
  final double speechEndThresholdDb;
  final Duration trailingSilenceDuration;
  final Duration minSpeechDuration;
  final Duration maxUtteranceDuration;
  final Duration preRoll;
  final Duration amplitudePollInterval;
  final FutureOr<void> Function(File audioFile, Duration speechDuration)
      onUtterance;
  final VoidCallback? onSpeechStart;
  final VoidCallback? onSpeechEnd;
  final void Function(String message)? onError;

  StreamSubscription<Uint8List>? _pcmSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  bool _isRunning = false;
  bool _isMuted = false;
  bool _isInSpeech = false;
  DateTime? _speechStartedAt;
  DateTime? _lastLoudAt;
  Timer? _endpointTimer;

  /// Rolling pre-roll buffer kept while idle so we can prepend ~[preRoll] of
  /// audio when speech is detected (the first 100-200 ms of speech usually
  /// triggers the amplitude threshold mid-utterance, and Whisper transcribes
  /// the full word much more reliably when we include the lead-in).
  final List<Uint8List> _preRollBuffer = <Uint8List>[];
  int _preRollBytes = 0;
  late final int _preRollBytesCap = _bytesForDuration(preRoll);

  /// Active utterance buffer used while [_isInSpeech] is true. Grows from
  /// pre-roll through speech-end then is emitted to [onUtterance].
  final List<Uint8List> _utteranceBuffer = <Uint8List>[];
  int _utteranceBytes = 0;
  late final int _maxUtteranceBytesCap =
      _bytesForDuration(maxUtteranceDuration);

  bool get isRunning => _isRunning;
  bool get isMuted => _isMuted;
  bool get isInSpeech => _isInSpeech;

  Future<bool> start() async {
    if (_isRunning) return true;
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        onError?.call('microphone permission denied');
        return false;
      }
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: sampleRate,
          // `noiseSuppress`/`echoCancel` defaults vary by platform — leave
          // them at the platform default and rely on amplitude thresholds.
        ),
      );
      _pcmSubscription = stream.listen(
        _onPcmChunk,
        onError: (Object error) {
          onError?.call('pcm stream error: $error');
        },
      );
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(amplitudePollInterval)
          .listen(_onAmplitudeTick, onError: (Object error) {
        onError?.call('amplitude stream error: $error');
      });
      _isRunning = true;
      debugPrint(
        '[VAD] continuous capture started rate=$sampleRate startDb=$speechStartThresholdDb endDb=$speechEndThresholdDb',
      );
      return true;
    } catch (error, stackTrace) {
      onError?.call('start failed: $error');
      debugPrint('[VAD] start failed: $error\n$stackTrace');
      _isRunning = false;
      return false;
    }
  }

  Future<void> stop() async {
    _endpointTimer?.cancel();
    _endpointTimer = null;
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    if (_isRunning) {
      try {
        await _recorder.stop();
      } catch (_) {
        // best-effort
      }
    }
    _isRunning = false;
    _isMuted = false;
    _resetSpeechState();
    _preRollBuffer.clear();
    _preRollBytes = 0;
    debugPrint('[VAD] continuous capture stopped');
  }

  /// Suppress speech detection — used while TTS is playing so the assistant's
  /// own voice doesn't get treated as user input. Pre-roll keeps filling so
  /// when we unmute we still have lead-in available.
  void mute() {
    if (_isMuted) return;
    _isMuted = true;
    if (_isInSpeech) {
      // Drop the in-progress utterance — it was probably picked up TTS
      // bleed-through rather than the user.
      _resetSpeechState();
      onSpeechEnd?.call();
    }
    // Throw away any idle pre-roll already accumulated — once TTS starts the
    // mic input is the assistant's own voice, not the user's lead-in.
    _preRollBuffer.clear();
    _preRollBytes = 0;
    debugPrint('[VAD] muted');
  }

  void unmute() {
    if (!_isMuted) return;
    _isMuted = false;
    _lastLoudAt = null;
    _speechStartedAt = null;
    debugPrint('[VAD] unmuted');
  }

  Future<void> dispose() async {
    await stop();
    try {
      await _recorder.dispose();
    } catch (_) {
      // ignore
    }
  }

  void _onPcmChunk(Uint8List chunk) {
    if (!_isRunning) return;
    if (_isInSpeech) {
      _utteranceBuffer.add(chunk);
      _utteranceBytes += chunk.length;
      if (_utteranceBytes >= _maxUtteranceBytesCap) {
        // Hard cap — emit and reset to keep memory bounded.
        debugPrint('[VAD] utterance hit max duration, force-emit');
        _emitUtterance();
      }
      return;
    }
    // Drop pre-roll while muted — the audio reaching the mic during TTS is
    // the assistant's own voice, and we don't want that bleed prepended to
    // the next utterance (Whisper transcribes it instead of the user).
    if (_isMuted) return;
    // Idle: maintain rolling pre-roll buffer.
    _preRollBuffer.add(chunk);
    _preRollBytes += chunk.length;
    while (_preRollBytes > _preRollBytesCap && _preRollBuffer.length > 1) {
      final removed = _preRollBuffer.removeAt(0);
      _preRollBytes -= removed.length;
    }
  }

  void _onAmplitudeTick(Amplitude amplitude) {
    if (!_isRunning) return;
    if (_isMuted) {
      _resetSpeechState();
      return;
    }
    final double current = amplitude.current;
    final DateTime now = DateTime.now();
    final bool aboveStart = current >= speechStartThresholdDb;
    final bool aboveEnd = current >= speechEndThresholdDb;

    if (!_isInSpeech) {
      if (aboveStart) {
        _enterSpeech(now);
      }
      return;
    }

    if (aboveEnd) {
      _lastLoudAt = now;
      _scheduleEndpoint();
      return;
    }

    // Below end-threshold while in speech — endpoint timer will detect end.
    _scheduleEndpoint();
  }

  void _enterSpeech(DateTime now) {
    _isInSpeech = true;
    _speechStartedAt = now;
    _lastLoudAt = now;
    // Seed the utterance buffer with pre-roll so we don't miss the lead-in.
    _utteranceBuffer
      ..clear()
      ..addAll(_preRollBuffer);
    _utteranceBytes = _preRollBytes;
    _preRollBuffer.clear();
    _preRollBytes = 0;
    debugPrint('[VAD] speech detected, preRoll=${_utteranceBytes}b');
    onSpeechStart?.call();
    _scheduleEndpoint();
  }

  void _scheduleEndpoint() {
    _endpointTimer?.cancel();
    _endpointTimer = Timer(trailingSilenceDuration, _checkEndpoint);
  }

  void _checkEndpoint() {
    if (!_isInSpeech) return;
    final last = _lastLoudAt;
    if (last == null) return;
    final elapsed = DateTime.now().difference(last);
    if (elapsed < trailingSilenceDuration) {
      _scheduleEndpoint();
      return;
    }
    final speechDuration =
        DateTime.now().difference(_speechStartedAt ?? DateTime.now());
    if (speechDuration < minSpeechDuration) {
      debugPrint(
        '[VAD] dropped sub-min utterance duration=${speechDuration.inMilliseconds}ms',
      );
      _resetSpeechState();
      onSpeechEnd?.call();
      return;
    }
    _emitUtterance();
  }

  void _emitUtterance() {
    _endpointTimer?.cancel();
    _endpointTimer = null;
    final speechDuration = _speechStartedAt == null
        ? Duration.zero
        : DateTime.now().difference(_speechStartedAt!);
    // Trim trailing silence we don't need to ship to the server — we keep
    // ~100 ms of trailing silence as breathing room for Whisper.
    final bytes = _concatenate(_utteranceBuffer);
    _resetSpeechState();
    onSpeechEnd?.call();
    if (bytes.isEmpty) return;
    unawaited(_writeWavAndEmit(bytes, speechDuration));
  }

  Future<void> _writeWavAndEmit(
    Uint8List samples,
    Duration speechDuration,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/vad-${DateTime.now().microsecondsSinceEpoch}.wav';
      final file = File(path);
      final wavBytes = _wrapPcmAsWav(samples, sampleRate: sampleRate);
      await file.writeAsBytes(wavBytes, flush: true);
      debugPrint(
        '[VAD] utterance emitted bytes=${wavBytes.length} speech=${speechDuration.inMilliseconds}ms',
      );
      await onUtterance(file, speechDuration);
    } catch (error) {
      onError?.call('write/emit utterance failed: $error');
    }
  }

  void _resetSpeechState() {
    _endpointTimer?.cancel();
    _endpointTimer = null;
    _isInSpeech = false;
    _speechStartedAt = null;
    _lastLoudAt = null;
    _utteranceBuffer.clear();
    _utteranceBytes = 0;
  }

  int _bytesForDuration(Duration duration) {
    // PCM 16-bit mono = 2 bytes/sample. sampleRate samples/sec.
    return (sampleRate * 2 * duration.inMilliseconds) ~/ 1000;
  }

  Uint8List _concatenate(List<Uint8List> chunks) {
    final total = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final result = Uint8List(total);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  /// Wraps raw little-endian PCM 16-bit mono samples in a standard WAV
  /// (RIFF) container. Faster-whisper on the VPS reads WAV directly via
  /// ffmpeg without any re-encoding.
  static Uint8List _wrapPcmAsWav(Uint8List pcm, {required int sampleRate}) {
    const int channels = 1;
    const int bitsPerSample = 16;
    final int byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final int blockAlign = channels * bitsPerSample ~/ 8;
    final int dataSize = pcm.length;
    final int riffSize = 36 + dataSize;

    final header = BytesBuilder();
    void writeStr(String s) => header.add(s.codeUnits);
    void writeU32(int v) {
      header.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    }

    void writeU16(int v) {
      header.add([v & 0xFF, (v >> 8) & 0xFF]);
    }

    writeStr('RIFF');
    writeU32(riffSize);
    writeStr('WAVE');
    writeStr('fmt ');
    writeU32(16); // fmt chunk size
    writeU16(1); // PCM format
    writeU16(channels);
    writeU32(sampleRate);
    writeU32(byteRate);
    writeU16(blockAlign);
    writeU16(bitsPerSample);
    writeStr('data');
    writeU32(dataSize);
    final headerBytes = header.toBytes();

    final result = Uint8List(headerBytes.length + pcm.length);
    result.setRange(0, headerBytes.length, headerBytes);
    result.setRange(headerBytes.length, result.length, pcm);
    return result;
  }
}
