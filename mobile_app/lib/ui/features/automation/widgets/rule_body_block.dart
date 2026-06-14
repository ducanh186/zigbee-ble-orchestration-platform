import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../../domain/models/cron_humanizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

/// Readable rule body. Device ids are resolved to their soft labels via
/// [deviceNames] (falling back to the id). Schedule rules read as one flowing
/// English sentence ("Every hour at minute 35, turn Lab Light on."); event /
/// threshold rules keep the `WHEN ... THEN ...` block.
class RuleBodyBlock extends StatelessWidget {
  const RuleBodyBlock({
    required this.rule,
    this.deviceNames = const {},
    super.key,
  });

  final AutomationRule rule;
  final Map<String, String> deviceNames;

  String _name(String id) => deviceNames[id] ?? id;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final trigger = rule.trigger;

    final Widget body;
    if (trigger is ScheduleAutomationTrigger) {
      body = _ScheduleSentence(text: _scheduleSentence(trigger, l10n));
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line(
            label: l10n.whenLabel,
            labelColor: palette.primary,
            subject: _name(trigger.deviceId),
            detail: _eventText(trigger, l10n),
          ),
          const SizedBox(height: 4),
          _ThenLine(label: l10n.thenLabel, actions: rule.actions, name: _name),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: body,
    );
  }

  /// "Every hour at minute 35, turn Lab Light on."
  String _scheduleSentence(
    ScheduleAutomationTrigger trigger,
    AppLocalizations l10n,
  ) {
    final when = _capitalize(humanizeCron(trigger.cron));
    final actions = rule.actions.map((action) => _actionClause(action)).toList();
    if (actions.isEmpty) {
      return '$when.';
    }
    return '$when, ${_joinClauses(actions)}.';
  }

  String _actionClause(AutomationAction action) {
    return switch (action) {
      DeviceCommandAutomationAction(:final deviceId, :final command) =>
        'turn ${_name(deviceId)} ${_verb(command)}',
      SceneActivateAutomationAction(:final sceneId) => 'activate $sceneId',
    };
  }

  String _verb(AutomationActionCommand command) => switch (command) {
    AutomationActionCommand.on => 'on',
    AutomationActionCommand.off => 'off',
    AutomationActionCommand.toggle => 'toggle',
  };

  String _joinClauses(List<String> clauses) {
    if (clauses.length == 1) {
      return clauses.first;
    }
    return '${clauses.sublist(0, clauses.length - 1).join(', ')} '
        'and ${clauses.last}';
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  String _eventText(AutomationTrigger trigger, AppLocalizations l10n) {
    if (trigger is SensorThresholdAutomationTrigger) {
      final metric = trigger.metric == EnvironmentMetric.temperature
          ? l10n.temperatureLabel
          : l10n.humidityLabel;
      final operator = trigger.operator == ThresholdOperator.gte ? '>=' : '<=';
      final threshold = trigger.threshold == trigger.threshold.roundToDouble()
          ? trigger.threshold.toStringAsFixed(0)
          : trigger.threshold.toStringAsFixed(1);
      final unit = trigger.metric == EnvironmentMetric.temperature
          ? l10n.degreesCelsiusUnit
          : l10n.percentUnit;
      return '$metric $operator $threshold$unit';
    }
    final occupancy = trigger.state['occupancy'];
    if (trigger.event == AutomationTriggerEvent.occupancyChanged) {
      return occupancy == null
          ? l10n.occupancyChangesLabel
          : l10n.occupancyChangesValue(occupancy.toString());
    }
    return l10n.togglesLabel;
  }
}

class _ScheduleSentence extends StatelessWidget {
  const _ScheduleSentence({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.event_repeat, size: 16, color: palette.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.labelColor,
    required this.subject,
    required this.detail,
  });

  final String label;
  final Color labelColor;
  final String subject;
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              Text(
                detail,
                style: TextStyle(
                  color: palette.textPrimary,
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
  const _ThenLine({
    required this.label,
    required this.actions,
    required this.name,
  });

  final String label;
  final List<AutomationAction> actions;
  final String Function(String id) name;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: TextStyle(
              color: palette.success,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
                          fontSize: 12,
                          height: 1.45,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _verbText(action, l10n),
                      style: TextStyle(
                        color: palette.textPrimary,
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
      DeviceCommandAutomationAction(:final deviceId) => name(deviceId),
      SceneActivateAutomationAction(:final groupId, :final sceneId) =>
        '$groupId / $sceneId',
    };
  }

  String _verbText(AutomationAction action, AppLocalizations? l10n) {
    return switch (action) {
      DeviceCommandAutomationAction(command: AutomationActionCommand.on) =>
        l10n?.turnOnLabel ?? 'on',
      DeviceCommandAutomationAction(command: AutomationActionCommand.off) =>
        l10n?.turnOffLabel ?? 'off',
      DeviceCommandAutomationAction(command: AutomationActionCommand.toggle) =>
        l10n?.toggleLabel ?? 'toggle',
      SceneActivateAutomationAction() => l10n?.activateLabel ?? 'activate',
    };
  }
}
