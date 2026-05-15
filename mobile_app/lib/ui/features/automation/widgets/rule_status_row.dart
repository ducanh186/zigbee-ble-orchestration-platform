import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_badge.dart';
import 'automation_visuals.dart';

/// Sync + last-run status chip pair. Always renders both — design rule #3
/// ("Hai status chip, luôn luôn").
class RuleStatusRow extends StatelessWidget {
  const RuleStatusRow({
    required this.syncStatus,
    required this.runStatus,
    this.lastRunAt,
    super.key,
  });

  final AutomationSyncStatus syncStatus;
  final AutomationLastRunStatus runStatus;
  final String? lastRunAt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                label: syncStatus.label,
                tone: AutomationVisuals.syncTone(syncStatus),
              ),
              StatusBadge(
                label: runStatus.label,
                tone: AutomationVisuals.runTone(runStatus),
                showDot: false,
              ),
            ],
          ),
        ),
        if (lastRunAt != null && lastRunAt!.isNotEmpty)
          Text(
            lastRunAt!,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'JetBrains Mono',
              color: palette.textSecondary,
            ),
          ),
      ],
    );
  }
}
