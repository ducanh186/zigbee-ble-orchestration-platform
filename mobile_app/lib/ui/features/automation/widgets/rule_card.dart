import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import 'automation_visuals.dart';
import 'rule_body_block.dart';
import 'rule_status_row.dart';

/// Single rule card — header (icon + name + template subtitle + enable
/// toggle), status row, WHEN/THEN block. `highlight` adds an outline used
/// after a successful save.
class RuleCard extends StatelessWidget {
  const RuleCard({
    required this.rule,
    required this.template,
    this.deviceNames = const {},
    this.onEnabledChanged,
    this.onDelete,
    this.highlight = false,
    super.key,
  });

  final AutomationRule rule;
  final AutomationRuleTemplate template;
  final Map<String, String> deviceNames;
  final ValueChanged<bool>? onEnabledChanged;
  final VoidCallback? onDelete;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final opacity = rule.enabled ? 1.0 : 0.72;
    final showMutationControls = onDelete != null || onEnabledChanged != null;
    final isSchedule =
        rule.trigger.triggerType == AutomationTriggerType.schedule;
    final isEnvironmentRule = rule.trigger is SensorThresholdAutomationTrigger;

    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: highlight ? palette.primary : palette.border,
            width: highlight ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0A000000),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: palette.primaryTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSchedule
                        ? Icons.schedule
                        : isEnvironmentRule
                        ? Icons.thermostat
                        : AutomationVisuals.templateIcon(template),
                    size: 18,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _templateLabel(
                          template,
                          l10n,
                          languageCode,
                          isSchedule: isSchedule,
                          isEnvironmentRule: isEnvironmentRule,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showMutationControls)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onDelete != null)
                        IconButton(
                          tooltip: l10n.deleteRuleTooltip,
                          icon: const Icon(Icons.delete_outline, size: 19),
                          color: palette.error,
                          onPressed: onDelete,
                          visualDensity: VisualDensity.compact,
                        ),
                      if (onEnabledChanged != null)
                        Switch(
                          value: rule.enabled,
                          onChanged: onEnabledChanged,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            RuleStatusRow(
              syncStatus: rule.syncStatus,
              runStatus: rule.lastRunStatus,
              lastRunAt: rule.updatedAt ?? rule.createdAt,
            ),
            const SizedBox(height: 10),
            RuleBodyBlock(rule: rule, deviceNames: deviceNames),
            if (rule.lastError != null && rule.lastError!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                rule.lastError!,
                style: TextStyle(color: palette.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _templateLabel(
  AutomationRuleTemplate template,
  AppLocalizations l10n,
  String languageCode, {
  required bool isSchedule,
  required bool isEnvironmentRule,
}) {
  if (isSchedule) {
    return l10n.scheduleTriggerLabel;
  }
  final vietnamese = languageCode.toLowerCase() == 'vi';
  if (isEnvironmentRule) {
    return vietnamese ? 'Cảm biến môi trường' : 'Environment sensor';
  }
  if (!vietnamese) {
    return template.label;
  }
  return switch (template) {
    AutomationRuleTemplate.switchTogglesOneLight => 'Công tắc đổi một đèn',
    AutomationRuleTemplate.switchTogglesLights => 'Công tắc đổi nhiều đèn',
    AutomationRuleTemplate.motionOccupiedTurnsOnLights =>
      'Cảm biến báo có người',
    AutomationRuleTemplate.motionUnoccupiedTurnsOffLights =>
      'Cảm biến báo không có người',
    AutomationRuleTemplate.scheduleOn => l10n.scheduleTriggerLabel,
    AutomationRuleTemplate.scheduleOff => l10n.scheduleTriggerLabel,
  };
}
