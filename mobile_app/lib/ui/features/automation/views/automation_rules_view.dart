import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';

class AutomationRulesView extends StatelessWidget {
  const AutomationRulesView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('Automation Rules'), pinned: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverList.list(
            children: [
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: palette.primaryTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.rule, color: palette.primary),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rule setup placeholder',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Automation API is not connected in this build.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Draft rule shape'),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RulePreviewLine(
                      icon: Icons.sensors,
                      label: 'When',
                      value: 'Motion or switch event',
                      color: palette.primary,
                    ),
                    const SizedBox(height: 12),
                    _RulePreviewLine(
                      icon: Icons.lightbulb_outline,
                      label: 'Then',
                      value: 'Turn LIGHT node on or off',
                      color: palette.warning,
                    ),
                    const SizedBox(height: 12),
                    _RulePreviewLine(
                      icon: Icons.schedule_outlined,
                      label: 'Mode',
                      value: 'Disabled until backend rules exist',
                      color: palette.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RulePreviewLine extends StatelessWidget {
  const _RulePreviewLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        SizedBox(
          width: 48,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
