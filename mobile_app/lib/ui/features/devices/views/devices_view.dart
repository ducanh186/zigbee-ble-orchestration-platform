import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../domain/models/device_power.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/status_badge.dart';
import '../view_models/device_dashboard_view_model.dart';

class DevicesView extends StatefulWidget {
  const DevicesView({required this.onOpenLight, this.onBack, super.key});

  final ValueChanged<SmartDevice> onOpenLight;
  final VoidCallback? onBack;

  @override
  State<DevicesView> createState() => _DevicesViewState();
}

class _DevicesViewState extends State<DevicesView> {
  String _query = '';
  String _type = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<DeviceDashboardViewModel>(
      builder: (context, viewModel, _) {
        final filteredDevices = viewModel.devices
            .where(_matchesDevice)
            .toList();

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(l10n.devicesTitle),
              pinned: true,
              leading: widget.onBack == null
                  ? null
                  : IconButton(
                      tooltip: l10n.backLabel,
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
              actions: [
                IconButton(
                  tooltip: l10n.refreshTooltip,
                  onPressed: viewModel.load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList.list(
                children: [
                  if (viewModel.errorMessage != null) ...[
                    ErrorBanner(
                      message: viewModel.errorMessage!,
                      onRetry: viewModel.load,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _DeviceSearchBar(
                    query: _query,
                    hintText: l10n.searchDevices,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 10),
                  _DeviceTypeFilters(
                    selectedType: _type,
                    onSelected: (value) => setState(() => _type = value),
                  ),
                  const SizedBox(height: 12),
                  if (filteredDevices.isEmpty)
                    AppCard(child: Text(l10n.noMatchingDeviceMessage))
                  else
                    for (final device in filteredDevices) ...[
                      _DeviceRow(
                        device: device,
                        roomName: viewModel.roomNameFor(device.roomId),
                        onTap: () => widget.onOpenLight(device),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  bool _matchesDevice(SmartDevice device) {
    final normalizedQuery = _query.trim().toLowerCase();
    // The "sensor" filter matches v2 'sensor'+kind devices and legacy
    // 'motion'/'environment' rows (isMotion/isEnvironment dual-read).
    final matchesType =
        _type == 'all' ||
        (_type == 'sensor'
            ? (device.isMotion || device.isEnvironment)
            : device.deviceType == _type);
    final matchesQuery =
        normalizedQuery.isEmpty ||
        device.name.toLowerCase().contains(normalizedQuery) ||
        device.id.toLowerCase().contains(normalizedQuery) ||
        device.roomLabel.toLowerCase().contains(normalizedQuery);

    return matchesType && matchesQuery;
  }
}

class _DeviceSearchBar extends StatelessWidget {
  const _DeviceSearchBar({
    required this.query,
    required this.hintText,
    required this.onChanged,
  });

  final String query;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.clearSearchTooltip,
                  onPressed: () => onChanged(''),
                  icon: const Icon(Icons.close),
                ),
          border: InputBorder.none,
          hintStyle: TextStyle(color: palette.textSecondary),
        ),
      ),
    );
  }
}

class _DeviceTypeFilters extends StatelessWidget {
  const _DeviceTypeFilters({
    required this.selectedType,
    required this.onSelected,
  });

  final String selectedType;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final filters = const [
      _DeviceFilter('all', 'All', Icons.grid_view_rounded),
      _DeviceFilter('light', 'Light', Icons.lightbulb_outline),
      _DeviceFilter('sensor', 'Sensors', Icons.sensors),
      _DeviceFilter('switch', 'Switch', Icons.toggle_off),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            FilterChip(
              avatar: Icon(filter.icon, size: 16),
              label: Text(filter.label),
              selected: selectedType == filter.type,
              onSelected: (_) => onSelected(filter.type),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DeviceFilter {
  const _DeviceFilter(this.type, this.label, this.icon);

  final String type;
  final String label;
  final IconData icon;
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.roomName, this.onTap});

  final SmartDevice device;
  final String roomName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final icon = switch (device.deviceType) {
      'light' =>
        device.power == DevicePower.on
            ? Icons.lightbulb
            : Icons.lightbulb_outline,
      'motion' || 'sensor' => Icons.sensors,
      'switch' => Icons.toggle_off,
      _ => Icons.help_outline,
    };

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: device.power == DevicePower.on
                  ? palette.warningTint
                  : const Color(0x1F6B7280),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: device.power == DevicePower.on
                  ? palette.warning
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
                  roomName,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          _DeviceStatusBadge(device: device),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 18, color: palette.textSecondary),
        ],
      ),
    );
  }
}

class _DeviceStatusBadge extends StatelessWidget {
  const _DeviceStatusBadge({required this.device});

  final SmartDevice device;

  @override
  Widget build(BuildContext context) {
    if (device.isLight) {
      return StatusBadge.forPower(device.power);
    }
    if (device.isMotion) {
      return StatusBadge(
        label: device.occupancy.label,
        tone: switch (device.occupancy) {
          OccupancyState.occupied => BadgeTone.success,
          OccupancyState.unoccupied => BadgeTone.neutral,
          OccupancyState.unknown => BadgeTone.warning,
        },
      );
    }
    return StatusBadge(
      label: device.isOnline ? 'ONLINE' : 'OFFLINE',
      tone: device.isOnline ? BadgeTone.success : BadgeTone.warning,
    );
  }
}
