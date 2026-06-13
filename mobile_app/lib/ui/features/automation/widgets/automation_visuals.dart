import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../core/widgets/status_badge.dart';

/// Shared icon + tone mapping between rule cards, status chips and template
/// pickers. Mirrors the design's `SYNC_TONE / RUN_TONE / TYPE_ICON` maps.
class AutomationVisuals {
  static AutomationRuleTemplate templateForRule(AutomationRule rule) {
    if (rule.trigger.triggerType == AutomationTriggerType.schedule) {
      final firstAction = rule.actions.firstOrNull;
      if (firstAction is DeviceCommandAutomationAction &&
          firstAction.command == AutomationActionCommand.off) {
        return AutomationRuleTemplate.scheduleOff;
      }
      return AutomationRuleTemplate.scheduleOn;
    }

    final firstAction = rule.actions.firstOrNull;
    final firstCommand = firstAction is DeviceCommandAutomationAction
        ? firstAction.command
        : null;
    return switch (rule.trigger.event) {
      AutomationTriggerEvent.occupancyChanged =>
        rule.trigger.state['occupancy'] == 'unoccupied'
            ? AutomationRuleTemplate.motionUnoccupiedTurnsOffLights
            : AutomationRuleTemplate.motionOccupiedTurnsOnLights,
      AutomationTriggerEvent.switchToggle =>
        rule.actions.length <= 1 ||
                firstCommand != AutomationActionCommand.toggle
            ? AutomationRuleTemplate.switchTogglesOneLight
            : AutomationRuleTemplate.switchTogglesLights,
    };
  }

  static IconData templateIcon(AutomationRuleTemplate template) {
    return switch (template) {
      AutomationRuleTemplate.motionOccupiedTurnsOnLights ||
      AutomationRuleTemplate.motionUnoccupiedTurnsOffLights => Icons.sensors,
      AutomationRuleTemplate.switchTogglesOneLight ||
      AutomationRuleTemplate.switchTogglesLights => Icons.toggle_off,
      AutomationRuleTemplate.scheduleOn ||
      AutomationRuleTemplate.scheduleOff => Icons.schedule,
    };
  }

  static IconData deviceTypeIcon(AutomationDeviceType type) {
    return switch (type) {
      AutomationDeviceType.light => Icons.lightbulb_outline,
      AutomationDeviceType.motion => Icons.sensors,
      AutomationDeviceType.switchDevice => Icons.toggle_off,
      AutomationDeviceType.environment => Icons.thermostat,
    };
  }

  static IconData runStatusIcon(AutomationLastRunStatus status) {
    return switch (status) {
      AutomationLastRunStatus.executed => Icons.check_circle_outline,
      AutomationLastRunStatus.failed => Icons.error_outline,
      AutomationLastRunStatus.timeout => Icons.timer_outlined,
      AutomationLastRunStatus.neverRun => Icons.remove,
    };
  }

  static BadgeTone syncTone(AutomationSyncStatus status) {
    return switch (status) {
      AutomationSyncStatus.synced => BadgeTone.success,
      AutomationSyncStatus.failed => BadgeTone.error,
      AutomationSyncStatus.pending => BadgeTone.warning,
    };
  }

  static BadgeTone runTone(AutomationLastRunStatus status) {
    return switch (status) {
      AutomationLastRunStatus.executed => BadgeTone.success,
      AutomationLastRunStatus.failed ||
      AutomationLastRunStatus.timeout => BadgeTone.error,
      AutomationLastRunStatus.neverRun => BadgeTone.neutral,
    };
  }

  /// 4-card MVP grid order, mirrors AutomationMock.jsx TEMPLATES.
  static const templateOrder = <AutomationRuleTemplate>[
    AutomationRuleTemplate.motionOccupiedTurnsOnLights,
    AutomationRuleTemplate.motionUnoccupiedTurnsOffLights,
    AutomationRuleTemplate.switchTogglesOneLight,
    AutomationRuleTemplate.switchTogglesLights,
    AutomationRuleTemplate.scheduleOn,
    AutomationRuleTemplate.scheduleOff,
  ];

  static String triggerEventLabel(
    AutomationTriggerEvent event,
    Map<String, Object?> state,
  ) {
    return switch (event) {
      AutomationTriggerEvent.occupancyChanged =>
        'occupancy changes: ${state['occupancy'] ?? 'occupied'}',
      AutomationTriggerEvent.switchToggle => 'toggles',
    };
  }
}
