import 'dart:async';

import 'package:flutter/material.dart';

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
  final TextEditingController _heardController = TextEditingController();
  int _index = 0;
  String? _statusText;
  bool _saving = false;

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
  void dispose() {
    _heardController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
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
      normalizedText: VoiceTextNormalizer.normalize(heardText),
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

  @override
  Widget build(BuildContext context) {
    final phrase = _currentPhrase;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice calibration'),
        actions: [
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
