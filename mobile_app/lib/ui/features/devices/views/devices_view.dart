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
                      tooltip: 'Back',
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
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
                    const AppCard(child: Text('No matching device found.'))
                  else
                    for (final device in filteredDevices) ...[
                      _DeviceRow(
                        device: device,
                        onTap: device.isLight
                            ? () => widget.onOpenLight(device)
                            : null,
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
    final matchesType = _type == 'all' || device.deviceType == _type;
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
                  tooltip: 'Clear search',
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
      _DeviceFilter('motion', 'Motion', Icons.sensors),
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
  const _DeviceRow({required this.device, this.onTap});

  final SmartDevice device;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final icon = switch (device.deviceType) {
      'light' =>
        device.power == DevicePower.on
            ? Icons.lightbulb
            : Icons.lightbulb_outline,
      'motion' => Icons.sensors,
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
                  '${device.id} - ${device.roomLabel}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          device.isLight
              ? StatusBadge.forPower(device.power)
              : StatusBadge(
                  label: device.isOnline ? 'ONLINE' : 'OFFLINE',
                  tone: device.isOnline ? BadgeTone.success : BadgeTone.warning,
                ),
        ],
      ),
    );
  }
}
