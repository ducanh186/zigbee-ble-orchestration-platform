import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../domain/models/smart_device.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';
import '../../automation/views/automation_rules_view.dart';
import '../../device_detail/views/device_detail_view.dart';
import '../../home/views/home_view.dart';
import '../../notifications/views/notification_center_view.dart';
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
  bool _showNotifications = false;
  final Set<String> _readNotificationIds = <String>{};
  SettingsSection _settingsInitialSection = SettingsSection.overview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<DeviceDashboardViewModel>(
      builder: (context, viewModel, _) {
        final selectedDevice = _selectedDeviceId == null
            ? null
            : viewModel.deviceById(_selectedDeviceId!);

        return Scaffold(
          body: SafeArea(
            child: _showNotifications
                ? NotificationCenterView(
                    events: viewModel.events,
                    readEventIds: _readNotificationIds,
                    onMarkRead: _markNotificationRead,
                    onMarkAllRead: () => setState(() {
                      _readNotificationIds.addAll(
                        viewModel.events.map((event) => event.id),
                      );
                    }),
                    onBack: () => setState(() => _showNotifications = false),
                  )
                : selectedDevice == null
                ? _buildTabBody()
                : DeviceDetailView(
                    device: selectedDevice,
                    onBack: () => setState(() => _selectedDeviceId = null),
                  ),
          ),
          floatingActionButton: _showNotifications || selectedDevice != null
              ? null
              : _NotificationButton(
                  unreadCount: viewModel.events
                      .where(
                        (event) => !_readNotificationIds.contains(event.id),
                      )
                      .length,
                  onPressed: () => setState(() => _showNotifications = true),
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedDeviceId = null;
                _showNotifications = false;
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
    setState(() {
      _showNotifications = false;
      _selectedDeviceId = device.id;
    });
  }

  void _openDevices() {
    setState(() {
      _showNotifications = false;
      _selectedDeviceId = null;
      _settingsInitialSection = SettingsSection.devices;
      _tabIndex = 3;
    });
  }

  Future<void> _handleLogout() async {
    await context.read<AuthViewModel>().logout();
  }

  void _markNotificationRead(String eventId) {
    setState(() => _readNotificationIds.add(eventId));
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = FloatingActionButton.small(
      tooltip: 'Notifications',
      onPressed: onPressed,
      child: const Icon(Icons.notifications_outlined),
    );

    if (unreadCount == 0) {
      return button;
    }

    return Badge(label: Text('$unreadCount'), child: button);
  }
}
