import 'package:flutter/material.dart';

import '../../../../domain/models/event_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_badge.dart';

/// Single notification row in the mobile notification center.
///
/// Stateless. Reads only what [EventLog] already exposes — title (event type
/// + device id), human-readable category badge, monospaced timestamp, and a
/// secondary line for the cloud-derived message + correlation hints
/// (source, command_id). The badge tone is driven by
/// [EventLog.category]:
///
/// - [EventCategory.motion] → primary (info-blue)
/// - [EventCategory.automationExecuted] → success (green)
/// - [EventCategory.automationFailed] → error (red)
/// - [EventCategory.other] → neutral (grey)
class NotificationEventTile extends StatelessWidget {
  const NotificationEventTile({
    required this.event,
    this.showBorder = false,
    super.key,
  });

  final EventLog event;

  /// Render a top border above the tile so a vertical list of tiles inside an
  /// [AppCard] gets dividers between rows. The first tile in a list should
  /// pass `false` so the card edge alone defines the top.
  final bool showBorder;

  String get _badgeLabel => switch (event.category) {
    EventCategory.motion => 'Motion',
    EventCategory.automationExecuted => 'Automation',
    EventCategory.automationFailed => 'Failed',
    EventCategory.other => 'Event',
  };

  BadgeTone get _badgeTone => switch (event.category) {
    EventCategory.motion => BadgeTone.primary,
    EventCategory.automationExecuted => BadgeTone.success,
    EventCategory.automationFailed => BadgeTone.error,
    EventCategory.other => BadgeTone.neutral,
  };

  IconData get _icon => switch (event.category) {
    EventCategory.motion => Icons.sensors,
    EventCategory.automationExecuted => Icons.check_circle_outline,
    EventCategory.automationFailed => Icons.error_outline,
    EventCategory.other => Icons.bolt_outlined,
  };

  Color _iconColor(AppPalette palette) => switch (event.category) {
    EventCategory.motion => palette.primary,
    EventCategory.automationExecuted => palette.success,
    EventCategory.automationFailed => palette.error,
    EventCategory.other => palette.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = '${event.eventType} ${event.deviceId ?? ''}'.trim();
    final correlation = [
      if (event.source != null) 'source=${event.source}',
      if (event.commandId != null) 'command_id=${event.commandId}',
    ].join(' - ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: showBorder
            ? Border(top: BorderSide(color: palette.border))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _iconColor(palette), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(label: _badgeLabel, tone: _badgeTone),
                  ],
                ),
                const SizedBox(height: 4),
                Text(event.message, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  event.occurredAt,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                  ),
                ),
                if (correlation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    correlation,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
