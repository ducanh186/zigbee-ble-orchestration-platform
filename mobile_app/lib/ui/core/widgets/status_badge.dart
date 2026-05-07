import 'package:flutter/material.dart';

import '../../../domain/models/command_status.dart';
import '../../../domain/models/device_power.dart';
import '../theme/app_theme.dart';

enum BadgeTone { neutral, primary, success, warning, error }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    this.tone = BadgeTone.neutral,
    this.showDot = true,
    super.key,
  });

  factory StatusBadge.forPower(DevicePower power) {
    return StatusBadge(
      label: power.label,
      tone: switch (power) {
        DevicePower.on => BadgeTone.success,
        DevicePower.off => BadgeTone.neutral,
        DevicePower.unreachable => BadgeTone.warning,
        DevicePower.unknown => BadgeTone.warning,
      },
    );
  }

  factory StatusBadge.forCommand(CommandStatus status) {
    return StatusBadge(
      label: status.label,
      tone: switch (status) {
        CommandStatus.executed => BadgeTone.success,
        CommandStatus.failed => BadgeTone.error,
        CommandStatus.timeout => BadgeTone.warning,
        CommandStatus.accepted ||
        CommandStatus.queued ||
        CommandStatus.sent => BadgeTone.primary,
        CommandStatus.idle => BadgeTone.neutral,
      },
      showDot: status != CommandStatus.idle,
    );
  }

  final String label;
  final BadgeTone tone;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = switch (tone) {
      BadgeTone.neutral => (palette.textSecondary, const Color(0x1F6B7280)),
      BadgeTone.primary => (palette.primary, palette.primaryTint),
      BadgeTone.success => (palette.success, palette.successTint),
      BadgeTone.warning => (palette.warning, palette.warningTint),
      BadgeTone.error => (palette.error, palette.errorTint),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colors.$1,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: colors.$1,
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
