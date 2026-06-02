import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_runtime_config.dart';
import 'data/repositories/mock_automation_repository.dart';
import 'data/repositories/mock_device_repository.dart';
import 'data/repositories/mock_provisioning_repository.dart';
import 'data/repositories/remote_auth_repository.dart';
import 'data/repositories/remote_automation_repository.dart';
import 'data/repositories/remote_device_repository.dart';
import 'data/repositories/remote_provisioning_repository.dart';
import 'data/services/api_client.dart';
import 'data/storage/secure_token_storage.dart';
import 'domain/repositories/automation_repository.dart';
import 'domain/repositories/device_repository.dart';
import 'domain/repositories/provisioning_repository.dart';
import 'l10n/app_localizations.dart';
import 'security/runtime_config_guard.dart';
import 'ui/core/localization/locale_controller.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/auth/views/change_password_view.dart';
import 'ui/features/auth/views/login_view.dart';
import 'ui/features/automation/view_models/automation_view_model.dart';
import 'ui/features/devices/view_models/device_dashboard_view_model.dart';
import 'ui/features/shell/views/smart_building_shell.dart';

const _useMockApi = bool.fromEnvironment('USE_MOCK_API', defaultValue: false);
const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://98.83.4.87:8000',
);
// Demo builds may override this with `--dart-define=HIDE_LOGIN=true`.
const _hideLogin = bool.fromEnvironment('HIDE_LOGIN', defaultValue: false);

void main() {
  validateRuntimeSecurityConfig(
    apiBaseUrl: _apiBaseUrl,
    hideLogin: _hideLogin,
    isReleaseMode: kReleaseMode,
  );

  final apiClient = ApiClient(baseUrl: _apiBaseUrl);
  final DeviceRepository repository = _useMockApi
      ? MockDeviceRepository()
      : RemoteDeviceRepository(apiClient: apiClient);
  final AutomationRepository automationRepository = _useMockApi
      ? MockAutomationRepository()
      : RemoteAutomationRepository(apiClient: apiClient);
  final ProvisioningRepository provisioningRepository = _useMockApi
      ? MockProvisioningRepository()
      : RemoteProvisioningRepository(apiClient: apiClient);
  final authViewModel = AuthViewModel(
    repository: RemoteAuthRepository(
      apiClient: apiClient,
      tokenStorage: const SecureTokenStorage(),
    ),
  );

  runApp(
    ZigbeeSmartBuildingApp(
      repository: repository,
      automationRepository: automationRepository,
      provisioningRepository: provisioningRepository,
      apiBaseUrl: _apiBaseUrl,
      useMockApi: _useMockApi,
      authViewModelOverride: authViewModel,
      hideLogin: _hideLogin,
    ),
  );
}

class ZigbeeSmartBuildingApp extends StatelessWidget {
  const ZigbeeSmartBuildingApp({
    required this.repository,
    required this.automationRepository,
    required this.apiBaseUrl,
    required this.useMockApi,
    this.provisioningRepository,
    this.authViewModelOverride,
    this.hideLogin = false,
    super.key,
  });

  final DeviceRepository repository;
  final AutomationRepository automationRepository;
  final ProvisioningRepository? provisioningRepository;
  final String apiBaseUrl;
  final bool useMockApi;

  /// Optional injection point for tests. If null, the production tree wires
  /// a real [AuthViewModel] backed by secure token storage.
  final AuthViewModel? authViewModelOverride;

  /// When true, [_AuthGate] skips the login screen and opens the shell.
  final bool hideLogin;

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
          create: (_) => DeviceDashboardViewModel(repository: repository),
        ),
        ChangeNotifierProvider(
          create: (_) => AutomationViewModel(repository: automationRepository),
        ),
        Provider<ProvisioningRepository>(
          create: (_) =>
              provisioningRepository ??
              (useMockApi
                  ? MockProvisioningRepository()
                  : RemoteProvisioningRepository(
                      apiClient: ApiClient(baseUrl: apiBaseUrl),
                    )),
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
            home: _AuthGate(hideLogin: hideLogin),
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
        tokenStorage: const SecureTokenStorage(),
      ),
    );
  }
}

/// Swaps between [LoginView] and [SmartBuildingShell] based on the current
/// [AuthViewModel] session.
class _AuthGate extends StatefulWidget {
  const _AuthGate({this.hideLogin = false});

  final bool hideLogin;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    if (!widget.hideLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final auth = context.read<AuthViewModel>();
        if (!auth.isAuthenticated) {
          unawaited(auth.bootstrap());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hideLogin) {
      return const SmartBuildingShell();
    }
    final auth = context.watch<AuthViewModel>();
    if (auth.isLoading) {
      return const _AuthLoadingView();
    }
    if (!auth.isAuthenticated) {
      return const LoginView();
    }
    if (auth.session?.mustChangePassword ?? false) {
      return const ChangePasswordView();
    }
    return const SmartBuildingShell();
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}
