import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_runtime_config.dart';
import 'data/repositories/mock_automation_repository.dart';
import 'data/repositories/mock_device_repository.dart';
import 'data/repositories/remote_auth_repository.dart';
import 'data/repositories/remote_automation_repository.dart';
import 'data/repositories/remote_device_repository.dart';
import 'data/services/api_client.dart';
import 'domain/repositories/automation_repository.dart';
import 'domain/repositories/device_repository.dart';
import 'l10n/app_localizations.dart';
import 'ui/core/localization/locale_controller.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/auth/views/login_view.dart';
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
  final authViewModel = AuthViewModel(
    repository: RemoteAuthRepository(apiClient: apiClient),
  );

  runApp(
    ZigbeeSmartBuildingApp(
      repository: repository,
      automationRepository: automationRepository,
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
    this.authViewModelOverride,
    super.key,
  });

  final DeviceRepository repository;
  final AutomationRepository automationRepository;
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
        ChangeNotifierProvider(create: (_) => LocaleController()),
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
        ChangeNotifierProvider<AuthViewModel>.value(
          value: authViewModelOverride ?? _fallbackAuthViewModel(),
        ),
      ],
      child: Consumer2<ThemeController, LocaleController>(
        builder: (context, themeController, localeController, _) {
          return MaterialApp(
            title: 'Zigbee Smart Building',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: localeController.locale,
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
      repository: RemoteAuthRepository(
        apiClient: ApiClient(baseUrl: apiBaseUrl),
      ),
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
