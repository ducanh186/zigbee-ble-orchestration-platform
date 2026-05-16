import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../core/widgets/status_badge.dart';

/// Shared icon + tone mapping between rule cards, status chips and template
/// pickers. Mirrors the design's `SYNC_TONE / RUN_TONE / TYPE_ICON` maps.
class AutomationVisuals {
  static IconData templateIcon(AutomationRuleTemplate template) {
    return switch (template) {
      AutomationRuleTemplate.motionOccupiedTurnsOnLights ||
      AutomationRuleTemplate.motionUnoccupiedTurnsOffLights => Icons.sensors,
      AutomationRuleTemplate.switchTogglesOneLight ||
      AutomationRuleTemplate.switchTogglesLights => Icons.toggle_off,
    };
  }

  static IconData deviceTypeIcon(AutomationDeviceType type) {
    return switch (type) {
      AutomationDeviceType.light => Icons.lightbulb_outline,
      AutomationDeviceType.motion => Icons.sensors,
      AutomationDeviceType.switchDevice => Icons.toggle_off,
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
      // SCRUM-50: syncing/pending maps to neutral. The cloud has not yet
      // acknowledged the rule, so a warning tone would over-claim. The
      // "PENDING" label still distinguishes it from idle neutral states.
      AutomationSyncStatus.pending => BadgeTone.neutral,
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
  ];

  static String triggerEventLabel(AutomationRuleTemplate template) {
    return switch (template) {
      AutomationRuleTemplate.motionOccupiedTurnsOnLights =>
        'occupancy changes: occupied',
      AutomationRuleTemplate.motionUnoccupiedTurnsOffLights =>
        'occupancy changes: unoccupied',
      AutomationRuleTemplate.switchTogglesOneLight ||
      AutomationRuleTemplate.switchTogglesLights => 'toggles',
    };
  }
}
