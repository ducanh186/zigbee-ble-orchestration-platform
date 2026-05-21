// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Zigbee Smart Building';

  @override
  String get homeTab => 'Home';

  @override
  String get automationTab => 'Automation';

  @override
  String get provisioningTab => 'Provisioning';

  @override
  String get settingsTab => 'Settings';

  @override
  String get devicesTitle => 'Devices';

  @override
  String get logsTitle => 'Logs';

  @override
  String get searchDevices => 'Search devices';

  @override
  String get eventPayload => 'Event payload';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileRoleTech => 'Field technician';

  @override
  String get profileSession => 'Session';

  @override
  String get profileOrganization => 'Organization';

  @override
  String get profileSignedIn => 'Signed in since';

  @override
  String get profileApiEndpoint => 'API endpoint';

  @override
  String get profileGateway => 'Gateway';

  @override
  String get profileActions => 'Actions';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileCopyToken => 'Copy API token';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get settingsOperator => 'Operator';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageHint =>
      'Affects all on-screen text. Status codes stay English.';

  @override
  String get settingsCloud => 'Cloud';

  @override
  String get settingsApiBaseUrl => 'API base URL';

  @override
  String get settingsPollInterval => 'Poll interval';

  @override
  String get settingsCommandTimeout => 'Command timeout';

  @override
  String get settingsWorkspace => 'Workspace';

  @override
  String get settingsDeviceInventory => 'Device inventory';

  @override
  String get settingsDeviceInventoryHint => 'Review all cloud devices';

  @override
  String get settingsCloudLogs => 'Cloud logs';

  @override
  String get settingsCloudLogsHint => 'Inspect event history';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsBuild => 'Build';

  @override
  String get settingsDiagnosticsLabel => 'Diagnostics';

  @override
  String get settingsDiagnostics => 'Open diagnostics';

  @override
  String get settingsLogout => 'Logout';

  @override
  String get settingsLogoutHint => 'End this operator session';

  @override
  String get logsNoEvents => 'No event log yet.';
}
