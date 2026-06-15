import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app_runtime_config.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../devices/views/devices_view.dart';
import '../../logs/views/logs_view.dart';
import '../widgets/profile_view.dart';
import '../widgets/rooms_view.dart';

enum SettingsSection { overview, profile, devices, rooms, logs }

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.onOpenLight,
    this.initialSection = SettingsSection.overview,
    this.onOpenAutomation,
    this.onOpenProvisioning,
    this.onLogout,
    super.key,
  });

  final ValueChanged<SmartDevice> onOpenLight;
  final SettingsSection initialSection;
  final VoidCallback? onOpenAutomation;
  final VoidCallback? onOpenProvisioning;

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
        onOpenRooms: () {
          setState(() => _section = SettingsSection.rooms);
        },
        onOpenLogs: () {
          setState(() => _section = SettingsSection.logs);
        },
        onOpenAutomation: widget.onOpenAutomation,
        onOpenProvisioning: widget.onOpenProvisioning,
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
      SettingsSection.rooms => RoomsView(onBack: _openOverview),
      SettingsSection.logs => LogsView(onBack: _openOverview),
    };
  }

  void _openOverview() {
    setState(() => _section = SettingsSection.overview);
  }
}

class _SettingsOverview extends StatelessWidget {
  const _SettingsOverview({
    required this.onOpenProfile,
    required this.onOpenDevices,
    required this.onOpenRooms,
    required this.onOpenLogs,
    this.onOpenAutomation,
    this.onOpenProvisioning,
    this.onLogout,
  });

  final VoidCallback onOpenProfile;
  final VoidCallback onOpenDevices;
  final VoidCallback onOpenRooms;
  final VoidCallback onOpenLogs;
  final VoidCallback? onOpenAutomation;
  final VoidCallback? onOpenProvisioning;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final runtime = context.watch<AppRuntimeConfig>();
    final themeController = context.watch<ThemeController>();
    final localeController = context.watch<LocaleController>();
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final session = context.watch<AuthViewModel>().session;
    final roleLabel = _roleLabel(session?.role, l10n);
    final canMutateHome = session?.canMutateHome ?? false;

    return CustomScrollView(
      slivers: [
        SliverAppBar(title: Text(l10n.settingsTab), pinned: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          sliver: SliverList.list(
            children: [
              _SettingsSectionTitle(
                title: l10n.settingsHomeSummary,
                preserveCase: localeController.locale.languageCode == 'vi',
              ),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: _SettingsRow(
                  icon: Icons.home_outlined,
                  title: roleLabel,
                  subtitle: 'Home: ${session?.homeId ?? 'Not assigned'}',
                  onTap: onOpenProfile,
                ),
              ),
              const SizedBox(height: 18),
              SectionTitle(title: l10n.settingsHomeManagement),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.lightbulb_outline,
                      title: l10n.settingsDevices,
                      onTap: onOpenDevices,
                    ),
                    if (canMutateHome) ...[
                      Divider(color: palette.border, height: 1),
                      _SettingsRow(
                        icon: Icons.meeting_room_outlined,
                        title: l10n.settingsRooms,
                        onTap: onOpenRooms,
                      ),
                      Divider(color: palette.border, height: 1),
                      _SettingsRow(
                        icon: Icons.add_circle_outline,
                        title: l10n.settingsAddNewDevice,
                        onTap: onOpenProvisioning,
                      ),
                    ],
                    Divider(color: palette.border, height: 1),
                    _SettingsRow(
                      icon: Icons.account_tree_outlined,
                      title: l10n.settingsAutomationRules,
                      onTap: onOpenAutomation,
                    ),
                    Divider(color: palette.border, height: 1),
                    _SettingsRow(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.settingsActivityHistory,
                      onTap: onOpenLogs,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionTitle(title: l10n.settingsPreferences),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsValueRow(
                      icon: Icons.palette_outlined,
                      title: l10n.settingsTheme,
                      value: _themeModeLabel(themeController.mode, l10n),
                      onTap: () {
                        _showThemePicker(context, themeController, l10n);
                      },
                    ),
                    Divider(color: palette.border, height: 1),
                    _SettingsValueRow(
                      icon: Icons.language_outlined,
                      title: l10n.settingsLanguage,
                      value: _languageLabel(
                        localeController.locale.languageCode,
                        l10n,
                      ),
                      onTap: () {
                        _showLanguagePicker(context, localeController);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionTitle(title: l10n.settingsAdvanced),
              const SizedBox(height: 8),
              _AdvancedSection(runtime: runtime, l10n: l10n),
              const SizedBox(height: 18),
              SectionTitle(title: l10n.settingsSession),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: _SettingsRow(
                  icon: Icons.logout,
                  iconColor: palette.error,
                  title: l10n.settingsLogout,
                  onTap: onLogout == null
                      ? null
                      : () {
                          _confirmLogout(context, l10n, onLogout!);
                        },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdvancedSection extends StatefulWidget {
  const _AdvancedSection({required this.runtime, required this.l10n});

  final AppRuntimeConfig runtime;
  final AppLocalizations l10n;

  @override
  State<_AdvancedSection> createState() => _AdvancedSectionState();
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({required this.title, this.preserveCase = false});

  final String title;
  final bool preserveCase;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        preserveCase ? title : title.toUpperCase(),
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AdvancedSectionState extends State<_AdvancedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final httpsStatus = widget.runtime.apiBaseUrl.startsWith('https://')
        ? 'HTTPS'
        : 'HTTP / development';

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SettingsRow(
            icon: Icons.cloud_outlined,
            title: widget.l10n.settingsConnectionSettings,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            Divider(color: palette.border, height: 1),
            _SettingsInfoRow(
              icon: Icons.cloud_outlined,
              label: widget.l10n.settingsApiBaseUrl,
              value: widget.runtime.apiBaseUrl,
              mono: true,
            ),
            Divider(color: palette.border, height: 1),
            _SettingsInfoRow(
              icon: Icons.lock_outline,
              label: widget.l10n.settingsHttpsStatus,
              value: httpsStatus,
            ),
            Divider(color: palette.border, height: 1),
            _SettingsInfoRow(
              icon: Icons.timer_outlined,
              label: widget.l10n.settingsPollInterval,
              value: '1.0 s',
              mono: true,
            ),
            Divider(color: palette.border, height: 1),
            _SettingsInfoRow(
              icon: Icons.hourglass_bottom_outlined,
              label: widget.l10n.settingsCommandTimeout,
              value: '5.0 s',
              mono: true,
            ),
            Divider(color: palette.border, height: 1),
            _SettingsInfoRow(
              icon: Icons.info_outline,
              label: widget.l10n.settingsVersion,
              value: '0.8.6',
              mono: true,
            ),
            Divider(color: palette.border, height: 1),
            _SettingsInfoRow(
              icon: Icons.terminal_outlined,
              label: widget.l10n.settingsDiagnosticsLabel,
              value: widget.l10n.settingsDiagnostics,
            ),
          ],
        ],
      ),
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

String _roleLabel(String? role, AppLocalizations l10n) {
  final normalized = (role ?? '').trim().toLowerCase();
  return switch (normalized) {
    'admin' => l10n.settingsSystemAdmin,
    'parent' || 'operator' || 'user' => l10n.settingsParentHomeOwner,
    'viewer' || 'member' => l10n.settingsMember,
    _ => l10n.settingsMember,
  };
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
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

class _SettingsValueRow extends StatelessWidget {
  const _SettingsValueRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: palette.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

String _themeModeLabel(AppThemeMode mode, AppLocalizations l10n) {
  return switch (mode) {
    AppThemeMode.light => l10n.themeLightLabel,
    AppThemeMode.dark => l10n.themeDarkLabel,
    AppThemeMode.grey => l10n.themeGreyLabel,
  };
}

String _languageLabel(String languageCode, AppLocalizations l10n) {
  return languageCode == 'vi'
      ? l10n.languageVietnameseLabel
      : l10n.languageEnglishLabel;
}

Future<void> _showThemePicker(
  BuildContext context,
  ThemeController themeController,
  AppLocalizations l10n,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.settingsTheme)),
            ListTile(
              leading: const Icon(Icons.light_mode_outlined),
              title: Text(l10n.themeLightLabel),
              onTap: () {
                themeController.setMode(AppThemeMode.light);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: Text(l10n.themeDarkLabel),
              onTap: () {
                themeController.setMode(AppThemeMode.dark);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tonality_outlined),
              title: Text(l10n.themeGreyLabel),
              onTap: () {
                themeController.setMode(AppThemeMode.grey);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showLanguagePicker(
  BuildContext context,
  LocaleController localeController,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: Text(l10n.languageEnglishLabel),
              onTap: () {
                localeController.setLocaleCode('en');
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: Text(l10n.languageVietnameseLabel),
              onTap: () {
                localeController.setLocaleCode('vi');
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _confirmLogout(
  BuildContext context,
  AppLocalizations l10n,
  VoidCallback onLogout,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.settingsLogoutConfirmTitle),
        content: Text(l10n.settingsLogoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.settingsLogoutConfirmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsLogoutConfirmAction),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    onLogout();
  }
}
