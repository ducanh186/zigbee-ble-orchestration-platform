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
  String get themeLightLabel => 'Light';

  @override
  String get themeDarkLabel => 'Dark';

  @override
  String get themeGreyLabel => 'Cream';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageEnglishLabel => 'English';

  @override
  String get languageVietnameseLabel => 'Vietnamese';

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
  String get refreshTooltip => 'Refresh';

  @override
  String get retryLabel => 'Retry';

  @override
  String get cancelLabel => 'Cancel';

  @override
  String get closeTooltip => 'Close';

  @override
  String get backLabel => 'Back';

  @override
  String get deleteLabel => 'Delete';

  @override
  String get deleteRuleTooltip => 'Delete rule';

  @override
  String get devicesMetricLabel => 'Devices';

  @override
  String get onlineMetricLabel => 'Online';

  @override
  String get unreachableMetricLabel => 'Unreachable';

  @override
  String get quickLightsTitle => 'Quick lights';

  @override
  String get noLightNodeMessage => 'No light node found.';

  @override
  String get newRuleTitle => 'New rule';

  @override
  String get newRuleSubtitle => 'When something happens, do something.';

  @override
  String get createRuleTitle => 'Create rule';

  @override
  String get ruleNameLabel => 'Rule name';

  @override
  String get ruleNameHint => 'e.g. Motion turns on lab lights';

  @override
  String get ruleKindLabel => 'Rule type';

  @override
  String get ruleKindDeviceTrigger => 'Device trigger';

  @override
  String get ruleKindSchedule => 'Schedule';

  @override
  String get triggerDeviceLabel => 'Trigger device';

  @override
  String get targetLightsLabel => 'Target lights';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get enabledLabel => 'Enabled';

  @override
  String get previewLabel => 'Preview';

  @override
  String get noTriggerDevicesMessage =>
      'No switch, motion, or environment sensor available';

  @override
  String get noLightDevicesMessage => 'No light devices available';

  @override
  String get chooseTriggerDeviceMessage => 'Choose a trigger device first';

  @override
  String get toggleLabel => 'Toggle';

  @override
  String get turnOnLabel => 'Turn on';

  @override
  String get turnOffLabel => 'Turn off';

  @override
  String get occupiedLabel => 'Occupied';

  @override
  String get unoccupiedLabel => 'Unoccupied';

  @override
  String get ruleEnabledLabel => 'On - rule is active';

  @override
  String get ruleDisabledLabel => 'Off - rule is not running';

  @override
  String get saveRuleLabel => 'Save rule';

  @override
  String get automationRulesTitle => 'Automation Rules';

  @override
  String get rulesSectionTitle => 'Rules';

  @override
  String ruleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
    );
    return '$_temp0';
  }

  @override
  String get deleteRuleTitle => 'Delete rule?';

  @override
  String deleteRuleBody(String name) {
    return 'This removes \"$name\" from the home hub sync list.';
  }

  @override
  String get ruleCreatedMessage => 'Rule created. Waiting for home hub sync.';

  @override
  String get noMatchingDeviceMessage => 'No matching device found.';

  @override
  String get clearSearchTooltip => 'Clear search';

  @override
  String get notificationCenterTitle => 'Notification Center';

  @override
  String get markAllReadLabel => 'Mark all read';

  @override
  String unreadCount(int count) {
    return 'Unread $count';
  }

  @override
  String get importantEventsLabel => 'Important cloud and home hub events';

  @override
  String get noNotificationsMessage => 'No notifications in this category.';

  @override
  String get markReadLabel => 'Mark read';

  @override
  String get notificationCategoryAll => 'All';

  @override
  String get notificationCategoryCommand => 'Command';

  @override
  String get notificationCategoryAutomation => 'Automation';

  @override
  String get notificationCategoryGateway => 'Home hub';

  @override
  String get notificationCategoryDevice => 'Devices';

  @override
  String get notificationCategorySystem => 'System';

  @override
  String get notificationCategoryOta => 'OTA';

  @override
  String get notificationCategoryOther => 'Other';

  @override
  String get profileUsernameLabel => 'Username';

  @override
  String get profileUserIdLabel => 'User ID';

  @override
  String get profileRoleLabel => 'Role';

  @override
  String get profileHomeIdLabel => 'Home ID';

  @override
  String get profileExpiresAtLabel => 'Expires at';

  @override
  String get profileApiLabel => 'API';

  @override
  String get provisioningWizardTitle => 'Provisioning wizard';

  @override
  String get roomIdLabel => 'Room ID';

  @override
  String get scanQrLabel => 'Scan QR';

  @override
  String get useManualLabel => 'Use manual';

  @override
  String get qrJsonLabel => 'QR JSON';

  @override
  String get clearLabel => 'Clear';

  @override
  String get startProvisioningLabel => 'Start provisioning';

  @override
  String get scanProvisioningQrTitle => 'Scan provisioning QR';

  @override
  String get provisioningSessionCreated => 'Session created in Cloud.';

  @override
  String get provisioningPermitOpen =>
      'Device join window is accepting this device.';

  @override
  String get provisioningJoining => 'Device is joining the Zigbee network.';

  @override
  String get provisioningJoined => 'Device joined and is ready for room use.';

  @override
  String get provisioningFailed => 'Provisioning failed.';

  @override
  String get provisioningExpired => 'Provisioning session expired.';

  @override
  String get provisioningCancelled => 'Provisioning session cancelled.';

  @override
  String get provisioningReady => 'Enter room and device identity.';

  @override
  String get deviceIdentityRequired => 'Device identity required';

  @override
  String get deviceIdentityTitle => 'Device identity';

  @override
  String get deviceTypeLabel => 'Type';

  @override
  String get modelLabel => 'Model';

  @override
  String get deviceDetailTitle => 'Device detail';

  @override
  String get renameDeviceLabel => 'Rename device';

  @override
  String get recentEventsTitle => 'Recent events';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get saveLabel => 'Save';

  @override
  String get statusLabel => 'Status';

  @override
  String get roomLabel => 'Room';

  @override
  String get moveRoomLabel => 'Move room';

  @override
  String get moveRoomTitle => 'Move to room';

  @override
  String get noRoomsAvailable => 'No rooms available';

  @override
  String get occupancyLabel => 'Occupancy';

  @override
  String get reportedLabel => 'Reported';

  @override
  String get onlineLabel => 'Online';

  @override
  String get offlineLabel => 'Offline';

  @override
  String get occupancyOccupiedLabel => 'Occupied';

  @override
  String get occupancyUnoccupiedLabel => 'Unoccupied';

  @override
  String get occupancyUnknownLabel => 'Unknown';

  @override
  String get occupancyTimelineTitle => 'Occupancy timeline';

  @override
  String get latestOccupancyLabel => 'Latest occupancy';

  @override
  String get noEventYetMessage => 'No event yet';

  @override
  String get noOccupancyEventMessage => 'No occupancy event for this sensor.';

  @override
  String get commandSentMessage => 'Sent to Cloud API';

  @override
  String get commandQueuedMessage => 'Queued by home hub';

  @override
  String get commandWaitingMessage => 'Waiting for device reply';

  @override
  String get commandAcknowledgedMessage => 'Acknowledged by home hub';

  @override
  String get commandFailedMessage => 'Command failed';

  @override
  String get commandTimeoutMessage => 'No reply within polling window';

  @override
  String get noActiveCommandMessage => 'No active command';

  @override
  String get lastCommandTitle => 'Last command';

  @override
  String get noneLabel => 'none';

  @override
  String retryTargetLabel(String target) {
    return 'Retry $target';
  }

  @override
  String get noRecentEventMessage => 'No recent event for this device.';

  @override
  String get deviceRegistryUpdatedMessage => 'Device registry updated';

  @override
  String get gatewayHealthUpdatedMessage => 'Home hub health updated';

  @override
  String get eventUpdatedMessage => 'Event updated';

  @override
  String get errorTimeoutMessage =>
      'The network response took too long. Try again.';

  @override
  String get errorOfflineMessage =>
      'No network connection. Check Wi-Fi or mobile data.';

  @override
  String get errorValidationMessage =>
      'The data is invalid. Check the input fields.';

  @override
  String get errorUnauthorizedMessage =>
      'Your session is invalid. Sign in again.';

  @override
  String get errorServerMessage => 'The server has a problem. Try again later.';

  @override
  String get errorUnknownMessage => 'An unknown error occurred. Try again.';

  @override
  String get errorLoginContext => 'Login failed';

  @override
  String get errorPasswordChangeContext => 'Password change failed';

  @override
  String get errorLoadRulesContext => 'Could not load automation rules';

  @override
  String get errorCreateRuleContext => 'Could not create automation rule';

  @override
  String get errorDeleteRuleContext => 'Could not delete automation rule';

  @override
  String get errorUpdateRuleContext => 'Could not update automation rule';

  @override
  String get errorCloudConnectionContext => 'Could not connect to Cloud API';

  @override
  String get errorRenameDeviceContext => 'Could not rename device';

  @override
  String get gatewayOnlineTitle => 'Home hub online';

  @override
  String get gatewayOfflineTitle => 'Home hub offline';

  @override
  String get gatewayUnknownTitle => 'Home hub status unknown';

  @override
  String get gatewayMockTitle => 'Mock home hub log';

  @override
  String gatewayLastReport(String time) {
    return 'Last report: $time';
  }

  @override
  String get gatewayLatestEvent => 'Latest cloud event received';

  @override
  String get gatewayNoStatus => 'No home hub status log found';

  @override
  String get gatewayOfflineDetail => 'Home hub reported offline';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSubtitle => 'Account access to your Smart Home.';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get usernameRequiredMessage => 'Enter your username';

  @override
  String get passwordRequiredMessage => 'Enter your password';

  @override
  String get loginAction => 'Login';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get requiredMessage => 'Required';

  @override
  String get passwordMinimumMessage => 'Use at least 8 characters';

  @override
  String get updatePasswordAction => 'Update password';

  @override
  String get emptyRulesTitle => 'No automation rules yet';

  @override
  String get emptyRulesBody =>
      'Create a rule for motion, switch, or environment sensor events. Cloud saves it and syncs it to your home hub.';

  @override
  String get whenLabel => 'WHEN';

  @override
  String get thenLabel => 'THEN';

  @override
  String get occupancyChangesLabel => 'occupancy changes';

  @override
  String occupancyChangesValue(String value) {
    return 'occupancy changes: $value';
  }

  @override
  String get togglesLabel => 'toggles';

  @override
  String get environmentTitle => 'Environment';

  @override
  String get temperatureLabel => 'Temperature';

  @override
  String get humidityLabel => 'Humidity';

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
  String get scheduleActionLabel => 'Action';

  @override
  String get scheduleModeHourly => 'Hourly';

  @override
  String get scheduleModeDaily => 'Daily';

  @override
  String get scheduleModeWeekdays => 'Weekdays';

  @override
  String get scheduleModeWeekly => 'Weekly';

  @override
  String get scheduleModeCustom => 'Custom';

  @override
  String get scheduleTimeLabel => 'At';

  @override
  String get scheduleMinuteLabel => 'At minute';

  @override
  String get scheduleSummaryPrefix => 'Runs';

  @override
  String get rawCronLabel => 'Custom cron';

  @override
  String get targetTypeLabel => 'Target type';

  @override
  String get directLightLabel => 'Direct light';

  @override
  String get sceneLabel => 'Scene';

  @override
  String get activateLabel => 'Activate';

  @override
  String get noScenesAvailable => 'No scenes available';

  @override
  String get sceneUnavailableMessage =>
      'Scenes are unavailable. Select a direct light.';

  @override
  String get invalidCronMessage => 'Enter a valid five-field cron expression';
}
