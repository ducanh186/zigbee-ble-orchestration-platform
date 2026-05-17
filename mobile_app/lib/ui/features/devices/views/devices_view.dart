import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/device_power.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/status_badge.dart';
import '../view_models/device_dashboard_view_model.dart';
import '../widgets/occupancy_status_card.dart';

class DevicesView extends StatelessWidget {
  const DevicesView({required this.onOpenLight, this.onBack, super.key});

  final ValueChanged<SmartDevice> onOpenLight;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceDashboardViewModel>(
      builder: (context, viewModel, _) {
        final motionDevices = viewModel.devices
            .where((device) => device.isMotion)
            .toList(growable: false);

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Devices'),
              pinned: true,
              leading: onBack == null
                  ? null
                  : IconButton(
                      tooltip: 'Back',
                      onPressed: onBack,
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
            if (viewModel.errorMessage != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: ErrorBanner(
                    message: viewModel.errorMessage!,
                    onRetry: viewModel.load,
                  ),
                ),
              ),
            if (motionDevices.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle(title: 'Occupancy'),
                      const SizedBox(height: 8),
                      for (final motion in motionDevices) ...[
                        OccupancyStatusCard(device: motion),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList.separated(
                itemCount: viewModel.devices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final device = viewModel.devices[index];
                  return _DeviceRow(
                    device: device,
                    onTap: device.isLight ? () => onOpenLight(device) : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
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
