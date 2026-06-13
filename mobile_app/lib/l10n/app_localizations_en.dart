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
  String get profileActions => 'Actions';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileCopyToken => 'Copy API token';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get settingsAccountCenter => 'Settings';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAccountDetails => 'Account details';

  @override
  String get settingsRole => 'Role';

  @override
  String get settingsHomeScope => 'Home scope';

  @override
  String get settingsHomeSummary => 'Home summary';

  @override
  String get settingsRolePermissions => 'Role permissions';

  @override
  String get settingsMember => 'Member';

  @override
  String get settingsMemberHint =>
      'Read-only: devices, state, motion, and event log';

  @override
  String get settingsParentHomeOwner => 'Parent · Home Owner';

  @override
  String get settingsParentHomeOwnerHint => 'Full control inside own home';

  @override
  String get settingsSystemAdmin => 'System Admin';

  @override
  String get settingsSystemAdminHint =>
      'Technical and production system access';

  @override
  String get settingsHomeManagement => 'Home management';

  @override
  String get settingsDevices => 'Devices';

  @override
  String get settingsAddNewDevice => 'Add new device';

  @override
  String get settingsAutomationRules => 'Automation rules';

  @override
  String get settingsActivityHistory => 'Activity history';

  @override
  String get settingsDeviceControl => 'Device control';

  @override
  String get settingsDeviceControlHint =>
      'Turn lights on or off inside this home';

  @override
  String get settingsAutomationCrud => 'Automation CRUD';

  @override
  String get settingsAutomationCrudHint =>
      'Create, edit, enable, disable, and delete rules';

  @override
  String get settingsProvisioningDevice => 'Provisioning device';

  @override
  String get settingsProvisioningDeviceHint => 'Add a new device to this home';

  @override
  String get settingsDeleteDevice => 'Delete device';

  @override
  String get settingsDeleteDeviceHint =>
      'Remove only devices that belong to this home';

  @override
  String get settingsRediscoverDevice => 'Rediscover device';

  @override
  String get settingsRediscoverDeviceHint =>
      'Ask the home hub to classify a home device again';

  @override
  String get settingsSystemOnly => 'System only';

  @override
  String get settingsProductionConfig => 'Production config';

  @override
  String get settingsProductionConfigHint =>
      'Admin-only tenant, site, and system identity settings';

  @override
  String get settingsMqttTlsSecurity => 'MQTT/TLS security';

  @override
  String get settingsMqttTlsSecurityHint =>
      'Admin-only broker, certificate, and security config';

  @override
  String get settingsCloudConnection => 'Cloud connection';

  @override
  String get settingsHttpsStatus => 'HTTPS status';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get settingsConnectionSettings => 'Connection settings';

  @override
  String get settingsPreferences => 'Preferences';

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
  String get settingsSession => 'Session';

  @override
  String get settingsLogout => 'Logout';

  @override
  String get settingsLogoutHint => 'End this account session';

  @override
  String get settingsLogoutConfirmTitle => 'Log out?';

  @override
  String get settingsLogoutConfirmBody =>
      'End this account session on this device.';

  @override
  String get settingsLogoutConfirmCancel => 'Cancel';

  @override
  String get settingsLogoutConfirmAction => 'Log out';

  @override
  String get logsNoEvents => 'No event log yet.';

  @override
  String get environmentTitle => 'Environment';

  @override
  String get temperatureLabel => 'Temperature';

  @override
  String get humidityLabel => 'Humidity';

  @override
  String get zigbeeLocalLabel => 'Zigbee local';

  @override
  String get sensorConditionLabel => 'Condition';

  @override
  String get metricLabel => 'Metric';

  @override
  String get operatorLabel => 'Operator';

  @override
  String get thresholdLabel => 'Threshold';

  @override
  String get greaterThanOrEqualLabel => 'Greater than or equal';

  @override
  String get lessThanOrEqualLabel => 'Less than or equal';

  @override
  String get degreesCelsiusUnit => '°C';

  @override
  String get percentUnit => '%';

  @override
  String get scheduleOnTemplate => 'Schedule on';

  @override
  String get scheduleOffTemplate => 'Schedule off';

  @override
  String get scheduleTriggerLabel => 'Schedule';

  @override
  String get cronPresetWeekdaySeven => 'Every weekday 07:00';

  @override
  String get cronPresetSundayTwentyTwo => 'Every Sunday 22:00';

  @override
  String get cronPresetEverySixHours => 'Every 6 hours';

  @override
  String get rawCronLabel => 'Custom cron';

  @override
  String get targetTypeLabel => 'Target type';

  @override
  String get directLightLabel => 'Direct light';

  @override
  String get sceneLabel => 'Scene';

  @override
  String get noScenesAvailable => 'No scenes available';

  @override
  String get sceneUnavailableMessage =>
      'Scenes are unavailable. Select a direct light.';

  @override
  String get invalidCronMessage => 'Enter a valid five-field cron expression';
}
