import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/quiz_voice_controller.dart';
import '../../services/voice_assistant_settings_service.dart';
import '../../voice/learning/voice_learning_service.dart';
import '../../voice/ui/voice_calibration_screen.dart';

class QuizVoiceDebugPanel extends StatelessWidget {
  const QuizVoiceDebugPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final QuizVoiceController controller =
        Get.isRegistered<QuizVoiceController>()
        ? Get.find<QuizVoiceController>()
        : Get.put(QuizVoiceController(), permanent: true);

    return Obx(() {
      final bool expanded = controller.isDebugPanelExpanded.value;
      final logs = controller.recentLogs.reversed.take(6).toList();
      final String screenName = controller.activeScreen.value.name;
      final String phaseName = controller.phase.value.name;
      final String stateName = controller.voiceState.value.name;
      final settings = controller.assistantSettings.value;

      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: controller.toggleDebugPanel,
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.bug_report : Icons.bug_report_outlined,
                    size: 15,
                    color: const Color(0xFF334155),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Voice debug: $screenName / $phaseName / $stateName',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF334155),
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              _VoiceSettingsControls(
                settings: settings,
                onChanged: (next) =>
                    unawaited(controller.updateAssistantSettings(next)),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: logs.isEmpty
                    ? const Text(
                        'No voice events yet.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: logs
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    entry,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      height: 1.25,
                                      color: Color(0xFF0F172A),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _VoiceSettingsControls extends StatelessWidget {
  final VoiceAssistantSettings settings;
  final ValueChanged<VoiceAssistantSettings> onChanged;

  const _VoiceSettingsControls({
    required this.settings,
    required this.onChanged,
  });

  static const List<String> _languageCodes = [
    'en-US',
    'en-GB',
    'en-IN',
    'bn-BD',
  ];

  String _safeLocale(String locale) {
    return _languageCodes.contains(locale) ? locale : 'en-US';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Voice settings',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          _CompactSlider(
            label: 'Speed',
            value: settings.voiceSpeed,
            min: 0.2,
            max: 1.0,
            onChanged: (value) =>
                onChanged(settings.copyWith(voiceSpeed: value)),
          ),
          _CompactSlider(
            label: 'Pitch',
            value: settings.voicePitch,
            min: 0.5,
            max: 2.0,
            onChanged: (value) =>
                onChanged(settings.copyWith(voicePitch: value)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _safeLocale(settings.languageCode),
                  decoration: const InputDecoration(
                    labelText: 'TTS language',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: _languageCodes
                      .map(
                        (code) =>
                            DropdownMenuItem(value: code, child: Text(code)),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    onChanged(settings.copyWith(languageCode: value));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<CommandSensitivity>(
                  initialValue: settings.commandSensitivity,
                  decoration: const InputDecoration(
                    labelText: 'Sensitivity',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: CommandSensitivity.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    onChanged(settings.copyWith(commandSensitivity: value));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _safeLocale(settings.speechLocaleCode),
            decoration: const InputDecoration(
              labelText: 'Speech locale',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: _languageCodes
                .map((code) => DropdownMenuItem(value: code, child: Text(code)))
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) return;
              onChanged(settings.copyWith(speechLocaleCode: value));
            },
          ),
          const SizedBox(height: 4),
          _CompactSwitch(
            label: 'Auto listen on open',
            value: settings.autoListenOnScreenOpen,
            onChanged: (value) =>
                onChanged(settings.copyWith(autoListenOnScreenOpen: value)),
          ),
          _CompactSwitch(
            label: 'Show heard text',
            value: settings.showHeardText,
            onChanged: (value) =>
                onChanged(settings.copyWith(showHeardText: value)),
          ),
          _CompactSwitch(
            label: 'Show debug confidence',
            value: settings.showDebugConfidence,
            onChanged: (value) =>
                onChanged(settings.copyWith(showDebugConfidence: value)),
          ),
          _CompactSwitch(
            label: 'Enable cloud fallback',
            value: settings.cloudFallbackEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(cloudFallbackEnabled: value)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                TextButton.icon(
                  onPressed: () => unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const VoiceCalibrationScreen(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 15),
                  label: const Text(
                    'Run calibration',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      unawaited(VoiceLearningService().clearCorrections()),
                  icon: const Icon(Icons.cleaning_services_outlined, size: 15),
                  label: const Text(
                    'Clear learned corrections',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _CompactSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 8,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
        ),
      ),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
    );
  }
}
