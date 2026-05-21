import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../../../app_runtime_config.dart';
import '../../../data/repositories/mock_device_repository.dart';
import '../../../domain/models/smart_device.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../devices/view_models/device_dashboard_view_model.dart';
import 'views/settings_view.dart';

@Preview(
  group: 'Settings',
  name: 'Settings overview - dark',
  size: Size(390, 844),
)
Widget settingsOverviewPreview() {
  return _settingsPreview(SettingsSection.overview);
}

@Preview(group: 'Settings', name: 'Profile - dark', size: Size(390, 844))
Widget profilePreview() {
  return _settingsPreview(SettingsSection.profile);
}

Widget _settingsPreview(SettingsSection section) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider(create: (_) => LocaleController()),
      Provider(
        create: (_) => const AppRuntimeConfig(
          apiBaseUrl: 'http://98.83.4.87:8000',
          useMockApi: true,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            DeviceDashboardViewModel(repository: MockDeviceRepository())
              ..load(),
      ),
    ],
    child: Consumer2<ThemeController, LocaleController>(
      builder: (context, themeController, localeController, _) {
        return MaterialApp(
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
          home: Scaffold(
            body: SafeArea(
              child: SettingsView(
                initialSection: section,
                onOpenLight: (SmartDevice _) {},
              ),
            ),
          ),
        );
      },
    ),
  );
}
