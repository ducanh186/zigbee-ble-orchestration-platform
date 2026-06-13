import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../domain/models/cloud_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';

class GatewayStatusCard extends StatelessWidget {
  const GatewayStatusCard({required this.status, super.key});

  final CloudStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final presentation = _GatewayStatusPresentation.from(status, l10n);

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: presentation.iconBackground(palette),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.router, color: presentation.iconColor(palette)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  presentation.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(label: presentation.badgeLabel, tone: presentation.tone),
        ],
      ),
    );
  }
}

class _GatewayStatusPresentation {
  const _GatewayStatusPresentation({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.tone,
  });

  factory _GatewayStatusPresentation.from(
    CloudStatus status,
    AppLocalizations l10n,
  ) {
    final logTime = status.occurredAt == null
        ? ''
        : l10n.gatewayLastReport(status.occurredAt!);
    final eventType = status.eventType == null ? '' : ' (${status.eventType})';
    final latestReport = logTime.isEmpty && eventType.isEmpty
        ? l10n.gatewayLatestEvent
        : '$logTime$eventType';

    return switch (status.state) {
      CloudConnectionState.online => _GatewayStatusPresentation(
        title: l10n.gatewayOnlineTitle,
        subtitle: latestReport,
        badgeLabel: 'LOG',
        tone: BadgeTone.success,
      ),
      CloudConnectionState.offline => _GatewayStatusPresentation(
        title: l10n.gatewayOfflineTitle,
        subtitle: status.detail ?? latestReport,
        badgeLabel: 'OFF',
        tone: BadgeTone.error,
      ),
      CloudConnectionState.unknown => _GatewayStatusPresentation(
        title: l10n.gatewayUnknownTitle,
        subtitle: status.detail ?? l10n.gatewayNoStatus,
        badgeLabel: 'CHECK',
        tone: BadgeTone.warning,
      ),
      CloudConnectionState.mock => _GatewayStatusPresentation(
        title: l10n.gatewayMockTitle,
        subtitle: latestReport,
        badgeLabel: 'MOCK',
        tone: BadgeTone.neutral,
      ),
    };
  }

  final String title;
  final String subtitle;
  final String badgeLabel;
  final BadgeTone tone;

  Color iconColor(AppPalette palette) {
    return switch (tone) {
      BadgeTone.success => palette.success,
      BadgeTone.warning => palette.warning,
      BadgeTone.error => palette.error,
      BadgeTone.primary => palette.primary,
      BadgeTone.neutral => palette.textSecondary,
    };
  }

  Color iconBackground(AppPalette palette) {
    return switch (tone) {
      BadgeTone.success => palette.successTint,
      BadgeTone.warning => palette.warningTint,
      BadgeTone.error => palette.errorTint,
      BadgeTone.primary => palette.primaryTint,
      BadgeTone.neutral => const Color(0x1F6B7280),
    };
  }
}

@Preview(
  name: 'Online from cloud log',
  group: 'Home hub status',
  size: Size(390, 120),
)
Widget gatewayStatusOnlinePreview() {
  return _GatewayStatusPreviewShell(
    status: const CloudStatus.online(
      gatewayId: 'gw-ubuntu-01',
      eventType: 'gateway_online',
      occurredAt: '10:11 05/07/2026',
    ),
  );
}

@Preview(name: 'No home hub log', group: 'Home hub status', size: Size(390, 120))
Widget gatewayStatusUnknownPreview() {
  return _GatewayStatusPreviewShell(
    status: const CloudStatus.unknown(
      detail: 'No home hub status log found in cloud events',
    ),
  );
}

class _GatewayStatusPreviewShell extends StatelessWidget {
  const _GatewayStatusPreviewShell({required this.status});

  final CloudStatus status;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(AppThemeMode.light),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: GatewayStatusCard(status: status),
        ),
      ),
    );
  }
}
