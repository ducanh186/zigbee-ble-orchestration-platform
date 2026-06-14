import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/command_status.dart';
import '../../../../domain/models/device_power.dart';
import '../../../../domain/models/event_log.dart';
import '../../../../domain/models/room.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/localized_error_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/status_badge.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';

class DeviceDetailView extends StatefulWidget {
  const DeviceDetailView({
    required this.device,
    required this.onBack,
    super.key,
  });

  final SmartDevice device;
  final VoidCallback onBack;

  @override
  State<DeviceDetailView> createState() => _DeviceDetailViewState();
}

class _DeviceDetailViewState extends State<DeviceDetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<DeviceDashboardViewModel>().loadDeviceEvents(
        widget.device.id,
      );
    });
  }

  @override
  void didUpdateWidget(covariant DeviceDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.id != widget.device.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<DeviceDashboardViewModel>().loadDeviceEvents(
          widget.device.id,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceDashboardViewModel>(
      builder: (context, viewModel, _) {
        final l10n = AppLocalizations.of(context)!;
        final current = viewModel.deviceById(widget.device.id) ?? widget.device;
        final recentEvents = viewModel.eventsForDevice(current.id);

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(l10n.deviceDetailTitle),
              pinned: true,
              leading: IconButton(
                tooltip: l10n.backLabel,
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              actions: [
                IconButton(
                  tooltip: l10n.renameDeviceLabel,
                  onPressed: viewModel.isRenamingDevice
                      ? null
                      : () => _renameDevice(context, viewModel, current),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: l10n.moveRoomLabel,
                  onPressed: viewModel.isMovingDevice
                      ? null
                      : () => _moveDevice(context, viewModel, current),
                  icon: const Icon(Icons.drive_file_move_outlined),
                ),
                IconButton(
                  tooltip: l10n.refreshTooltip,
                  onPressed: () => _refresh(viewModel, current.id),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList.list(
                children: [
                  _DeviceHeroCard(device: current, viewModel: viewModel),
                  if (current.isLight) ...[
                    const SizedBox(height: 12),
                    _LastCommandCard(viewModel: viewModel),
                  ] else ...[
                    const SizedBox(height: 12),
                    _DeviceInfoCard(
                      device: current,
                      roomName: viewModel.roomNameFor(current.roomId),
                    ),
                  ],
                  if (current.isMotion) ...[
                    const SizedBox(height: 18),
                    _OccupancyTimeline(events: recentEvents),
                  ],
                  const SizedBox(height: 18),
                  SectionTitle(title: l10n.recentEventsTitle),
                  const SizedBox(height: 8),
                  _RecentEvents(
                    events: recentEvents,
                    isLoading: viewModel.isLoadingDeviceEvents(current.id),
                    errorMessage: viewModel.deviceEventsError(current.id),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refresh(
    DeviceDashboardViewModel viewModel,
    String deviceId,
  ) async {
    await viewModel.load();
    await viewModel.loadDeviceEvents(deviceId);
  }

  Future<void> _renameDevice(
    BuildContext context,
    DeviceDashboardViewModel viewModel,
    SmartDevice device,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDeviceDialog(initialName: device.name),
    );
    if (!mounted || name == null) {
      return;
    }
    await viewModel.renameDevice(device, name);
  }

  Future<void> _moveDevice(
    BuildContext context,
    DeviceDashboardViewModel viewModel,
    SmartDevice device,
  ) async {
    final roomId = await showDialog<String>(
      context: context,
      builder: (_) => _MoveRoomDialog(
        rooms: viewModel.rooms,
        selectedRoomId: device.roomId,
      ),
    );
    if (!mounted || roomId == null) {
      return;
    }
    await viewModel.moveDevice(device, roomId);
  }
}

class _MoveRoomDialog extends StatefulWidget {
  const _MoveRoomDialog({required this.rooms, required this.selectedRoomId});

  final List<Room> rooms;
  final String? selectedRoomId;

  @override
  State<_MoveRoomDialog> createState() => _MoveRoomDialogState();
}

class _MoveRoomDialogState extends State<_MoveRoomDialog> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedRoomId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.moveRoomTitle),
      content: widget.rooms.isEmpty
          ? Text(l10n.noRoomsAvailable)
          : RadioGroup<String>(
              groupValue: _selected,
              onChanged: (value) => setState(() => _selected = value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final room in widget.rooms)
                    RadioListTile<String>(
                      key: ValueKey('move-room-${room.id}'),
                      title: Text(room.name),
                      value: room.id,
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelLabel),
        ),
        FilledButton(
          onPressed: (_selected == null || widget.rooms.isEmpty)
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: Text(l10n.saveLabel),
        ),
      ],
    );
  }
}

class _RenameDeviceDialog extends StatefulWidget {
  const _RenameDeviceDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDeviceDialog> createState() => _RenameDeviceDialogState();
}

class _RenameDeviceDialogState extends State<_RenameDeviceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.renameDeviceLabel),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.displayNameLabel),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.saveLabel),
        ),
      ],
    );
  }
}

class _DeviceHeroCard extends StatelessWidget {
  const _DeviceHeroCard({required this.device, required this.viewModel});

  final SmartDevice device;
  final DeviceDashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final isOn = device.power == DevicePower.on;
    final canCommand =
        device.isLight &&
        device.power.canCommand &&
        !viewModel.hasPendingCommand;
    final canTurnOn = canCommand && device.power != DevicePower.on;
    final canTurnOff = canCommand && device.power != DevicePower.off;

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
              _iconFor(device),
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
            viewModel.roomNameFor(device.roomId),
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              device.isLight
                  ? StatusBadge.forPower(device.power)
                  : StatusBadge(
                      label: device.isOnline
                          ? l10n.onlineLabel.toUpperCase()
                          : l10n.offlineLabel.toUpperCase(),
                      tone: device.isOnline
                          ? BadgeTone.success
                          : BadgeTone.warning,
                    ),
              if (device.isMotion) _OccupancyBadge(status: device.occupancy),
              if (device.reportedAt != null)
                Text(
                  device.reportedAt!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
            ],
          ),
          if (device.isLight) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canTurnOn
                        ? () => viewModel.setLightPower(device, DevicePower.on)
                        : null,
                    icon: viewModel.hasPendingCommand
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.power_settings_new),
                    label: Text(l10n.turnOnLabel.toUpperCase()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canTurnOff
                        ? () => viewModel.setLightPower(device, DevicePower.off)
                        : null,
                    icon: const Icon(Icons.power_settings_new),
                    label: Text(l10n.turnOffLabel.toUpperCase()),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(SmartDevice device) {
    return switch (device.deviceType) {
      'light' =>
        device.power == DevicePower.on
            ? Icons.lightbulb
            : Icons.lightbulb_outline,
      'motion' || 'sensor' => Icons.sensors,
      'switch' => Icons.toggle_off,
      _ => Icons.hub_outlined,
    };
  }
}

class _DeviceInfoCard extends StatelessWidget {
  const _DeviceInfoCard({required this.device, required this.roomName});

  final SmartDevice device;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _InfoRow(label: l10n.deviceTypeLabel, value: device.deviceType),
          _InfoRow(
            label: l10n.statusLabel,
            value: device.isOnline ? l10n.onlineLabel : l10n.offlineLabel,
          ),
          _InfoRow(label: l10n.roomLabel, value: roomName),
          if (device.isMotion)
            _InfoRow(
              label: l10n.occupancyLabel,
              value: _localizedOccupancy(device.occupancy, l10n),
            ),
          if (device.reportedAt != null)
            _InfoRow(label: l10n.reportedLabel, value: device.reportedAt!),
        ],
      ),
    );
  }
}

class _OccupancyBadge extends StatelessWidget {
  const _OccupancyBadge({required this.status});

  final OccupancyState status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StatusBadge(
      label: _localizedOccupancy(status, l10n),
      tone: switch (status) {
        OccupancyState.occupied => BadgeTone.success,
        OccupancyState.unoccupied => BadgeTone.neutral,
        OccupancyState.unknown => BadgeTone.warning,
      },
    );
  }
}

class _OccupancyTimeline extends StatelessWidget {
  const _OccupancyTimeline({required this.events});

  final List<EventLog> events;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final occupancyEvents = events.where(_isOccupancyEvent).toList();
    final latest = occupancyEvents.isEmpty ? null : occupancyEvents.first;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: l10n.occupancyTimelineTitle),
          const SizedBox(height: 8),
          Text(
            l10n.latestOccupancyLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            latest == null
                ? l10n.noEventYetMessage
                : _occupancyLabel(latest, l10n),
            style: TextStyle(color: context.palette.textSecondary),
          ),
          const SizedBox(height: 10),
          if (occupancyEvents.isEmpty)
            Text(
              l10n.noOccupancyEventMessage,
              style: TextStyle(color: context.palette.textSecondary),
            )
          else
            for (final event in occupancyEvents)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 74,
                      child: Text(
                        event.occurredAt,
                        style: TextStyle(
                          color: context.palette.textSecondary,
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.sensors,
                      color: context.palette.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_occupancyLabel(event, l10n))),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static bool _isOccupancyEvent(EventLog event) {
    final combined = '${event.eventType} ${event.message}'.toLowerCase();
    return combined.contains('occup');
  }

  static String _occupancyLabel(EventLog event, AppLocalizations l10n) {
    final status = OccupancyState.fromValue(event.message);
    if (status != OccupancyState.unknown) {
      return _localizedOccupancy(status, l10n);
    }
    return event.message;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
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
    final l10n = AppLocalizations.of(context)!;
    final command = viewModel.lastCommand;
    final status = command?.status ?? CommandStatus.idle;
    final message = switch (status) {
      CommandStatus.accepted => l10n.commandSentMessage,
      CommandStatus.queued => l10n.commandQueuedMessage,
      CommandStatus.sent => l10n.commandWaitingMessage,
      CommandStatus.executed => l10n.commandAcknowledgedMessage,
      CommandStatus.failed => command?.reason ?? l10n.commandFailedMessage,
      CommandStatus.timeout => l10n.commandTimeoutMessage,
      CommandStatus.idle => l10n.noActiveCommandMessage,
    };

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: l10n.lastCommandTitle),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      command?.id ?? l10n.noneLabel,
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
                    l10n.retryTargetLabel(viewModel.lastTarget?.label ?? ''),
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
  const _RecentEvents({
    required this.events,
    required this.isLoading,
    required this.errorMessage,
  });

  final List<EventLog> events;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading) {
      return const AppCard(
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (errorMessage != null) {
      return AppCard(child: Text(localizedErrorMessage(l10n, errorMessage!)));
    }
    if (events.isEmpty) {
      return AppCard(child: Text(l10n.noRecentEventMessage));
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
    final l10n = AppLocalizations.of(context)!;
    final message = _compactMessage(event, l10n);
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
                Text(message, style: const TextStyle(fontSize: 13)),
                Text(
                  event.eventType,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                  ),
                ),
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

  String _compactMessage(EventLog event, AppLocalizations l10n) {
    if (event.eventType == 'device_registry') {
      return l10n.deviceRegistryUpdatedMessage;
    }
    if (event.eventType == 'gateway_health') {
      return l10n.gatewayHealthUpdatedMessage;
    }
    if (event.message.length > 80) {
      return _humanize(event.eventType, l10n);
    }
    return event.message;
  }

  String _humanize(String value, AppLocalizations l10n) {
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) {
      return l10n.eventUpdatedMessage;
    }
    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

String _localizedOccupancy(OccupancyState status, AppLocalizations l10n) {
  return switch (status) {
    OccupancyState.occupied => l10n.occupancyOccupiedLabel,
    OccupancyState.unoccupied => l10n.occupancyUnoccupiedLabel,
    OccupancyState.unknown => l10n.occupancyUnknownLabel,
  };
}
