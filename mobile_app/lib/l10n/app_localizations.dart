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

  /// No description provided for @themeLightLabel.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLightLabel;

  /// No description provided for @themeDarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDarkLabel;

  /// No description provided for @themeGreyLabel.
  ///
  /// In en, this message translates to:
  /// **'Cream'**
  String get themeGreyLabel;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageEnglishLabel.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglishLabel;

  /// No description provided for @languageVietnameseLabel.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get languageVietnameseLabel;

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

  /// No description provided for @refreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// No description provided for @retryLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryLabel;

  /// No description provided for @cancelLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelLabel;

  /// No description provided for @closeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeTooltip;

  /// No description provided for @backLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backLabel;

  /// No description provided for @deleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteLabel;

  /// No description provided for @deleteRuleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get deleteRuleTooltip;

  /// No description provided for @devicesMetricLabel.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesMetricLabel;

  /// No description provided for @onlineMetricLabel.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get onlineMetricLabel;

  /// No description provided for @unreachableMetricLabel.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get unreachableMetricLabel;

  /// No description provided for @quickLightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick lights'**
  String get quickLightsTitle;

  /// No description provided for @noLightNodeMessage.
  ///
  /// In en, this message translates to:
  /// **'No light node found.'**
  String get noLightNodeMessage;

  /// No description provided for @newRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get newRuleTitle;

  /// No description provided for @newRuleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When something happens, do something.'**
  String get newRuleSubtitle;

  /// No description provided for @createRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Create rule'**
  String get createRuleTitle;

  /// No description provided for @ruleNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Rule name'**
  String get ruleNameLabel;

  /// No description provided for @ruleNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Motion turns on lab lights'**
  String get ruleNameHint;

  /// No description provided for @quickTemplateLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick template'**
  String get quickTemplateLabel;

  /// No description provided for @expandQuickTemplateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Expand quick template'**
  String get expandQuickTemplateTooltip;

  /// No description provided for @collapseQuickTemplateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Collapse quick template'**
  String get collapseQuickTemplateTooltip;

  /// No description provided for @triggerDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Trigger device'**
  String get triggerDeviceLabel;

  /// No description provided for @targetLightsLabel.
  ///
  /// In en, this message translates to:
  /// **'Target lights'**
  String get targetLightsLabel;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @enabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabledLabel;

  /// No description provided for @previewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewLabel;

  /// No description provided for @noTriggerDevicesMessage.
  ///
  /// In en, this message translates to:
  /// **'No switch, motion, or environment sensor available'**
  String get noTriggerDevicesMessage;

  /// No description provided for @noLightDevicesMessage.
  ///
  /// In en, this message translates to:
  /// **'No light devices available'**
  String get noLightDevicesMessage;

  /// No description provided for @chooseTriggerDeviceMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a trigger device first'**
  String get chooseTriggerDeviceMessage;

  /// No description provided for @toggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Toggle'**
  String get toggleLabel;

  /// No description provided for @turnOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOnLabel;

  /// No description provided for @turnOffLabel.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get turnOffLabel;

  /// No description provided for @occupiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get occupiedLabel;

  /// No description provided for @unoccupiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unoccupied'**
  String get unoccupiedLabel;

  /// No description provided for @ruleEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'On - rule is active'**
  String get ruleEnabledLabel;

  /// No description provided for @ruleDisabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Off - rule is not running'**
  String get ruleDisabledLabel;

  /// No description provided for @saveRuleLabel.
  ///
  /// In en, this message translates to:
  /// **'Save rule'**
  String get saveRuleLabel;

  /// No description provided for @automationRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Automation Rules'**
  String get automationRulesTitle;

  /// No description provided for @rulesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get rulesSectionTitle;

  /// No description provided for @ruleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rule} other{{count} rules}}'**
  String ruleCount(int count);

  /// No description provided for @deleteRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete rule?'**
  String get deleteRuleTitle;

  /// No description provided for @deleteRuleBody.
  ///
  /// In en, this message translates to:
  /// **'This removes \"{name}\" from the home hub sync list.'**
  String deleteRuleBody(String name);

  /// No description provided for @ruleCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Rule created. Waiting for home hub sync.'**
  String get ruleCreatedMessage;

  /// No description provided for @noMatchingDeviceMessage.
  ///
  /// In en, this message translates to:
  /// **'No matching device found.'**
  String get noMatchingDeviceMessage;

  /// No description provided for @clearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearchTooltip;

  /// No description provided for @notificationCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Center'**
  String get notificationCenterTitle;

  /// No description provided for @markAllReadLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllReadLabel;

  /// No description provided for @unreadCount.
  ///
  /// In en, this message translates to:
  /// **'Unread {count}'**
  String unreadCount(int count);

  /// No description provided for @importantEventsLabel.
  ///
  /// In en, this message translates to:
  /// **'Important cloud and home hub events'**
  String get importantEventsLabel;

  /// No description provided for @noNotificationsMessage.
  ///
  /// In en, this message translates to:
  /// **'No notifications in this category.'**
  String get noNotificationsMessage;

  /// No description provided for @markReadLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark read'**
  String get markReadLabel;

  /// No description provided for @notificationCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationCategoryAll;

  /// No description provided for @notificationCategoryCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get notificationCategoryCommand;

  /// No description provided for @notificationCategoryAutomation.
  ///
  /// In en, this message translates to:
  /// **'Automation'**
  String get notificationCategoryAutomation;

  /// No description provided for @notificationCategoryGateway.
  ///
  /// In en, this message translates to:
  /// **'Home hub'**
  String get notificationCategoryGateway;

  /// No description provided for @notificationCategoryDevice.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get notificationCategoryDevice;

  /// No description provided for @notificationCategorySystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notificationCategorySystem;

  /// No description provided for @notificationCategoryOta.
  ///
  /// In en, this message translates to:
  /// **'OTA'**
  String get notificationCategoryOta;

  /// No description provided for @notificationCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get notificationCategoryOther;

  /// No description provided for @profileUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileUsernameLabel;

  /// No description provided for @profileUserIdLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get profileUserIdLabel;

  /// No description provided for @profileRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get profileRoleLabel;

  /// No description provided for @profileHomeIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Home ID'**
  String get profileHomeIdLabel;

  /// No description provided for @profileExpiresAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Expires at'**
  String get profileExpiresAtLabel;

  /// No description provided for @profileApiLabel.
  ///
  /// In en, this message translates to:
  /// **'API'**
  String get profileApiLabel;

  /// No description provided for @provisioningWizardTitle.
  ///
  /// In en, this message translates to:
  /// **'Provisioning wizard'**
  String get provisioningWizardTitle;

  /// No description provided for @roomIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Room ID'**
  String get roomIdLabel;

  /// No description provided for @scanQrLabel.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQrLabel;

  /// No description provided for @useManualLabel.
  ///
  /// In en, this message translates to:
  /// **'Use manual'**
  String get useManualLabel;

  /// No description provided for @qrJsonLabel.
  ///
  /// In en, this message translates to:
  /// **'QR JSON'**
  String get qrJsonLabel;

  /// No description provided for @clearLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearLabel;

  /// No description provided for @startProvisioningLabel.
  ///
  /// In en, this message translates to:
  /// **'Start provisioning'**
  String get startProvisioningLabel;

  /// No description provided for @scanProvisioningQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan provisioning QR'**
  String get scanProvisioningQrTitle;

  /// No description provided for @provisioningSessionCreated.
  ///
  /// In en, this message translates to:
  /// **'Session created in Cloud.'**
  String get provisioningSessionCreated;

  /// No description provided for @provisioningPermitOpen.
  ///
  /// In en, this message translates to:
  /// **'Device join window is accepting this device.'**
  String get provisioningPermitOpen;

  /// No description provided for @provisioningJoining.
  ///
  /// In en, this message translates to:
  /// **'Device is joining the Zigbee network.'**
  String get provisioningJoining;

  /// No description provided for @provisioningJoined.
  ///
  /// In en, this message translates to:
  /// **'Device joined and is ready for room use.'**
  String get provisioningJoined;

  /// No description provided for @provisioningFailed.
  ///
  /// In en, this message translates to:
  /// **'Provisioning failed.'**
  String get provisioningFailed;

  /// No description provided for @provisioningExpired.
  ///
  /// In en, this message translates to:
  /// **'Provisioning session expired.'**
  String get provisioningExpired;

  /// No description provided for @provisioningCancelled.
  ///
  /// In en, this message translates to:
  /// **'Provisioning session cancelled.'**
  String get provisioningCancelled;

  /// No description provided for @provisioningReady.
  ///
  /// In en, this message translates to:
  /// **'Enter room and device identity.'**
  String get provisioningReady;

  /// No description provided for @deviceIdentityRequired.
  ///
  /// In en, this message translates to:
  /// **'Device identity required'**
  String get deviceIdentityRequired;

  /// No description provided for @deviceIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Device identity'**
  String get deviceIdentityTitle;

  /// No description provided for @deviceTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get deviceTypeLabel;

  /// No description provided for @modelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelLabel;

  /// No description provided for @deviceDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Device detail'**
  String get deviceDetailTitle;

  /// No description provided for @renameDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Rename device'**
  String get renameDeviceLabel;

  /// No description provided for @recentEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent events'**
  String get recentEventsTitle;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameLabel;

  /// No description provided for @saveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @roomLabel.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get roomLabel;

  /// No description provided for @occupancyLabel.
  ///
  /// In en, this message translates to:
  /// **'Occupancy'**
  String get occupancyLabel;

  /// No description provided for @reportedLabel.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get reportedLabel;

  /// No description provided for @onlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get onlineLabel;

  /// No description provided for @offlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineLabel;

  /// No description provided for @occupancyOccupiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get occupancyOccupiedLabel;

  /// No description provided for @occupancyUnoccupiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unoccupied'**
  String get occupancyUnoccupiedLabel;

  /// No description provided for @occupancyUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get occupancyUnknownLabel;

  /// No description provided for @occupancyTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Occupancy timeline'**
  String get occupancyTimelineTitle;

  /// No description provided for @latestOccupancyLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest occupancy'**
  String get latestOccupancyLabel;

  /// No description provided for @noEventYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No event yet'**
  String get noEventYetMessage;

  /// No description provided for @noOccupancyEventMessage.
  ///
  /// In en, this message translates to:
  /// **'No occupancy event for this sensor.'**
  String get noOccupancyEventMessage;

  /// No description provided for @commandSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Sent to Cloud API'**
  String get commandSentMessage;

  /// No description provided for @commandQueuedMessage.
  ///
  /// In en, this message translates to:
  /// **'Queued by home hub'**
  String get commandQueuedMessage;

  /// No description provided for @commandWaitingMessage.
  ///
  /// In en, this message translates to:
  /// **'Waiting for device reply'**
  String get commandWaitingMessage;

  /// No description provided for @commandAcknowledgedMessage.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged by home hub'**
  String get commandAcknowledgedMessage;

  /// No description provided for @commandFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Command failed'**
  String get commandFailedMessage;

  /// No description provided for @commandTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'No reply within polling window'**
  String get commandTimeoutMessage;

  /// No description provided for @noActiveCommandMessage.
  ///
  /// In en, this message translates to:
  /// **'No active command'**
  String get noActiveCommandMessage;

  /// No description provided for @lastCommandTitle.
  ///
  /// In en, this message translates to:
  /// **'Last command'**
  String get lastCommandTitle;

  /// No description provided for @noneLabel.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get noneLabel;

  /// No description provided for @retryTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry {target}'**
  String retryTargetLabel(String target);

  /// No description provided for @noRecentEventMessage.
  ///
  /// In en, this message translates to:
  /// **'No recent event for this device.'**
  String get noRecentEventMessage;

  /// No description provided for @deviceRegistryUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Device registry updated'**
  String get deviceRegistryUpdatedMessage;

  /// No description provided for @gatewayHealthUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Home hub health updated'**
  String get gatewayHealthUpdatedMessage;

  /// No description provided for @eventUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Event updated'**
  String get eventUpdatedMessage;

  /// No description provided for @errorTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The network response took too long. Try again.'**
  String get errorTimeoutMessage;

  /// No description provided for @errorOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Check Wi-Fi or mobile data.'**
  String get errorOfflineMessage;

  /// No description provided for @errorValidationMessage.
  ///
  /// In en, this message translates to:
  /// **'The data is invalid. Check the input fields.'**
  String get errorValidationMessage;

  /// No description provided for @errorUnauthorizedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your session is invalid. Sign in again.'**
  String get errorUnauthorizedMessage;

  /// No description provided for @errorServerMessage.
  ///
  /// In en, this message translates to:
  /// **'The server has a problem. Try again later.'**
  String get errorServerMessage;

  /// No description provided for @errorUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred. Try again.'**
  String get errorUnknownMessage;

  /// No description provided for @errorLoginContext.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get errorLoginContext;

  /// No description provided for @errorPasswordChangeContext.
  ///
  /// In en, this message translates to:
  /// **'Password change failed'**
  String get errorPasswordChangeContext;

  /// No description provided for @errorLoadRulesContext.
  ///
  /// In en, this message translates to:
  /// **'Could not load automation rules'**
  String get errorLoadRulesContext;

  /// No description provided for @errorCreateRuleContext.
  ///
  /// In en, this message translates to:
  /// **'Could not create automation rule'**
  String get errorCreateRuleContext;

  /// No description provided for @errorDeleteRuleContext.
  ///
  /// In en, this message translates to:
  /// **'Could not delete automation rule'**
  String get errorDeleteRuleContext;

  /// No description provided for @errorUpdateRuleContext.
  ///
  /// In en, this message translates to:
  /// **'Could not update automation rule'**
  String get errorUpdateRuleContext;

  /// No description provided for @errorCloudConnectionContext.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to Cloud API'**
  String get errorCloudConnectionContext;

  /// No description provided for @errorRenameDeviceContext.
  ///
  /// In en, this message translates to:
  /// **'Could not rename device'**
  String get errorRenameDeviceContext;

  /// No description provided for @gatewayOnlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Home hub online'**
  String get gatewayOnlineTitle;

  /// No description provided for @gatewayOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Home hub offline'**
  String get gatewayOfflineTitle;

  /// No description provided for @gatewayUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Home hub status unknown'**
  String get gatewayUnknownTitle;

  /// No description provided for @gatewayMockTitle.
  ///
  /// In en, this message translates to:
  /// **'Mock home hub log'**
  String get gatewayMockTitle;

  /// No description provided for @gatewayLastReport.
  ///
  /// In en, this message translates to:
  /// **'Last report: {time}'**
  String gatewayLastReport(String time);

  /// No description provided for @gatewayLatestEvent.
  ///
  /// In en, this message translates to:
  /// **'Latest cloud event received'**
  String get gatewayLatestEvent;

  /// No description provided for @gatewayNoStatus.
  ///
  /// In en, this message translates to:
  /// **'No home hub status log found'**
  String get gatewayNoStatus;

  /// No description provided for @gatewayOfflineDetail.
  ///
  /// In en, this message translates to:
  /// **'Home hub reported offline'**
  String get gatewayOfflineDetail;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Account access to your Smart Home.'**
  String get signInSubtitle;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @usernameRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get usernameRequiredMessage;

  /// No description provided for @passwordRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordRequiredMessage;

  /// No description provided for @loginAction.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginAction;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @requiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredMessage;

  /// No description provided for @passwordMinimumMessage.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get passwordMinimumMessage;

  /// No description provided for @updatePasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePasswordAction;

  /// No description provided for @emptyRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'No automation rules yet'**
  String get emptyRulesTitle;

  /// No description provided for @emptyRulesBody.
  ///
  /// In en, this message translates to:
  /// **'Create a rule for motion, switch, or environment sensor events. Cloud saves it and syncs it to your home hub.'**
  String get emptyRulesBody;

  /// No description provided for @whenLabel.
  ///
  /// In en, this message translates to:
  /// **'WHEN'**
  String get whenLabel;

  /// No description provided for @thenLabel.
  ///
  /// In en, this message translates to:
  /// **'THEN'**
  String get thenLabel;

  /// No description provided for @occupancyChangesLabel.
  ///
  /// In en, this message translates to:
  /// **'occupancy changes'**
  String get occupancyChangesLabel;

  /// No description provided for @occupancyChangesValue.
  ///
  /// In en, this message translates to:
  /// **'occupancy changes: {value}'**
  String occupancyChangesValue(String value);

  /// No description provided for @togglesLabel.
  ///
  /// In en, this message translates to:
  /// **'toggles'**
  String get togglesLabel;

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

  /// No description provided for @scheduleModeHourly.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get scheduleModeHourly;

  /// No description provided for @scheduleModeDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get scheduleModeDaily;

  /// No description provided for @scheduleModeWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get scheduleModeWeekdays;

  /// No description provided for @scheduleModeWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get scheduleModeWeekly;

  /// No description provided for @scheduleModeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get scheduleModeCustom;

  /// No description provided for @scheduleTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'At'**
  String get scheduleTimeLabel;

  /// No description provided for @scheduleMinuteLabel.
  ///
  /// In en, this message translates to:
  /// **'At minute'**
  String get scheduleMinuteLabel;

  /// No description provided for @scheduleSummaryPrefix.
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get scheduleSummaryPrefix;

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
