import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/room.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/localized_error_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/section_title.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';

class RoomsView extends StatelessWidget {
  const RoomsView({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.palette;

    return Consumer<DeviceDashboardViewModel>(
      builder: (context, dashboard, _) {
        final rooms = dashboard.rooms;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(l10n.roomsTitle),
                pinned: true,
                leading: IconButton(
                  tooltip: l10n.backLabel,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverList.list(
                  children: [
                    if (dashboard.errorMessage != null) ...[
                      ErrorBanner(
                        message: localizedErrorMessage(
                          l10n,
                          dashboard.errorMessage!,
                        ),
                        onRetry: dashboard.load,
                      ),
                      const SizedBox(height: 12),
                    ],
                    SectionTitle(title: l10n.roomsTitle),
                    const SizedBox(height: 8),
                    if (rooms.isEmpty)
                      AppCard(
                        child: Text(
                          l10n.noRoomsAvailable,
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      )
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var index = 0; index < rooms.length; index++)
                              _RoomRow(
                                room: rooms[index],
                                showDivider: index < rooms.length - 1,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('create-room-button'),
            onPressed: dashboard.isMutatingRoom
                ? null
                : () => _showRoomNameDialog(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.createRoomLabel),
          ),
        );
      },
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.room, required this.showDivider});

  final Room room;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.palette;
    final dashboard = context.read<DeviceDashboardViewModel>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.meeting_room_outlined, color: palette.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.renameRoomLabel,
                icon: const Icon(Icons.edit_outlined),
                onPressed: dashboard.isMutatingRoom
                    ? null
                    : () => _showRoomNameDialog(context, room: room),
              ),
              IconButton(
                tooltip: l10n.deleteLabel,
                color: palette.error,
                icon: const Icon(Icons.delete_outline),
                onPressed: dashboard.isMutatingRoom
                    ? null
                    : () => _confirmDeleteRoom(context, room),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(color: palette.border, height: 1),
      ],
    );
  }
}

Future<void> _showRoomNameDialog(BuildContext context, {Room? room}) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: room?.name ?? '');
  final dashboard = context.read<DeviceDashboardViewModel>();
  final name = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(room == null ? l10n.createRoomLabel : l10n.renameRoomLabel),
        content: TextField(
          key: const Key('room-name-field'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.roomNameLabel),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.saveLabel),
          ),
        ],
      );
    },
  );
  controller.dispose();

  final normalized = name?.trim();
  if (normalized == null || normalized.isEmpty) {
    return;
  }
  if (room == null) {
    await dashboard.createRoom(normalized);
  } else {
    await dashboard.renameRoom(roomId: room.id, name: normalized);
  }
}

Future<void> _confirmDeleteRoom(BuildContext context, Room room) async {
  final l10n = AppLocalizations.of(context)!;
  final dashboard = context.read<DeviceDashboardViewModel>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.deleteRoomTitle),
        content: Text(l10n.deleteRoomBody(room.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteLabel),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await dashboard.deleteRoom(room.id);
  }
}
