import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../core/theme/app_theme.dart';

/// Monospace `WHEN ... THEN ...` block. Reads the rule like a sentence using
/// the same device IDs that appear in the Logs tab.
class RuleBodyBlock extends StatelessWidget {
  const RuleBodyBlock({required this.rule, super.key});

  final AutomationRule rule;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final trigger = rule.trigger;
    final triggerDeviceId = switch (trigger) {
      ScheduleAutomationTrigger() => 'schedule',
      _ => trigger.deviceId,
    };
    final triggerEvent = _eventText(trigger);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line(
            label: 'WHEN',
            labelColor: palette.primary,
            deviceId: triggerDeviceId,
            detail: triggerEvent,
          ),
          const SizedBox(height: 4),
          _ThenLine(actions: rule.actions),
        ],
      ),
    );
  }

  String _eventText(AutomationTrigger trigger) {
    if (trigger case ScheduleAutomationTrigger(:final cron)) {
      return cron;
    }
    final occupancy = trigger.state['occupancy'];
    if (trigger.event == AutomationTriggerEvent.occupancyChanged) {
      return occupancy == null
          ? 'occupancy changes'
          : 'occupancy changes: $occupancy';
    }
    return 'toggles';
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.labelColor,
    required this.deviceId,
    required this.detail,
  });

  final String label;
  final Color labelColor;
  final String deviceId;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deviceId,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              Text(
                detail,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThenLine extends StatelessWidget {
  const _ThenLine({required this.actions});

  final List<AutomationAction> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Text(
            'THEN',
            style: TextStyle(
              color: palette.success,
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final action in actions)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _targetText(action),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          height: 1.45,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _verbText(action),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _targetText(AutomationAction action) {
    return switch (action) {
      DeviceCommandAutomationAction(:final deviceId) => deviceId,
      SceneActivateAutomationAction(:final groupId, :final sceneId) =>
        '$groupId / $sceneId',
    };
  }

  String _verbText(AutomationAction action) {
    return switch (action) {
      DeviceCommandAutomationAction(:final command) => command.wireValue,
      SceneActivateAutomationAction() => 'activate',
    };
  }
}
