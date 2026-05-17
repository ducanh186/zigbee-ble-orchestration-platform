import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app_runtime_config.dart';
import '../../../../domain/models/ota_campaign.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/status_badge.dart';
import '../../devices/views/devices_view.dart';
import '../../logs/views/logs_view.dart';
import '../view_models/ota_progress_view_model.dart';

enum _SettingsSection { overview, devices, logs }

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.onOpenLight,
    this.onLogout,
    super.key,
  });

  final ValueChanged<SmartDevice> onOpenLight;

  /// Optional logout action. When null the row falls back to its inert
  /// placeholder behavior. Wired by [SmartBuildingShell] in production.
  final VoidCallback? onLogout;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  _SettingsSection _section = _SettingsSection.overview;
  bool _runtimeExpanded = false;

  @override
  Widget build(BuildContext context) {
    return switch (_section) {
      _SettingsSection.overview => _SettingsOverview(
        runtimeExpanded: _runtimeExpanded,
        onToggleRuntime: () {
          setState(() => _runtimeExpanded = !_runtimeExpanded);
        },
        onOpenDevices: () {
          setState(() => _section = _SettingsSection.devices);
        },
        onOpenLogs: () {
          setState(() => _section = _SettingsSection.logs);
        },
        onLogout: widget.onLogout,
      ),
      _SettingsSection.devices => DevicesView(
        onOpenLight: widget.onOpenLight,
        onBack: _openOverview,
      ),
      _SettingsSection.logs => LogsView(onBack: _openOverview),
    };
  }

  void _openOverview() {
    setState(() => _section = _SettingsSection.overview);
  }
}

class _SettingsOverview extends StatelessWidget {
  const _SettingsOverview({
    required this.runtimeExpanded,
    required this.onToggleRuntime,
    required this.onOpenDevices,
    required this.onOpenLogs,
    this.onLogout,
  });

  final bool runtimeExpanded;
  final VoidCallback onToggleRuntime;
  final VoidCallback onOpenDevices;
  final VoidCallback onOpenLogs;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final runtime = context.watch<AppRuntimeConfig>();
    final themeController = context.watch<ThemeController>();
    final palette = context.palette;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('Settings'), pinned: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverList.list(
            children: [
              const SectionTitle(title: 'Operator'),
              const SizedBox(height: 8),
              const AppCard(
                child: _SettingsRow(
                  icon: Icons.account_circle_outlined,
                  title: 'Account',
                  subtitle: 'operator@hust/lab01',
                ),
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'System'),
              const SizedBox(height: 8),
              AppCard(
                onTap: onToggleRuntime,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SettingsRow(
                            icon: Icons.memory_outlined,
                            title: 'Runtime',
                            subtitle: runtime.useMockApi
                                ? 'Mock API'
                                : 'Cloud API',
                          ),
                        ),
                        Icon(
                          runtimeExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: palette.textSecondary,
                        ),
                      ],
                    ),
                    if (runtimeExpanded) ...[
                      const SizedBox(height: 14),
                      Divider(color: palette.border, height: 1),
                      const SizedBox(height: 14),
                      _SettingLine(
                        label: 'API_BASE_URL',
                        value: runtime.apiBaseUrl,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Workspace'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.lightbulb_outline,
                      title: 'Device inventory',
                      subtitle: 'Review all cloud devices',
                      onTap: onOpenDevices,
                    ),
                    Divider(color: palette.border, height: 1),
                    _SettingsRow(
                      icon: Icons.receipt_long_outlined,
                      title: 'Cloud logs',
                      subtitle: 'Inspect event history',
                      onTap: onOpenLogs,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _OtaProgressSection(),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Theme mode'),
              const SizedBox(height: 8),
              AppCard(
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AppThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: AppThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.grey,
                        icon: Icon(Icons.tonality_outlined),
                        label: Text('Grey'),
                      ),
                    ],
                    selected: {themeController.mode},
                    onSelectionChanged: (selection) {
                      themeController.setMode(selection.first);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppCard(
                padding: onLogout == null
                    ? const EdgeInsets.all(16)
                    : EdgeInsets.zero,
                child: _SettingsRow(
                  icon: Icons.logout,
                  iconColor: palette.error,
                  title: 'Logout',
                  subtitle: onLogout == null
                      ? 'Sign out placeholder'
                      : 'End this operator session',
                  onTap: onLogout,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = Padding(
      padding: onTap == null
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? palette.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, color: palette.textSecondary),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(onTap: onTap, child: content);
  }
}

/// Renders the cloud OTA campaign list pulled from
/// [OtaProgressViewModel]. The section is silently empty when no campaigns
/// exist (or when the cloud OTA router is not yet deployed, see
/// `RemoteOtaRepository`). When the view model isn't provided to the tree,
/// the section renders nothing so legacy tests stay green.
class _OtaProgressSection extends StatelessWidget {
  const _OtaProgressSection();

  @override
  Widget build(BuildContext context) {
    final OtaProgressViewModel? viewModel;
    try {
      viewModel = context.watch<OtaProgressViewModel>();
    } on ProviderNotFoundException {
      // Tests / harnesses that don't wire an OTA view model render no
      // section. Keeps the screen backwards-compatible with the existing
      // settings widget tests.
      return const SizedBox.shrink();
    }

    final palette = context.palette;
    final children = <Widget>[];
    if (viewModel.isLoading && viewModel.campaigns.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    } else if (viewModel.errorMessage != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            viewModel.errorMessage!,
            style: TextStyle(color: palette.error, fontSize: 12),
          ),
        ),
      );
    } else if (viewModel.campaigns.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Khong co chien dich OTA dang chay',
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
        ),
      );
    } else {
      for (var index = 0; index < viewModel.campaigns.length; index++) {
        if (index > 0) {
          children.add(Divider(color: palette.border, height: 1));
        }
        children.add(_OtaProgressRow(campaign: viewModel.campaigns[index]));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Cap nhat firmware'),
        const SizedBox(height: 8),
        AppCard(padding: EdgeInsets.zero, child: Column(children: children)),
      ],
    );
  }
}

class _OtaProgressRow extends StatelessWidget {
  const _OtaProgressRow({required this.campaign});

  final OtaCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = switch (campaign.state) {
      OtaProgressState.queued => BadgeTone.neutral,
      OtaProgressState.running => BadgeTone.primary,
      OtaProgressState.succeeded => BadgeTone.success,
      OtaProgressState.failed => BadgeTone.error,
    };

    final subtitleParts = <String>[
      'Firmware v${campaign.firmwareVersion}',
      '${campaign.targetedDeviceCount} devices',
    ];
    if (campaign.state == OtaProgressState.running &&
        campaign.progress != null) {
      subtitleParts.add('${(campaign.progress! * 100).round()}%');
    }
    if (campaign.state == OtaProgressState.failed &&
        campaign.errorMessage != null &&
        campaign.errorMessage!.isNotEmpty) {
      subtitleParts.add(campaign.errorMessage!);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.system_update_alt,
            color: palette.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.id,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' • '),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatusBadge(label: campaign.state.label, tone: tone),
        ],
      ),
    );
  }
}

class _SettingLine extends StatelessWidget {
  const _SettingLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
        ),
      ],
    );
  }
}
