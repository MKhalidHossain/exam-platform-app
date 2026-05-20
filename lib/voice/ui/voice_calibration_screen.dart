import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../services/voice_assistant_settings_service.dart';
import '../../utils/voice_listen_start.dart';
import '../core/voice_command_context.dart';
import '../core/voice_intent.dart';
import '../learning/voice_learning_service.dart';
import '../parsing/voice_command_aliases.dart';
import '../parsing/voice_text_normalizer.dart';

class VoiceCalibrationScreen extends StatefulWidget {
  const VoiceCalibrationScreen({super.key});

  @override
  State<VoiceCalibrationScreen> createState() => _VoiceCalibrationScreenState();
}

class _VoiceCalibrationScreenState extends State<VoiceCalibrationScreen> {
  final VoiceLearningService _learningService = const VoiceLearningService();
  final VoiceAssistantSettingsService _settingsService =
      VoiceAssistantSettingsService();
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _heardController = TextEditingController();
  int _index = 0;
  String? _statusText;
  bool _saving = false;
  bool _speechAvailable = false;
  bool _speechInitializing = false;
  bool _isListening = false;
  VoiceAccentProfile _accentProfile = VoiceAccentProfile.defaultEnglish;

  static final List<_CalibrationPhrase> _phrases = [
    _CalibrationPhrase('Option A', VoiceIntentType.optionA, value: 'a'),
    _CalibrationPhrase('Option B', VoiceIntentType.optionB, value: 'b'),
    _CalibrationPhrase('Option C', VoiceIntentType.optionC, value: 'c'),
    _CalibrationPhrase('Option D', VoiceIntentType.optionD, value: 'd'),
    _CalibrationPhrase('Next question', VoiceIntentType.next),
    _CalibrationPhrase('Read question', VoiceIntentType.readQuestion),
    _CalibrationPhrase('True', VoiceIntentType.trueAnswer, value: 'true'),
    _CalibrationPhrase('False', VoiceIntentType.falseAnswer, value: 'false'),
    _CalibrationPhrase('Submit quiz', VoiceIntentType.submit, learnable: false),
  ];

  _CalibrationPhrase get _currentPhrase => _phrases[_index];
  bool get _isLastPhrase => _index >= _phrases.length - 1;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    _heardController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.loadSettings();
    if (!mounted) return;
    setState(() => _accentProfile = settings.accentProfile);
  }

  Future<bool> _initSpeech() async {
    if (_speechInitializing) return _speechAvailable;
    _speechInitializing = true;
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('[VoiceCalibration] speech status=$status');
          if (!mounted) return;
          if (status == 'listening') {
            setState(() => _isListening = true);
          }
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          debugPrint('[VoiceCalibration] speech error: $error');
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _statusText =
                'Microphone permission or speech recognition failed. Check app microphone settings and try again.';
          });
        },
      );
      if (!mounted) return available;
      setState(() => _speechAvailable = available);
      if (!available) {
        final hasPermission = await _speech.hasPermission;
        setState(() {
          _statusText = hasPermission
              ? 'Speech recognition is not available on this device.'
              : 'Microphone permission is required. Enable it in app settings and try again.';
        });
      }
      return available;
    } catch (error) {
      debugPrint('[VoiceCalibration] speech init failed: $error');
      if (mounted) {
        setState(() {
          _speechAvailable = false;
          _statusText =
              'Speech recognition could not start. Check microphone permission and try again.';
        });
      }
      return false;
    } finally {
      _speechInitializing = false;
    }
  }

  Future<void> _listenForPhrase() async {
    if (_isListening) {
      await _stopListening();
      return;
    }
    final ready = _speechAvailable || await _initSpeech();
    if (!ready || !mounted) return;

    _heardController.clear();
    setState(() => _statusText = 'Listening...');
    await _speech.listen(
      onResult: _onSpeechResult,
      listenFor: voiceListenForDuration,
      pauseFor: voicePauseForDuration,
      listenOptions: SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _heardController.text = result.recognizedWords;
      _heardController.selection = TextSelection.collapsed(
        offset: _heardController.text.length,
      );
      _statusText = result.finalResult
          ? 'Captured. Review and save if it is correct.'
          : 'Listening...';
    });
  }

  Future<void> _saveAndContinue() async {
    if (_isListening) await _stopListening();
    final phrase = _currentPhrase;
    final heardText = _heardController.text.trim();
    if (heardText.isEmpty) {
      setState(() => _statusText = 'Enter what was heard, or skip.');
      return;
    }

    if (!phrase.learnable) {
      setState(() => _statusText = 'Submit quiz is not learned automatically.');
      _goNext();
      return;
    }

    setState(() => _saving = true);
    final intent = VoiceCommandAliases.intentFor(
      type: phrase.intentType,
      phrase: phrase.label.toLowerCase(),
      rawText: heardText,
      normalizedText: VoiceTextNormalizer.normalize(
        heardText,
        accentProfile: _accentProfile,
      ),
      value: phrase.value,
    );
    final saved = await _learningService.saveCorrection(
      rawHeardText: heardText,
      intent: intent,
      screenContext: VoiceScreenContext.quiz,
      userConfirmed: true,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _statusText = saved ? 'Saved.' : 'Skipped.';
    });
    _goNext();
  }

  void _goNext() {
    if (_isLastPhrase) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index += 1;
      _heardController.clear();
    });
  }

  void _skip() => _goNext();

  Future<void> _clearAndRestart() async {
    await _learningService.clearCorrections();
    await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _index = 0;
      _heardController.clear();
      _isListening = false;
      _statusText = 'Corrections cleared. Start calibration again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final phrase = _currentPhrase;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice calibration'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => unawaited(_clearAndRestart()),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_index + 1} of ${_phrases.length}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Text(
              phrase.label,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _heardController,
              decoration: const InputDecoration(
                labelText: 'What was heard',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_saveAndContinue()),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => unawaited(_listenForPhrase()),
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              label: Text(_isListening ? 'Stop listening' : 'Listen'),
            ),
            const SizedBox(height: 10),
            if (_statusText != null)
              Text(
                _statusText!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _skip,
                    child: const Text('Skip phrase'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveAndContinue,
                    child: Text(_isLastPhrase ? 'Finish' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalibrationPhrase {
  final String label;
  final VoiceIntentType intentType;
  final String? value;
  final bool learnable;

  const _CalibrationPhrase(
    this.label,
    this.intentType, {
    this.value,
    this.learnable = true,
  });
}
