import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../domain/models/smart_device.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../automation/view_models/automation_view_model.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';
import '../../automation/views/automation_rules_view.dart';
import '../../device_detail/views/device_detail_view.dart';
import '../../home/views/home_view.dart';
import '../../provisioning/views/provisioning_view.dart';
import '../../settings/views/settings_view.dart';

class SmartBuildingShell extends StatefulWidget {
  const SmartBuildingShell({super.key});

  @override
  State<SmartBuildingShell> createState() => _SmartBuildingShellState();
}

class _SmartBuildingShellState extends State<SmartBuildingShell> {
  int _tabIndex = 0;
  String? _selectedDeviceId;
  SettingsSection _settingsInitialSection = SettingsSection.overview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<DeviceDashboardViewModel>().load();
      context.read<AutomationViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = context.watch<AuthViewModel>().session;
    final canMutateHome = session?.canMutateHome ?? false;
    final settingsIndex = canMutateHome ? 3 : 2;
    if (_tabIndex > settingsIndex) {
      _tabIndex = settingsIndex;
    }

    return Consumer<DeviceDashboardViewModel>(
      builder: (context, viewModel, _) {
        final selectedDevice = _selectedDeviceId == null
            ? null
            : viewModel.deviceById(_selectedDeviceId!);

        return Scaffold(
          body: SafeArea(
            child: selectedDevice == null
                ? _buildTabBody()
                : DeviceDetailView(
                    device: selectedDevice,
                    onBack: () => setState(() => _selectedDeviceId = null),
                  ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedDeviceId = null;
                if (index != settingsIndex) {
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
              if (canMutateHome)
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
    final session = context.watch<AuthViewModel>().session;
    final canMutateHome = session?.canMutateHome ?? false;
    return switch (_tabIndex) {
      0 => HomeView(
        onOpenLight: _openLight,
        onOpenDevices: _openDevices,
        onOpenProvisioning: _openProvisioning,
      ),
      1 => AutomationRulesView(
        canMutate: session?.canManageAutomation ?? false,
      ),
      2 when canMutateHome => const ProvisioningView(),
      _ => SettingsView(
        key: ValueKey(_settingsInitialSection),
        initialSection: _settingsInitialSection,
        onOpenLight: _openLight,
        onOpenAutomation: _openAutomation,
        onOpenProvisioning: _openProvisioning,
        onLogout: _handleLogout,
      ),
    };
  }

  void _openLight(SmartDevice device) {
    setState(() {
      _selectedDeviceId = device.id;
    });
  }

  void _openDevices() {
    final session = context.read<AuthViewModel>().session;
    final settingsIndex = session?.canMutateHome ?? false ? 3 : 2;
    setState(() {
      _selectedDeviceId = null;
      _settingsInitialSection = SettingsSection.devices;
      _tabIndex = settingsIndex;
    });
  }

  void _openAutomation() {
    setState(() {
      _selectedDeviceId = null;
      _settingsInitialSection = SettingsSection.overview;
      _tabIndex = 1;
    });
  }

  void _openProvisioning() {
    final session = context.read<AuthViewModel>().session;
    if (!(session?.canMutateHome ?? false)) {
      return;
    }
    setState(() {
      _selectedDeviceId = null;
      _settingsInitialSection = SettingsSection.overview;
      _tabIndex = 2;
    });
  }

  Future<void> _handleLogout() async {
    await context.read<AuthViewModel>().logout();
  }
}
