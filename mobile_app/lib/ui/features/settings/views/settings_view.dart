import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app_runtime_config.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/expandable_content.dart';
import '../../../core/widgets/section_title.dart';
import '../../devices/views/devices_view.dart';
import '../../logs/views/logs_view.dart';
import '../widgets/profile_view.dart';

enum SettingsSection { overview, profile, devices, logs }

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.onOpenLight,
    this.initialSection = SettingsSection.overview,
    this.onLogout,
    super.key,
  });

  final ValueChanged<SmartDevice> onOpenLight;
  final SettingsSection initialSection;

  /// Optional logout action. When null the row falls back to its inert
  /// placeholder behavior. Wired by [SmartBuildingShell] in production.
  final VoidCallback? onLogout;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late SettingsSection _section = widget.initialSection;

  @override
  Widget build(BuildContext context) {
    return switch (_section) {
      SettingsSection.overview => _SettingsOverview(
        onOpenProfile: () {
          setState(() => _section = SettingsSection.profile);
        },
        onOpenDevices: () {
          setState(() => _section = SettingsSection.devices);
        },
        onOpenLogs: () {
          setState(() => _section = SettingsSection.logs);
        },
        onLogout: widget.onLogout,
      ),
      SettingsSection.profile => ProfileView(
        onBack: _openOverview,
        onLogout: widget.onLogout,
      ),
      SettingsSection.devices => DevicesView(
        onOpenLight: widget.onOpenLight,
        onBack: _openOverview,
      ),
      SettingsSection.logs => LogsView(onBack: _openOverview),
    };
  }

  void _openOverview() {
    setState(() => _section = SettingsSection.overview);
  }
}

class _SettingsOverview extends StatefulWidget {
  const _SettingsOverview({
    required this.onOpenProfile,
    required this.onOpenDevices,
    required this.onOpenLogs,
    this.onLogout,
  });

  final VoidCallback onOpenProfile;
  final VoidCallback onOpenDevices;
  final VoidCallback onOpenLogs;
  final VoidCallback? onLogout;

  @override
  State<_SettingsOverview> createState() => _SettingsOverviewState();
}

class _SettingsOverviewState extends State<_SettingsOverview> {
  bool _operatorExpanded = false;
  bool _appearanceExpanded = false;
  bool _themeExpanded = false;
  bool _languageExpanded = false;
  bool _cloudExpanded = false;
  bool _workspaceExpanded = false;
  bool _aboutExpanded = false;

  @override
  Widget build(BuildContext context) {
    final runtime = context.watch<AppRuntimeConfig>();
    final themeController = context.watch<ThemeController>();
    final localeController = context.watch<LocaleController>();
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(title: Text(l10n.settingsTab), pinned: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverList.list(
            children: [
              SectionTitle(
                title: l10n.settingsOperator,
                action: CollapseIconButton(
                  key: const Key('settings-operator-toggle'),
                  expanded: _operatorExpanded,
                  onPressed: () {
                    setState(() => _operatorExpanded = !_operatorExpanded);
                  },
                ),
              ),
              ExpandableBody(
                expanded: _operatorExpanded,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: _SettingsRow(
                        icon: Icons.account_circle_outlined,
                        title: l10n.settingsAccount,
                        subtitle: 'operator@hust/lab01',
                        onTap: widget.onOpenProfile,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionTitle(
                title: l10n.settingsAppearance,
                action: CollapseIconButton(
                  key: const Key('settings-appearance-toggle'),
                  expanded: _appearanceExpanded,
                  onPressed: () {
                    setState(() => _appearanceExpanded = !_appearanceExpanded);
                  },
                ),
              ),
              ExpandableBody(
                expanded: _appearanceExpanded,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SettingsHeaderLine(
                            icon: Icons.palette_outlined,
                            title: l10n.settingsTheme,
                            expanded: _themeExpanded,
                            toggleKey: const Key('settings-theme-toggle'),
                            onToggle: () {
                              setState(() => _themeExpanded = !_themeExpanded);
                            },
                          ),
                          ExpandableBody(
                            expanded: _themeExpanded,
                            child: Column(
                              children: [
                                const SizedBox(height: 10),
                                SizedBox(
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Divider(color: palette.border, height: 1),
                          const SizedBox(height: 14),
                          _SettingsHeaderLine(
                            icon: Icons.language_outlined,
                            title: l10n.settingsLanguage,
                            expanded: _languageExpanded,
                            toggleKey: const Key('settings-language-toggle'),
                            onToggle: () {
                              setState(
                                () => _languageExpanded = !_languageExpanded,
                              );
                            },
                          ),
                          ExpandableBody(
                            expanded: _languageExpanded,
                            child: Column(
                              children: [
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(
                                        value: 'en',
                                        label: Text('English'),
                                      ),
                                      ButtonSegment(
                                        value: 'vi',
                                        label: Text('Tiếng Việt'),
                                      ),
                                    ],
                                    selected: {
                                      localeController.locale.languageCode,
                                    },
                                    onSelectionChanged: (selection) {
                                      localeController.setLocaleCode(
                                        selection.first,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionTitle(
                title: l10n.settingsCloud,
                action: CollapseIconButton(
                  key: const Key('settings-cloud-toggle'),
                  expanded: _cloudExpanded,
                  onPressed: () {
                    setState(() => _cloudExpanded = !_cloudExpanded);
                  },
                ),
              ),
              ExpandableBody(
                expanded: _cloudExpanded,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _SettingsInfoRow(
                            icon: Icons.cloud_outlined,
                            label: l10n.settingsApiBaseUrl,
                            value: runtime.apiBaseUrl,
                            mono: true,
                          ),
                          Divider(color: palette.border, height: 1),
                          _SettingsInfoRow(
                            icon: Icons.timer_outlined,
                            label: l10n.settingsPollInterval,
                            value: '2.0 s',
                            mono: true,
                          ),
                          Divider(color: palette.border, height: 1),
                          _SettingsInfoRow(
                            icon: Icons.hourglass_bottom_outlined,
                            label: l10n.settingsCommandTimeout,
                            value: '5.0 s',
                            mono: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionTitle(
                title: l10n.settingsWorkspace,
                action: CollapseIconButton(
                  key: const Key('settings-workspace-toggle'),
                  expanded: _workspaceExpanded,
                  onPressed: () {
                    setState(() => _workspaceExpanded = !_workspaceExpanded);
                  },
                ),
              ),
              ExpandableBody(
                expanded: _workspaceExpanded,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _SettingsRow(
                            icon: Icons.lightbulb_outline,
                            title: l10n.settingsDeviceInventory,
                            subtitle: l10n.settingsDeviceInventoryHint,
                            onTap: widget.onOpenDevices,
                          ),
                          Divider(color: palette.border, height: 1),
                          _SettingsRow(
                            icon: Icons.receipt_long_outlined,
                            title: l10n.settingsCloudLogs,
                            subtitle: l10n.settingsCloudLogsHint,
                            onTap: widget.onOpenLogs,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionTitle(
                title: l10n.settingsAbout,
                action: CollapseIconButton(
                  key: const Key('settings-about-toggle'),
                  expanded: _aboutExpanded,
                  onPressed: () {
                    setState(() => _aboutExpanded = !_aboutExpanded);
                  },
                ),
              ),
              ExpandableBody(
                expanded: _aboutExpanded,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _SettingsInfoRow(
                            icon: Icons.info_outline,
                            label: l10n.settingsVersion,
                            value: '0.8.6',
                            mono: true,
                          ),
                          Divider(color: palette.border, height: 1),
                          _SettingsInfoRow(
                            icon: Icons.inventory_2_outlined,
                            label: l10n.settingsBuild,
                            value: '806',
                            mono: true,
                          ),
                          Divider(color: palette.border, height: 1),
                          _SettingsInfoRow(
                            icon: Icons.terminal_outlined,
                            label: l10n.settingsDiagnosticsLabel,
                            value: l10n.settingsDiagnostics,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppCard(
                padding: widget.onLogout == null
                    ? const EdgeInsets.all(16)
                    : EdgeInsets.zero,
                child: _SettingsRow(
                  icon: Icons.logout,
                  iconColor: palette.error,
                  title: l10n.settingsLogout,
                  subtitle: widget.onLogout == null
                      ? l10n.profileSignOut
                      : l10n.settingsLogoutHint,
                  onTap: widget.onLogout,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsHeaderLine extends StatelessWidget {
  const _SettingsHeaderLine({
    required this.icon,
    required this.title,
    this.expanded,
    this.onToggle,
    this.toggleKey,
  });

  final IconData icon;
  final String title;
  final bool? expanded;
  final VoidCallback? onToggle;
  final Key? toggleKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(icon, color: palette.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        if (expanded != null && onToggle != null)
          CollapseIconButton(
            key: toggleKey,
            expanded: expanded!,
            onPressed: onToggle!,
          ),
      ],
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: palette.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.textSecondary,
                fontFamily: mono ? 'JetBrains Mono' : null,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
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
