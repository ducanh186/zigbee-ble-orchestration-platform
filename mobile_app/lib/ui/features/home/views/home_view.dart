import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../domain/models/device_power.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/status_badge.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';
import '../widgets/environment_metric_card.dart';
import '../widgets/gateway_status_card.dart';

class HomeView extends StatelessWidget {
  const HomeView({
    required this.onOpenLight,
    required this.onOpenDevices,
    super.key,
  });

  final ValueChanged<SmartDevice> onOpenLight;
  final VoidCallback onOpenDevices;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<DeviceDashboardViewModel>(
      builder: (context, viewModel, _) {
        SmartDevice? environmentSensor;
        for (final device in viewModel.devices) {
          if (device.isEnvironment) {
            environmentSensor = device;
            break;
          }
        }

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(l10n.homeTab),
              pinned: true,
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
                  GatewayStatusCard(status: viewModel.cloudStatus),
                  const SizedBox(height: 12),
                  _MetricRow(
                    viewModel: viewModel,
                    onOpenDevices: onOpenDevices,
                  ),
                  if (environmentSensor != null) ...[
                    const SizedBox(height: 18),
                    SectionTitle(title: l10n.environmentTitle),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: EnvironmentMetricCard(
                            icon: Icons.thermostat_outlined,
                            value: environmentSensor.temperatureC,
                            unit: '°C',
                            label: l10n.temperatureLabel,
                            sensorLabel:
                                environmentSensor.sensorKind?.toUpperCase() ??
                                environmentSensor.name,
                            sourceLabel: l10n.zigbeeLocalLabel,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: EnvironmentMetricCard(
                            icon: Icons.water_drop_outlined,
                            value: environmentSensor.humidityPercent,
                            unit: '%',
                            label: l10n.humidityLabel,
                            sensorLabel:
                                environmentSensor.sensorKind?.toUpperCase() ??
                                environmentSensor.name,
                            sourceLabel: l10n.zigbeeLocalLabel,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  SectionTitle(title: l10n.quickLightsTitle),
                  const SizedBox(height: 8),
                  _QuickLightGrid(
                    lights: viewModel.lights.take(4).toList(),
                    onOpenLight: onOpenLight,
                  ),
                  if (viewModel.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 18),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.viewModel, required this.onOpenDevices});

  final DeviceDashboardViewModel viewModel;
  final VoidCallback onOpenDevices;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: l10n.devicesMetricLabel,
            value: viewModel.devices.length,
            onTap: onOpenDevices,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: l10n.onlineMetricLabel,
            value: viewModel.onlineCount,
            tone: BadgeTone.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: l10n.unreachableMetricLabel,
            value: viewModel.unreachableCount,
            tone: BadgeTone.warning,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.tone = BadgeTone.neutral,
    this.onTap,
  });

  final String label;
  final int value;
  final BadgeTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = switch (tone) {
      BadgeTone.success => palette.success,
      BadgeTone.warning => palette.warning,
      BadgeTone.error => palette.error,
      BadgeTone.primary => palette.primary,
      BadgeTone.neutral => palette.textSecondary,
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLightGrid extends StatelessWidget {
  const _QuickLightGrid({required this.lights, required this.onOpenLight});

  final List<SmartDevice> lights;
  final ValueChanged<SmartDevice> onOpenLight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (lights.isEmpty) {
      return AppCard(child: Text(l10n.noLightNodeMessage));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lights.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final light = lights[index];
        return AppCard(
          onTap: () => onOpenLight(light),
          child: _LightTile(light: light),
        );
      },
    );
  }
}

class _LightTile extends StatelessWidget {
  const _LightTile({required this.light});

  final SmartDevice light;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isOn = light.power == DevicePower.on;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isOn ? palette.warningTint : const Color(0x1F6B7280),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                color: isOn ? palette.warning : palette.textSecondary,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StatusBadge.forPower(light.power),
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          light.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          light.id,
          style: TextStyle(
            color: palette.textSecondary,
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
