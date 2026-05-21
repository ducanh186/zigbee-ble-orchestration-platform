import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../domain/models/smart_device.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';
import '../../automation/views/automation_rules_view.dart';
import '../../home/views/home_view.dart';
import '../../light_detail/views/light_detail_view.dart';
import '../../provisioning/views/provisioning_view.dart';
import '../../settings/views/settings_view.dart';

class SmartBuildingShell extends StatefulWidget {
  const SmartBuildingShell({super.key});

  @override
  State<SmartBuildingShell> createState() => _SmartBuildingShellState();
}

class _SmartBuildingShellState extends State<SmartBuildingShell> {
  int _tabIndex = 0;
  String? _selectedLightId;
  SettingsSection _settingsInitialSection = SettingsSection.overview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<DeviceDashboardViewModel>(
      builder: (context, viewModel, _) {
        final selectedLight = _selectedLightId == null
            ? null
            : viewModel.deviceById(_selectedLightId!);

        return Scaffold(
          body: SafeArea(
            child: selectedLight == null
                ? _buildTabBody()
                : LightDetailView(
                    device: selectedLight,
                    onBack: () => setState(() => _selectedLightId = null),
                  ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedLightId = null;
                if (index != 3) {
                  _settingsInitialSection = SettingsSection.overview;
                }
                _tabIndex = index;
              });
            },
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: l10n.homeTab,
              ),
              NavigationDestination(
                icon: Icon(Icons.rule_outlined),
                selectedIcon: Icon(Icons.rule),
                label: l10n.automationTab,
              ),
              NavigationDestination(
                icon: Icon(Icons.hub_outlined),
                selectedIcon: Icon(Icons.hub),
                label: l10n.provisioningTab,
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: l10n.settingsTab,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBody() {
    return switch (_tabIndex) {
      0 => HomeView(onOpenLight: _openLight, onOpenDevices: _openDevices),
      1 => const AutomationRulesView(),
      2 => const ProvisioningView(),
      _ => SettingsView(
        key: ValueKey(_settingsInitialSection),
        initialSection: _settingsInitialSection,
        onOpenLight: _openLight,
        onLogout: _handleLogout,
      ),
    };
  }

  void _openLight(SmartDevice device) {
    setState(() => _selectedLightId = device.id);
  }

  void _openDevices() {
    setState(() {
      _selectedLightId = null;
      _settingsInitialSection = SettingsSection.devices;
      _tabIndex = 3;
    });
  }

  Future<void> _handleLogout() async {
    await context.read<AuthViewModel>().logout();
  }
}
