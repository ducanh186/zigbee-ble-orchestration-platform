import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Zigbee Smart Building'**
  String get appTitle;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @automationTab.
  ///
  /// In en, this message translates to:
  /// **'Automation'**
  String get automationTab;

  /// No description provided for @provisioningTab.
  ///
  /// In en, this message translates to:
  /// **'Provisioning'**
  String get provisioningTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @devicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesTitle;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @searchDevices.
  ///
  /// In en, this message translates to:
  /// **'Search devices'**
  String get searchDevices;

  /// No description provided for @eventPayload.
  ///
  /// In en, this message translates to:
  /// **'Event payload'**
  String get eventPayload;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileRoleTech.
  ///
  /// In en, this message translates to:
  /// **'Field technician'**
  String get profileRoleTech;

  /// No description provided for @profileSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get profileSession;

  /// No description provided for @profileOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get profileOrganization;

  /// No description provided for @profileSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in since'**
  String get profileSignedIn;

  /// No description provided for @profileApiEndpoint.
  ///
  /// In en, this message translates to:
  /// **'API endpoint'**
  String get profileApiEndpoint;

  /// No description provided for @profileActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get profileActions;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileChangePassword;

  /// No description provided for @profileCopyToken.
  ///
  /// In en, this message translates to:
  /// **'Copy API token'**
  String get profileCopyToken;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileSignOut;

  /// No description provided for @settingsAccountCenter.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsAccountCenter;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account details'**
  String get settingsAccountDetails;

  /// No description provided for @settingsRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get settingsRole;

  /// No description provided for @settingsHomeScope.
  ///
  /// In en, this message translates to:
  /// **'Home scope'**
  String get settingsHomeScope;

  /// No description provided for @settingsHomeSummary.
  ///
  /// In en, this message translates to:
  /// **'Home summary'**
  String get settingsHomeSummary;

  /// No description provided for @settingsRolePermissions.
  ///
  /// In en, this message translates to:
  /// **'Role permissions'**
  String get settingsRolePermissions;

  /// No description provided for @settingsMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get settingsMember;

  /// No description provided for @settingsMemberHint.
  ///
  /// In en, this message translates to:
  /// **'Read-only: devices, state, motion, and event log'**
  String get settingsMemberHint;

  /// No description provided for @settingsParentHomeOwner.
  ///
  /// In en, this message translates to:
  /// **'Parent · Home Owner'**
  String get settingsParentHomeOwner;

  /// No description provided for @settingsParentHomeOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'Full control inside own home'**
  String get settingsParentHomeOwnerHint;

  /// No description provided for @settingsSystemAdmin.
  ///
  /// In en, this message translates to:
  /// **'System Admin'**
  String get settingsSystemAdmin;

  /// No description provided for @settingsSystemAdminHint.
  ///
  /// In en, this message translates to:
  /// **'Technical and production system access'**
  String get settingsSystemAdminHint;

  /// No description provided for @settingsHomeManagement.
  ///
  /// In en, this message translates to:
  /// **'Home management'**
  String get settingsHomeManagement;

  /// No description provided for @settingsDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get settingsDevices;

  /// No description provided for @settingsAddNewDevice.
  ///
  /// In en, this message translates to:
  /// **'Add new device'**
  String get settingsAddNewDevice;

  /// No description provided for @settingsAutomationRules.
  ///
  /// In en, this message translates to:
  /// **'Automation rules'**
  String get settingsAutomationRules;

  /// No description provided for @settingsActivityHistory.
  ///
  /// In en, this message translates to:
  /// **'Activity history'**
  String get settingsActivityHistory;

  /// No description provided for @settingsDeviceControl.
  ///
  /// In en, this message translates to:
  /// **'Device control'**
  String get settingsDeviceControl;

  /// No description provided for @settingsDeviceControlHint.
  ///
  /// In en, this message translates to:
  /// **'Turn lights on or off inside this home'**
  String get settingsDeviceControlHint;

  /// No description provided for @settingsAutomationCrud.
  ///
  /// In en, this message translates to:
  /// **'Automation CRUD'**
  String get settingsAutomationCrud;

  /// No description provided for @settingsAutomationCrudHint.
  ///
  /// In en, this message translates to:
  /// **'Create, edit, enable, disable, and delete rules'**
  String get settingsAutomationCrudHint;

  /// No description provided for @settingsProvisioningDevice.
  ///
  /// In en, this message translates to:
  /// **'Provisioning device'**
  String get settingsProvisioningDevice;

  /// No description provided for @settingsProvisioningDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Add a new device to this home'**
  String get settingsProvisioningDeviceHint;

  /// No description provided for @settingsDeleteDevice.
  ///
  /// In en, this message translates to:
  /// **'Delete device'**
  String get settingsDeleteDevice;

  /// No description provided for @settingsDeleteDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Remove only devices that belong to this home'**
  String get settingsDeleteDeviceHint;

  /// No description provided for @settingsRediscoverDevice.
  ///
  /// In en, this message translates to:
  /// **'Rediscover device'**
  String get settingsRediscoverDevice;

  /// No description provided for @settingsRediscoverDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the home hub to classify a home device again'**
  String get settingsRediscoverDeviceHint;

  /// No description provided for @settingsSystemOnly.
  ///
  /// In en, this message translates to:
  /// **'System only'**
  String get settingsSystemOnly;

  /// No description provided for @settingsProductionConfig.
  ///
  /// In en, this message translates to:
  /// **'Production config'**
  String get settingsProductionConfig;

  /// No description provided for @settingsProductionConfigHint.
  ///
  /// In en, this message translates to:
  /// **'Admin-only tenant, site, and system identity settings'**
  String get settingsProductionConfigHint;

  /// No description provided for @settingsMqttTlsSecurity.
  ///
  /// In en, this message translates to:
  /// **'MQTT/TLS security'**
  String get settingsMqttTlsSecurity;

  /// No description provided for @settingsMqttTlsSecurityHint.
  ///
  /// In en, this message translates to:
  /// **'Admin-only broker, certificate, and security config'**
  String get settingsMqttTlsSecurityHint;

  /// No description provided for @settingsCloudConnection.
  ///
  /// In en, this message translates to:
  /// **'Cloud connection'**
  String get settingsCloudConnection;

  /// No description provided for @settingsHttpsStatus.
  ///
  /// In en, this message translates to:
  /// **'HTTPS status'**
  String get settingsHttpsStatus;

  /// No description provided for @settingsAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsAdvanced;

  /// No description provided for @settingsConnectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Connection settings'**
  String get settingsConnectionSettings;

  /// No description provided for @settingsPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferences;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Affects all on-screen text. Status codes stay English.'**
  String get settingsLanguageHint;

  /// No description provided for @settingsCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get settingsCloud;

  /// No description provided for @settingsApiBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'API base URL'**
  String get settingsApiBaseUrl;

  /// No description provided for @settingsPollInterval.
  ///
  /// In en, this message translates to:
  /// **'Poll interval'**
  String get settingsPollInterval;

  /// No description provided for @settingsCommandTimeout.
  ///
  /// In en, this message translates to:
  /// **'Command timeout'**
  String get settingsCommandTimeout;

  /// No description provided for @settingsWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get settingsWorkspace;

  /// No description provided for @settingsDeviceInventory.
  ///
  /// In en, this message translates to:
  /// **'Device inventory'**
  String get settingsDeviceInventory;

  /// No description provided for @settingsDeviceInventoryHint.
  ///
  /// In en, this message translates to:
  /// **'Review all cloud devices'**
  String get settingsDeviceInventoryHint;

  /// No description provided for @settingsCloudLogs.
  ///
  /// In en, this message translates to:
  /// **'Cloud logs'**
  String get settingsCloudLogs;

  /// No description provided for @settingsCloudLogsHint.
  ///
  /// In en, this message translates to:
  /// **'Inspect event history'**
  String get settingsCloudLogsHint;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsBuild.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get settingsBuild;

  /// No description provided for @settingsDiagnosticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnosticsLabel;

  /// No description provided for @settingsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Open diagnostics'**
  String get settingsDiagnostics;

  /// No description provided for @settingsSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get settingsSession;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutHint.
  ///
  /// In en, this message translates to:
  /// **'End this account session'**
  String get settingsLogoutHint;

  /// No description provided for @settingsLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get settingsLogoutConfirmTitle;

  /// No description provided for @settingsLogoutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'End this account session on this device.'**
  String get settingsLogoutConfirmBody;

  /// No description provided for @settingsLogoutConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsLogoutConfirmCancel;

  /// No description provided for @settingsLogoutConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogoutConfirmAction;

  /// No description provided for @logsNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No event log yet.'**
  String get logsNoEvents;

  /// No description provided for @environmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get environmentTitle;

  /// No description provided for @temperatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperatureLabel;

  /// No description provided for @humidityLabel.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get humidityLabel;

  /// No description provided for @zigbeeLocalLabel.
  ///
  /// In en, this message translates to:
  /// **'Zigbee local'**
  String get zigbeeLocalLabel;

  /// No description provided for @sensorConditionLabel.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get sensorConditionLabel;

  /// No description provided for @metricLabel.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get metricLabel;

  /// No description provided for @operatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get operatorLabel;

  /// No description provided for @thresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get thresholdLabel;

  /// No description provided for @greaterThanOrEqualLabel.
  ///
  /// In en, this message translates to:
  /// **'Greater than or equal'**
  String get greaterThanOrEqualLabel;

  /// No description provided for @lessThanOrEqualLabel.
  ///
  /// In en, this message translates to:
  /// **'Less than or equal'**
  String get lessThanOrEqualLabel;

  /// No description provided for @degreesCelsiusUnit.
  ///
  /// In en, this message translates to:
  /// **'°C'**
  String get degreesCelsiusUnit;

  /// No description provided for @percentUnit.
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get percentUnit;

  /// No description provided for @scheduleOnTemplate.
  ///
  /// In en, this message translates to:
  /// **'Schedule on'**
  String get scheduleOnTemplate;

  /// No description provided for @scheduleOffTemplate.
  ///
  /// In en, this message translates to:
  /// **'Schedule off'**
  String get scheduleOffTemplate;

  /// No description provided for @scheduleTriggerLabel.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleTriggerLabel;

  /// No description provided for @cronPresetWeekdaySeven.
  ///
  /// In en, this message translates to:
  /// **'Every weekday 07:00'**
  String get cronPresetWeekdaySeven;

  /// No description provided for @cronPresetSundayTwentyTwo.
  ///
  /// In en, this message translates to:
  /// **'Every Sunday 22:00'**
  String get cronPresetSundayTwentyTwo;

  /// No description provided for @cronPresetEverySixHours.
  ///
  /// In en, this message translates to:
  /// **'Every 6 hours'**
  String get cronPresetEverySixHours;

  /// No description provided for @rawCronLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom cron'**
  String get rawCronLabel;

  /// No description provided for @targetTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Target type'**
  String get targetTypeLabel;

  /// No description provided for @directLightLabel.
  ///
  /// In en, this message translates to:
  /// **'Direct light'**
  String get directLightLabel;

  /// No description provided for @sceneLabel.
  ///
  /// In en, this message translates to:
  /// **'Scene'**
  String get sceneLabel;

  /// No description provided for @noScenesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No scenes available'**
  String get noScenesAvailable;

  /// No description provided for @sceneUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Scenes are unavailable. Select a direct light.'**
  String get sceneUnavailableMessage;

  /// No description provided for @invalidCronMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid five-field cron expression'**
  String get invalidCronMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
