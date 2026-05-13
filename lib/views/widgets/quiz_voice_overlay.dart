import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/quiz_voice_controller.dart';

class QuizVoiceOverlay extends StatefulWidget {
  final bool isListening;
  final bool isPreparingToListen;
  final bool isSpeaking;
  final String heardText;
  final VoidCallback onMicTap;
  final String listeningHint;
  final String speakingHint;
  final String idleHint;
  final double bottomPadding;
  final List<String> instructionItems;

  const QuizVoiceOverlay({
    super.key,
    required this.isListening,
    this.isPreparingToListen = false,
    required this.isSpeaking,
    required this.heardText,
    required this.onMicTap,
    required this.listeningHint,
    required this.speakingHint,
    required this.idleHint,
    this.bottomPadding = 30,
    this.instructionItems = const <String>[],
  });

  @override
  State<QuizVoiceOverlay> createState() => _QuizVoiceOverlayState();
}

class _QuizVoiceOverlayState extends State<QuizVoiceOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  DateTime? _listeningStartedAt;
  int _unknownRetryCount = 0;
  String _lastRetryMessage = '';

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    if (widget.isListening || widget.isPreparingToListen) {
      _listeningStartedAt = DateTime.now();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant QuizVoiceOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasListening = oldWidget.isListening || oldWidget.isPreparingToListen;
    final isListeningNow = widget.isListening || widget.isPreparingToListen;

    if (!wasListening && isListeningNow) {
      _listeningStartedAt = DateTime.now();
    } else if (!isListeningNow) {
      _listeningStartedAt = null;
    }

    final retryMessage = _currentRetryMessage();
    if (retryMessage != _lastRetryMessage) {
      _lastRetryMessage = retryMessage;
      if (_isUnknownRetry(retryMessage)) {
        _unknownRetryCount += 1;
      } else if (retryMessage.isEmpty) {
        _unknownRetryCount = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final QuizVoiceController controller =
        Get.isRegistered<QuizVoiceController>()
        ? Get.find<QuizVoiceController>()
        : Get.put(QuizVoiceController(), permanent: true);

    return Obx(() {
      final bool preparing = widget.isPreparingToListen && !widget.isListening;
      final bool listening = widget.isListening || preparing;
      final bool activelyListening = widget.isListening;
      final bool speaking = widget.isSpeaking;
      final VoiceState voiceState = controller.voiceState.value;
      final String recognizedCommand = controller.recognizedCommand.value;
      final String retryMessage = controller.retryMessage.value;
      final bool debugEnabled = controller.isDebugPanelExpanded.value;
      final bool showHeardText =
          controller.assistantSettings.value.showHeardText;
      final int confidencePercent = (controller.commandConfidence.value * 100)
          .round()
          .clamp(0, 100);

      final String statusText = _statusTextFor(
        voiceState,
        speaking: speaking,
        listening: listening,
        preparing: preparing,
      );
      final Color accentColor = _accentColorFor(statusText);

      final int listeningSeconds = _listeningStartedAt == null
          ? 0
          : DateTime.now().difference(_listeningStartedAt!).inSeconds;

      final String helperText = retryMessage.isNotEmpty
          ? retryMessage
          : preparing
          ? 'Microphone is warming up. Start speaking in a moment.'
          : listening
          ? listeningSeconds >= 8
                ? "I'm still listening. Take your time and say your command."
                : widget.listeningHint
          : speaking
          ? widget.speakingHint
          : widget.idleHint;
      final bool showAudioQualityHint =
          retryMessage.isNotEmpty && _unknownRetryCount >= 2;
      final List<String> instructionItems = widget.instructionItems
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);

      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottomPadding),
          child: Material(
            color: Colors.transparent,
            child: AnimatedBuilder(
              animation: _motion,
              builder: (context, child) {
                final pulseWave =
                    (math.sin(_motion.value * math.pi * 2) + 1) / 2;

                return CustomPaint(
                  foregroundPainter: activelyListening
                      ? _ShineBorderPainter(progress: _motion.value)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.18),
                        width: 1.2,
                      ),
                      boxShadow: [
                        const BoxShadow(
                          color: Color(0x160F172A),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                        if (activelyListening)
                          BoxShadow(
                            color: const Color(
                              0xFFFE8FB5,
                            ).withValues(alpha: 0.18 + (pulseWave * 0.14)),
                            blurRadius: 22,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: widget.onMicTap,
                          child: Transform.scale(
                            scale: activelyListening
                                ? 1 + (pulseWave * 0.08)
                                : 1,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor,
                              ),
                              child: const Icon(
                                Icons.mic_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _VoiceBars(
                                    animation: _motion,
                                    color: accentColor,
                                    active: activelyListening,
                                  ),
                                  if (recognizedCommand.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Command: $recognizedCommand',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                helperText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: retryMessage.isEmpty
                                      ? const Color(0xFF334155)
                                      : const Color(0xFF9A3412),
                                ),
                              ),
                              if (showAudioQualityHint) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'Please move closer to the microphone or use a headset.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF9A3412),
                                  ),
                                ),
                              ],
                              if (debugEnabled &&
                                  recognizedCommand.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Confidence: $confidencePercent%',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                              if (!listening &&
                                  retryMessage.isEmpty &&
                                  instructionItems.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: instructionItems
                                      .take(3)
                                      .map(
                                        (item) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFEFF4FF,
                                            ).withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFCEDDF8),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E3A6F),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ],
                              if (showHeardText &&
                                  widget.heardText.trim().isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  'Heard: "${widget.heardText.trim()}"',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    });
  }

  String _statusTextFor(
    VoiceState state, {
    required bool speaking,
    required bool listening,
    required bool preparing,
  }) {
    if (speaking || state == VoiceState.speaking) return 'Speaking';
    if (listening || state == VoiceState.listening) return 'Listening';
    if (preparing || state == VoiceState.processing) return 'Processing';
    return 'Paused';
  }

  Color _accentColorFor(String statusText) {
    return switch (statusText) {
      'Listening' => const Color(0xFFDC2626),
      'Speaking' => const Color(0xFF274B8A),
      'Processing' => const Color(0xFFF59E0B),
      _ => const Color(0xFF475569),
    };
  }

  String _currentRetryMessage() {
    if (!Get.isRegistered<QuizVoiceController>()) return '';
    return Get.find<QuizVoiceController>().retryMessage.value;
  }

  bool _isUnknownRetry(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('not recognised') ||
        normalized.contains('did not understand');
  }
}

class _ShineBorderPainter extends CustomPainter {
  final double progress;

  const _ShineBorderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.1);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(19));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: const [
          Color(0x00F97316),
          Color(0xFFF97316),
          Color(0xFFEF4444),
          Color(0xFFFE8FB5),
          Color(0xFF60A5FA),
          Color(0x00F97316),
        ],
        stops: const [0.0, 0.18, 0.42, 0.62, 0.82, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShineBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _VoiceBars extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final bool active;

  const _VoiceBars({
    required this.animation,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 16,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final wave = math.sin(
                (animation.value * math.pi * 2) + (index * 0.7),
              );
              final height = active ? 5 + ((wave + 1) * 3.5) : 5.0;
              return Container(
                width: 4,
                height: height.clamp(5, 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: active ? 1 : 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
