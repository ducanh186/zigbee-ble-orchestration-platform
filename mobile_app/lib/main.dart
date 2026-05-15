import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_runtime_config.dart';
import 'data/repositories/mock_automation_repository.dart';
import 'data/repositories/mock_device_repository.dart';
import 'data/repositories/remote_automation_repository.dart';
import 'data/repositories/remote_device_repository.dart';
import 'data/services/api_client.dart';
import 'domain/repositories/automation_repository.dart';
import 'domain/repositories/device_repository.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/automation/view_models/automation_view_model.dart';
import 'ui/features/devices/view_models/device_dashboard_view_model.dart';
import 'ui/features/shell/views/smart_building_shell.dart';

const _useMockApi = bool.fromEnvironment('USE_MOCK_API', defaultValue: false);
const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://98.83.4.87:8000',
);

void main() {
  final apiClient = ApiClient(baseUrl: _apiBaseUrl);
  final DeviceRepository repository = _useMockApi
      ? MockDeviceRepository()
      : RemoteDeviceRepository(apiClient: apiClient);
  final AutomationRepository automationRepository = _useMockApi
      ? MockAutomationRepository()
      : RemoteAutomationRepository(apiClient: apiClient);

  runApp(
    ZigbeeSmartBuildingApp(
      repository: repository,
      automationRepository: automationRepository,
      apiBaseUrl: _apiBaseUrl,
      useMockApi: _useMockApi,
    ),
  );
}

class ZigbeeSmartBuildingApp extends StatelessWidget {
  const ZigbeeSmartBuildingApp({
    required this.repository,
    required this.automationRepository,
    required this.apiBaseUrl,
    required this.useMockApi,
    super.key,
  });

  final DeviceRepository repository;
  final AutomationRepository automationRepository;
  final String apiBaseUrl;
  final bool useMockApi;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        Provider(
          create: (_) =>
              AppRuntimeConfig(apiBaseUrl: apiBaseUrl, useMockApi: useMockApi),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              DeviceDashboardViewModel(repository: repository)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              AutomationViewModel(repository: automationRepository)..load(),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: 'Zigbee Smart Building',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme(themeController.mode),
            home: const SmartBuildingShell(),
          );
        },
      ),
    );
  }
}
