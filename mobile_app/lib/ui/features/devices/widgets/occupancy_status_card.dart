import 'package:flutter/material.dart';

import '../../../../domain/models/occupancy_state.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';

/// Per-motion-sensor occupancy summary card.
///
/// Renders the sensor's room and name, a [StatusBadge] coloured for the
/// current [OccupancyState] (occupied → success, unoccupied → neutral,
/// unknown → warning) and a relative "last reported" timestamp. Stateless
/// and reads only what [DeviceDashboardViewModel] already exposes — no new
/// backend calls.
class OccupancyStatusCard extends StatelessWidget {
  const OccupancyStatusCard({
    required this.device,
    this.now,
    super.key,
  });

  final SmartDevice device;

  /// Override for the current wall-clock time. Tests inject a fixed value so
  /// the "X phut truoc" label is deterministic; production callers leave it
  /// `null` to use [DateTime.now].
  final DateTime? now;

  OccupancyState get _state => device.occupancy ?? OccupancyState.unknown;

  String get _stateLabel => switch (_state) {
    OccupancyState.occupied => 'Co nguoi',
    OccupancyState.unoccupied => 'Vang',
    OccupancyState.unknown => 'Khong xac dinh',
  };

  String get _badgeLabel => switch (_state) {
    OccupancyState.occupied => 'OCCUPIED',
    OccupancyState.unoccupied => 'CLEAR',
    OccupancyState.unknown => 'UNKNOWN',
  };

  BadgeTone get _tone => switch (_state) {
    OccupancyState.occupied => BadgeTone.success,
    OccupancyState.unoccupied => BadgeTone.neutral,
    OccupancyState.unknown => BadgeTone.warning,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _state == OccupancyState.occupied
                  ? palette.successTint
                  : const Color(0x1F6B7280),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.sensors,
              color: _state == OccupancyState.occupied
                  ? palette.success
                  : palette.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.roomLabel} - $_stateLabel',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _timestampLabel(),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(label: _badgeLabel, tone: _tone),
        ],
      ),
    );
  }

  String _timestampLabel() {
    final reportedAt = device.reportedAt;
    if (reportedAt == null || reportedAt.isEmpty) {
      return 'Chua co du lieu';
    }
    final parsed = DateTime.tryParse(reportedAt);
    if (parsed == null) {
      // Fall back to the raw cloud string when it isn't ISO-8601 (mock data
      // uses a human-readable timestamp).
      return reportedAt;
    }
    final reference = (now ?? DateTime.now()).toUtc();
    final delta = reference.difference(parsed.toUtc());
    if (delta.isNegative) {
      return 'Vua moi';
    }
    if (delta.inSeconds < 60) {
      return 'Vua moi';
    }
    if (delta.inMinutes < 60) {
      return '${delta.inMinutes} phut truoc';
    }
    if (delta.inHours < 24) {
      return '${delta.inHours} gio truoc';
    }
    return '${delta.inDays} ngay truoc';
  }
}
