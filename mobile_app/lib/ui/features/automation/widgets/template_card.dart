import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../core/theme/app_theme.dart';
import 'automation_visuals.dart';

/// Single template tile in the create sheet's 2x2 grid. Tinted + checkmark
/// when selected.
class TemplateCard extends StatelessWidget {
  const TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AutomationRuleTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: selected ? palette.primaryTint : palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? palette.primary : palette.border,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: selected
                          ? palette.primary
                          : palette.primaryTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      AutomationVisuals.templateIcon(template),
                      size: 14,
                      color: selected ? palette.primaryOn : palette.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      template.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check, size: 14, color: palette.primary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                template.actionLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono',
                  color: palette.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
