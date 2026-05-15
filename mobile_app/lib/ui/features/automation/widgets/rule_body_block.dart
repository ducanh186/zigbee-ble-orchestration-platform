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
    final triggerEvent = _eventText(rule.trigger);
    final actionVerb = _actionVerb(rule.actions);

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
            deviceId: rule.trigger.deviceId,
            detail: triggerEvent,
          ),
          const SizedBox(height: 4),
          _ThenLine(actions: rule.actions, verb: actionVerb),
        ],
      ),
    );
  }

  String _actionVerb(List<AutomationAction> actions) {
    if (actions.isEmpty) {
      return '';
    }
    return switch (actions.first.command) {
      AutomationActionCommand.on => 'on',
      AutomationActionCommand.off => 'off',
      AutomationActionCommand.toggle => 'toggle',
    };
  }

  String _eventText(AutomationTrigger trigger) {
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
  const _ThenLine({required this.actions, required this.verb});

  final List<AutomationAction> actions;
  final String verb;

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
                        action.deviceId,
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
                      verb,
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
}
