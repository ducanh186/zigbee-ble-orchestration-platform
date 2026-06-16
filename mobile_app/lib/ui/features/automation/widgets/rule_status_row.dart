import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;

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
                label: _syncStatusLabel(l10n, syncStatus),
                tone: AutomationVisuals.syncTone(syncStatus),
              ),
              StatusBadge(
                label: _runStatusLabel(l10n, runStatus),
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

String _syncStatusLabel(AppLocalizations l10n, AutomationSyncStatus status) {
  return switch (status) {
    AutomationSyncStatus.pending => l10n.syncPendingStatus,
    AutomationSyncStatus.synced => l10n.syncSyncedStatus,
    AutomationSyncStatus.failed => l10n.syncFailedStatus,
  };
}

String _runStatusLabel(AppLocalizations l10n, AutomationLastRunStatus status) {
  return switch (status) {
    AutomationLastRunStatus.neverRun => l10n.runNeverStatus,
    AutomationLastRunStatus.executed => l10n.runExecutedStatus,
    AutomationLastRunStatus.failed => l10n.runFailedStatus,
    AutomationLastRunStatus.timeout => l10n.runTimeoutStatus,
  };
}
