import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_runtime_config.dart';
import 'data/repositories/mock_device_repository.dart';
import 'data/repositories/remote_device_repository.dart';
import 'data/services/api_client.dart';
import 'domain/repositories/device_repository.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/devices/view_models/device_dashboard_view_model.dart';
import 'ui/features/shell/views/smart_building_shell.dart';

const _useMockApi = bool.fromEnvironment('USE_MOCK_API', defaultValue: false);
const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://98.83.4.87:8000',
);

void main() {
  final DeviceRepository repository = _useMockApi
      ? MockDeviceRepository()
      : RemoteDeviceRepository(apiClient: ApiClient(baseUrl: _apiBaseUrl));

  runApp(
    ZigbeeSmartBuildingApp(
      repository: repository,
      apiBaseUrl: _apiBaseUrl,
      useMockApi: _useMockApi,
    ),
  );
}

class ZigbeeSmartBuildingApp extends StatelessWidget {
  const ZigbeeSmartBuildingApp({
    required this.repository,
    required this.apiBaseUrl,
    required this.useMockApi,
    super.key,
  });

  final DeviceRepository repository;
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
