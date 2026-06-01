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
const _apiAuthToken = String.fromEnvironment('API_AUTH_TOKEN', defaultValue: '');
const _allowInsecureApi = bool.fromEnvironment(
  'ALLOW_INSECURE_API',
  defaultValue: false,
);

void main() {
  final apiClient = ApiClient(baseUrl: _apiBaseUrl, accessToken: _apiAuthToken);
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
      apiAuthToken: _apiAuthToken,
      allowInsecureApi: _allowInsecureApi,
    ),
  );
}

class ZigbeeSmartBuildingApp extends StatelessWidget {
  const ZigbeeSmartBuildingApp({
    required this.repository,
    required this.automationRepository,
    required this.apiBaseUrl,
    required this.useMockApi,
    this.apiAuthToken = '',
    this.allowInsecureApi = false,
    super.key,
  });

  final DeviceRepository repository;
  final AutomationRepository automationRepository;
  final String apiBaseUrl;
  final bool useMockApi;
  final String apiAuthToken;
  final bool allowInsecureApi;

  @override
  Widget build(BuildContext context) {
    final configError = remoteApiConfigurationError(
      apiBaseUrl: apiBaseUrl,
      apiAuthToken: apiAuthToken,
      useMockApi: useMockApi,
      allowInsecureApi: allowInsecureApi,
    );
    if (configError != null) {
      return MaterialApp(
        title: 'Zigbee Smart Building',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme(AppThemeMode.light),
        home: _RemoteApiConfigurationBlocked(message: configError),
      );
    }

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

String? remoteApiConfigurationError({
  required String apiBaseUrl,
  required String apiAuthToken,
  required bool useMockApi,
  required bool allowInsecureApi,
}) {
  if (useMockApi) {
    return null;
  }

  final uri = Uri.tryParse(apiBaseUrl);
  final problems = <String>[];
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    problems.add('Set API_BASE_URL to a valid HTTPS URL.');
  } else {
    final isLocalHost = {
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
    }.contains(uri.host);
    if (uri.scheme != 'https' && !(allowInsecureApi && isLocalHost)) {
      problems.add('Use HTTPS for remote API_BASE_URL.');
    }
  }

  if (apiAuthToken.trim().isEmpty) {
    problems.add('Set API_AUTH_TOKEN before using the remote API.');
  }

  if (problems.isEmpty) {
    return null;
  }
  return problems.join(' ');
}

class _RemoteApiConfigurationBlocked extends StatelessWidget {
  const _RemoteApiConfigurationBlocked({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remote API configuration blocked',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
