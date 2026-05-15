import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/device_power.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/status_badge.dart';
import '../view_models/device_dashboard_view_model.dart';

class DevicesView extends StatelessWidget {
  const DevicesView({required this.onOpenLight, this.onBack, super.key});

  final ValueChanged<SmartDevice> onOpenLight;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceDashboardViewModel>(
      builder: (context, viewModel, _) {
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList.separated(
                itemCount:
                    viewModel.devices.length +
                    (viewModel.errorMessage == null ? 0 : 1),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (viewModel.errorMessage != null && index == 0) {
                    return ErrorBanner(
                      message: viewModel.errorMessage!,
                      onRetry: viewModel.load,
                    );
                  }

                  final offset = viewModel.errorMessage == null
                      ? index
                      : index - 1;
                  final device = viewModel.devices[offset];

                  return _DeviceRow(
                    device: device,
                    viewModel: viewModel,
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
  const _DeviceRow({required this.device, required this.viewModel, this.onTap});

  final SmartDevice device;
  final DeviceDashboardViewModel viewModel;
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(width: 12),
          _DeviceActions(device: device, viewModel: viewModel),
        ],
      ),
    );
  }
}

class _DeviceActions extends StatelessWidget {
  const _DeviceActions({required this.device, required this.viewModel});

  final SmartDevice device;
  final DeviceDashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (!device.isLight) {
      return StatusBadge(
        label: device.isOnline ? 'ONLINE' : 'OFFLINE',
        tone: device.isOnline ? BadgeTone.success : BadgeTone.warning,
      );
    }

    final isPending =
        viewModel.hasPendingCommand &&
        viewModel.lastCommand?.deviceId == device.id;
    final canCommand = device.isReachable && !viewModel.hasPendingCommand;
    final showOnSpinner = isPending && viewModel.lastTarget == DevicePower.on;
    final showOffSpinner = isPending && viewModel.lastTarget == DevicePower.off;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        StatusBadge.forPower(device.power),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 58,
              child: FilledButton(
                onPressed: canCommand
                    ? () => viewModel.setLightPower(device, DevicePower.on)
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(58, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: showOnSpinner
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ON'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 58,
              child: OutlinedButton(
                onPressed: canCommand
                    ? () => viewModel.setLightPower(device, DevicePower.off)
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(58, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: showOffSpinner
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('OFF'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
