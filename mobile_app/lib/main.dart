import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_runtime_config.dart';
import 'data/repositories/mock_automation_repository.dart';
import 'data/repositories/mock_device_repository.dart';
import 'data/repositories/mock_ota_repository.dart';
import 'data/repositories/remote_auth_repository.dart';
import 'data/repositories/remote_automation_repository.dart';
import 'data/repositories/remote_device_repository.dart';
import 'data/repositories/remote_ota_repository.dart';
import 'data/services/api_client.dart';
import 'domain/repositories/automation_repository.dart';
import 'domain/repositories/device_repository.dart';
import 'domain/repositories/ota_repository.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/auth/views/login_view.dart';
import 'ui/features/automation/view_models/automation_view_model.dart';
import 'ui/features/devices/view_models/device_dashboard_view_model.dart';
import 'ui/features/settings/view_models/ota_progress_view_model.dart';
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
  // SCRUM-25: the cloud OTA router does not exist yet (depends on SCRUM-8).
  // Until then the remote impl maps 404 to an empty list so the screen stays
  // quiet in production. Mock mode shows representative campaigns.
  final OtaRepository otaRepository = _useMockApi
      ? MockOtaRepository()
      : RemoteOtaRepository(apiClient: apiClient);
  final authViewModel = AuthViewModel(
    repository: RemoteAuthRepository(apiClient: apiClient),
  );

  runApp(
    ZigbeeSmartBuildingApp(
      repository: repository,
      automationRepository: automationRepository,
      otaRepository: otaRepository,
      apiBaseUrl: _apiBaseUrl,
      useMockApi: _useMockApi,
      authViewModelOverride: authViewModel,
    ),
  );
}

class ZigbeeSmartBuildingApp extends StatelessWidget {
  const ZigbeeSmartBuildingApp({
    required this.repository,
    required this.automationRepository,
    required this.apiBaseUrl,
    required this.useMockApi,
    this.otaRepository,
    this.authViewModelOverride,
    super.key,
  });

  final DeviceRepository repository;
  final AutomationRepository automationRepository;

  /// Optional OTA progress source. When null the OTA settings section is
  /// hidden. Production [main] always supplies one; the existing widget
  /// tests omit it to keep their fixtures focused.
  final OtaRepository? otaRepository;

  final String apiBaseUrl;
  final bool useMockApi;

  /// Optional injection point for tests. If null, the production tree wires
  /// a real [AuthViewModel] backed by the in-memory repository.
  final AuthViewModel? authViewModelOverride;

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
        if (otaRepository != null)
          ChangeNotifierProvider(
            create: (_) =>
                OtaProgressViewModel(repository: otaRepository!)..load(),
          ),
        ChangeNotifierProvider<AuthViewModel>.value(
          value: authViewModelOverride ?? _fallbackAuthViewModel(),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: 'Zigbee Smart Building',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme(themeController.mode),
            home: const _AuthGate(),
          );
        },
      ),
    );
  }

  AuthViewModel _fallbackAuthViewModel() {
    // Tests that omit [authViewModelOverride] still need a working auth view
    // model. Production always supplies one via [main].
    return AuthViewModel(
      repository: RemoteAuthRepository(apiClient: ApiClient(baseUrl: apiBaseUrl)),
    );
  }
}

/// Swaps between [LoginView] and [SmartBuildingShell] based on the current
/// [AuthViewModel] session.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (!auth.isAuthenticated) {
      return const LoginView();
    }
    return const SmartBuildingShell();
  }
}
