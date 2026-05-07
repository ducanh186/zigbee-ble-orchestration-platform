import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/smart_device.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';
import '../../devices/views/devices_view.dart';
import '../../home/views/home_view.dart';
import '../../light_detail/views/light_detail_view.dart';
import '../../logs/views/logs_view.dart';
import '../../settings/views/settings_view.dart';

class SmartBuildingShell extends StatefulWidget {
  const SmartBuildingShell({super.key});

  @override
  State<SmartBuildingShell> createState() => _SmartBuildingShellState();
}

class _SmartBuildingShellState extends State<SmartBuildingShell> {
  int _tabIndex = 0;
  String? _selectedLightId;

  @override
  Widget build(BuildContext context) {
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
                _tabIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.lightbulb_outline),
                selectedIcon: Icon(Icons.lightbulb),
                label: 'Devices',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Logs',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBody() {
    return switch (_tabIndex) {
      0 => HomeView(onOpenLight: _openLight),
      1 => DevicesView(onOpenLight: _openLight),
      2 => const LogsView(),
      _ => const SettingsView(),
    };
  }

  void _openLight(SmartDevice device) {
    setState(() => _selectedLightId = device.id);
  }
}
