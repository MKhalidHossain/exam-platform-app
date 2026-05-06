import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/quiz_voice_controller.dart';

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
                      'Voice debug: $screenName / $phaseName',
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
