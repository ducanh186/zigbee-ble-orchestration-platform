import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../../domain/models/rule_humanizer.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';

/// Plain-language preview that reads the in-progress rule back as a sentence.
class RulePreview extends StatelessWidget {
  RulePreview.event({
    required AutomationTriggerEvent triggerEvent,
    required Map<String, Object?> triggerState,
    required AutomationActionCommand actionCommand,
    required SmartDevice? trigger,
    required List<SmartDevice> targets,
    AutomationDeviceType? triggerDeviceType,
    EnvironmentMetric environmentMetric = EnvironmentMetric.temperature,
    ThresholdOperator thresholdOperator = ThresholdOperator.gte,
    double? threshold,
    super.key,
  }) : text = humanizeAutomationRule(
         trigger: triggerDeviceType == AutomationDeviceType.environment
             ? SensorThresholdAutomationTrigger(
                 deviceId: trigger?.id ?? 'selected sensor',
                 metric: environmentMetric,
                 operator: thresholdOperator,
                 threshold: threshold ?? 0,
               )
             : EventAutomationTrigger(
                 deviceId: trigger?.id ?? 'selected device',
                 deviceType: triggerDeviceType ?? AutomationDeviceType.motion,
                 event: triggerEvent,
                 state: triggerState,
               ),
         actions: [
           for (final target in targets)
             DeviceCommandAutomationAction(
               deviceId: target.id,
               command: actionCommand,
             ),
         ],
         deviceNames: {
           if (trigger != null) trigger.id: trigger.name,
           for (final target in targets) target.id: target.name,
         },
       );

  const RulePreview.text({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 12,
          height: 1.5,
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
