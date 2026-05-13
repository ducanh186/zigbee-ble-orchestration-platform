import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/command_status.dart';
import '../../../../domain/models/device_power.dart';
import '../../../../domain/models/event_log.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/status_badge.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';

class LightDetailView extends StatelessWidget {
  const LightDetailView({
    required this.device,
    required this.onBack,
    super.key,
  });

  final SmartDevice device;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceDashboardViewModel>(
      builder: (context, viewModel, _) {
        final current = viewModel.deviceById(device.id) ?? device;
        final recentEvents = viewModel.events
            .where((event) => event.deviceId == current.id)
            .take(3)
            .toList();

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Light detail'),
              pinned: true,
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: viewModel.load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList.list(
                children: [
                  _LightHeroCard(device: current, viewModel: viewModel),
                  const SizedBox(height: 12),
                  _LastCommandCard(viewModel: viewModel),
                  const SizedBox(height: 18),
                  const SectionTitle(title: 'Recent events'),
                  const SizedBox(height: 8),
                  _RecentEvents(events: recentEvents),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LightHeroCard extends StatelessWidget {
  const _LightHeroCard({required this.device, required this.viewModel});

  final SmartDevice device;
  final DeviceDashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isOn = device.power == DevicePower.on;
    final canCommand = device.isReachable && !viewModel.hasPendingCommand;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: isOn ? palette.warningTint : const Color(0x1F6B7280),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              isOn ? Icons.lightbulb : Icons.lightbulb_outline,
              color: isOn ? palette.warning : palette.textSecondary,
              size: 48,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            device.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '${device.id} - ${device.roomLabel}',
            style: TextStyle(
              color: palette.textSecondary,
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatusBadge.forPower(device.power),
              if (device.reportedAt != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    device.reportedAt!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: canCommand
                      ? () => viewModel.setLightPower(device, DevicePower.on)
                      : null,
                  icon: viewModel.hasPendingCommand
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.power_settings_new),
                  label: const Text('ON'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canCommand
                      ? () => viewModel.setLightPower(device, DevicePower.off)
                      : null,
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('OFF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LastCommandCard extends StatelessWidget {
  const _LastCommandCard({required this.viewModel});

  final DeviceDashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final command = viewModel.lastCommand;
    final status = command?.status ?? CommandStatus.idle;
    final message = switch (status) {
      CommandStatus.accepted => 'Sent to Cloud API',
      CommandStatus.queued => 'Queued by gateway',
      CommandStatus.sent => 'Waiting for device reply',
      CommandStatus.executed => 'Acknowledged by gateway',
      CommandStatus.failed => command?.reason ?? 'Command failed',
      CommandStatus.timeout => 'No reply within polling window',
      CommandStatus.idle => 'No active command',
    };

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Last command'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      command?.id ?? 'none',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge.forCommand(status),
            ],
          ),
          if (status == CommandStatus.failed || status == CommandStatus.timeout)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: viewModel.retryLastCommand,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    'Retry ${viewModel.lastTarget?.label ?? ''}'.trim(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentEvents extends StatelessWidget {
  const _RecentEvents({required this.events});

  final List<EventLog> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const AppCard(child: Text('No recent event for this LIGHT.'));
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < events.length; index++)
            _EventRow(event: events[index], showBorder: index != 0),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.showBorder});

  final EventLog event;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
          SizedBox(
            width: 74,
            child: Text(
              event.occurredAt,
              style: TextStyle(
                color: palette.textSecondary,
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
              ),
            ),
          ),
          Icon(Icons.check_circle_outline, color: palette.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.message, style: const TextStyle(fontSize: 13)),
                if (event.commandId != null)
                  Text(
                    'command_id=${event.commandId}',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
