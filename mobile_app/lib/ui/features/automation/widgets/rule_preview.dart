import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import 'automation_visuals.dart';

/// Plain-language preview that reads the in-progress rule back as a
/// sentence. Mirrors the design's RulePreview block.
class RulePreview extends StatelessWidget {
  const RulePreview({
    required this.template,
    required this.trigger,
    required this.targets,
    super.key,
  });

  final AutomationRuleTemplate template;
  final SmartDevice? trigger;
  final List<SmartDevice> targets;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final verb = switch (template.actionCommand) {
      AutomationActionCommand.toggle => 'Toggle',
      AutomationActionCommand.on => 'Turn',
      AutomationActionCommand.off => 'Turn',
    };
    final tail = switch (template.actionCommand) {
      AutomationActionCommand.toggle => '',
      AutomationActionCommand.on => ' on',
      AutomationActionCommand.off => ' off',
    };

    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                height: 1.5,
                color: palette.textPrimary,
              ),
              children: [
                TextSpan(
                  text: 'When ',
                  style: TextStyle(
                    color: palette.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: trigger?.id ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: ' ${AutomationVisuals.triggerEventLabel(template)}',
                  style: TextStyle(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                height: 1.5,
                color: palette.textPrimary,
              ),
              children: [
                TextSpan(
                  text: 'Then ',
                  style: TextStyle(
                    color: palette.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: '$verb '),
                if (targets.isEmpty)
                  TextSpan(
                    text: 'selected lights',
                    style: TextStyle(color: palette.textSecondary),
                  )
                else
                  TextSpan(
                    text: targets.map((light) => light.id).join(', '),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                TextSpan(text: tail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
