import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../../domain/models/rule_humanizer.dart';
import '../../../core/theme/app_theme.dart';

/// Human-readable body for saved automation rules.
class RuleBodyBlock extends StatelessWidget {
  const RuleBodyBlock({
    required this.rule,
    this.deviceNames = const {},
    super.key,
  });

  final AutomationRule rule;
  final Map<String, String> deviceNames;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final language = automationRuleLanguageForCode(
      Localizations.localeOf(context).languageCode,
    );
    final sentence = humanizeAutomationRule(
      trigger: rule.trigger,
      actions: rule.actions,
      deviceNames: deviceNames,
      language: language,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        sentence,
        style: TextStyle(
          color: palette.textPrimary,
          height: 1.35,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
