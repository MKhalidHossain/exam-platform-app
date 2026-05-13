import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart' as native;
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_recognition_result.dart';
import 'voice_recognition_service.dart';

class NativeSpeechService implements VoiceRecognitionService {
  static const String nativeSource = 'native';

  final SpeechToText _speech;

  bool _initialized = false;
  bool _available = false;
  String? _activeLocaleId;
  native.SpeechRecognitionResult? _lastResult;
  Completer<SpeechRecognitionResult>? _listenCompleter;
  Timer? _timeoutTimer;

  NativeSpeechService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  bool get isInitialized => _initialized;
  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  @override
  Future<SpeechRecognitionResult> initialize() async {
    try {
      final available = await _speech.initialize(
        onError: (error) {
          _completeListen(
            SpeechRecognitionResult.failure(
              status: SpeechRecognitionStatus.speechUnavailable,
              message: error.errorMsg,
            ),
          );
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _completeListen(_resultFromLastNativeResult());
          }
        },
      );

      _initialized = true;
      _available = available;

      if (!available) {
        final hasPermission = await _speech.hasPermission;
        return SpeechRecognitionResult.failure(
          status: hasPermission
              ? SpeechRecognitionStatus.speechUnavailable
              : SpeechRecognitionStatus.permissionDenied,
          message: hasPermission
              ? 'Native speech recognition is unavailable.'
              : 'Microphone or speech recognition permission denied.',
        );
      }

      return SpeechRecognitionResult.success(
        transcript: '',
        confidence: 1,
        provider: nativeSource,
        source: nativeSource,
        language: '',
        durationMs: 0,
      );
    } catch (error) {
      _initialized = false;
      _available = false;
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.speechUnavailable,
        message: 'Native speech initialization failed: $error',
      );
    }
  }

  @override
  Future<List<VoiceRecognitionLocale>> locales() async {
    try {
      if (!_initialized) {
        final result = await initialize();
        if (!result.isSuccess) return const <VoiceRecognitionLocale>[];
      }

      final nativeLocales = await _speech.locales();
      return nativeLocales
          .map(
            (locale) => VoiceRecognitionLocale(
              localeId: locale.localeId,
              name: locale.name,
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <VoiceRecognitionLocale>[];
    }
  }

  @override
  Future<SpeechRecognitionResult> listen({
    VoiceRecognitionListenConfig config = const VoiceRecognitionListenConfig(),
    VoiceRecognitionResultCallback? onPartialResult,
  }) async {
    if (!_initialized || !_available) {
      final initResult = await initialize();
      if (!initResult.isSuccess) return initResult;
    }

    final hasPermission = await _speech.hasPermission;
    if (!hasPermission) {
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.permissionDenied,
        message: 'Microphone or speech recognition permission denied.',
      );
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    _activeLocaleId = config.localeId;
    _lastResult = null;
    _listenCompleter = Completer<SpeechRecognitionResult>();
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(config.listenFor, () {
      _completeListen(
        SpeechRecognitionResult.failure(
          status: SpeechRecognitionStatus.timeout,
          message: 'Native speech recognition timed out.',
        ),
      );
      unawaited(_speech.stop());
    });

    try {
      await _speech.listen(
        localeId: config.localeId,
        listenFor: config.listenFor,
        pauseFor: config.pauseFor,
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: config.partialResults,
        ),
        onResult: (result) {
          _lastResult = result;
          final partial = _resultFromNativeResult(result);
          if (!result.finalResult) {
            onPartialResult?.call(partial);
            return;
          }
          _completeListen(partial);
        },
      );
    } catch (error) {
      _completeListen(
        SpeechRecognitionResult.failure(
          status: SpeechRecognitionStatus.speechUnavailable,
          message: 'Native speech listen failed: $error',
        ),
      );
    }

    return _listenCompleter!.future;
  }

  @override
  Future<SpeechRecognitionResult> stop() async {
    try {
      await _speech.stop();
      final result = _resultFromLastNativeResult();
      _completeListen(result);
      return result;
    } catch (error) {
      final result = SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.speechUnavailable,
        message: 'Native speech stop failed: $error',
      );
      _completeListen(result);
      return result;
    }
  }

  @override
  Future<SpeechRecognitionResult> cancel() async {
    try {
      await _speech.cancel();
      final result = SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.canceled,
        message: 'Native speech recognition canceled.',
      );
      _completeListen(result);
      return result;
    } catch (error) {
      final result = SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.speechUnavailable,
        message: 'Native speech cancel failed: $error',
      );
      _completeListen(result);
      return result;
    }
  }

  SpeechRecognitionResult _resultFromLastNativeResult() {
    final result = _lastResult;
    if (result == null || result.recognizedWords.trim().isEmpty) {
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.emptyResult,
        message: 'Native speech recognition returned no transcript.',
      );
    }
    return _resultFromNativeResult(result);
  }

  SpeechRecognitionResult _resultFromNativeResult(
    native.SpeechRecognitionResult result,
  ) {
    final transcript = result.recognizedWords.trim();
    if (transcript.isEmpty) {
      return SpeechRecognitionResult.failure(
        status: SpeechRecognitionStatus.emptyResult,
        message: 'Native speech recognition returned no transcript.',
      );
    }

    return SpeechRecognitionResult.success(
      transcript: transcript,
      confidence: result.confidence.clamp(0.0, 1.0).toDouble(),
      provider: nativeSource,
      source: nativeSource,
      language: _activeLocaleId ?? '',
      durationMs: 0,
    );
  }

  void _completeListen(SpeechRecognitionResult result) {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    final completer = _listenCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete(result);
  }
}
