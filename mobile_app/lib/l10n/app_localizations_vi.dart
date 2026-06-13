// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Zigbee Smart Building';

  @override
  String get homeTab => 'Trang chủ';

  @override
  String get automationTab => 'Tự động hóa';

  @override
  String get provisioningTab => 'Provisioning';

  @override
  String get settingsTab => 'Cài đặt';

  @override
  String get devicesTitle => 'Thiết bị';

  @override
  String get logsTitle => 'Nhật ký';

  @override
  String get searchDevices => 'Tìm thiết bị';

  @override
  String get eventPayload => 'Nội dung sự kiện';

  @override
  String get profileTitle => 'Hồ sơ';

  @override
  String get profileRoleTech => 'Kỹ thuật hiện trường';

  @override
  String get profileSession => 'Phiên làm việc';

  @override
  String get profileOrganization => 'Tổ chức';

  @override
  String get profileSignedIn => 'Đăng nhập từ';

  @override
  String get profileApiEndpoint => 'Cloud endpoint';

  @override
  String get profileActions => 'Tác vụ';

  @override
  String get profileChangePassword => 'Đổi mật khẩu';

  @override
  String get profileCopyToken => 'Sao chép API token';

  @override
  String get profileSignOut => 'Đăng xuất';

  @override
  String get settingsAccountCenter => 'Cài đặt';

  @override
  String get settingsAccount => 'Tài khoản';

  @override
  String get settingsAccountDetails => 'Chi tiết tài khoản';

  @override
  String get settingsRole => 'Vai trò';

  @override
  String get settingsHomeScope => 'Phạm vi home';

  @override
  String get settingsHomeSummary => 'Tóm tắt home';

  @override
  String get settingsRolePermissions => 'Quyền vai trò';

  @override
  String get settingsMember => 'Thành viên';

  @override
  String get settingsMemberHint =>
      'Chỉ xem: thiết bị, state, motion và event log';

  @override
  String get settingsParentHomeOwner => 'Chủ nhà';

  @override
  String get settingsParentHomeOwnerHint => 'Toàn quyền trong home của mình';

  @override
  String get settingsSystemAdmin => 'Quản trị hệ thống';

  @override
  String get settingsSystemAdminHint => 'Quyền kỹ thuật và production system';

  @override
  String get settingsHomeManagement => 'Quản lý home';

  @override
  String get settingsDevices => 'Thiết bị';

  @override
  String get settingsAddNewDevice => 'Thêm thiết bị mới';

  @override
  String get settingsAutomationRules => 'Luật tự động hóa';

  @override
  String get settingsActivityHistory => 'Lịch sử hoạt động';

  @override
  String get settingsDeviceControl => 'Điều khiển thiết bị';

  @override
  String get settingsDeviceControlHint => 'Bật hoặc tắt light trong home này';

  @override
  String get settingsAutomationCrud => 'Automation CRUD';

  @override
  String get settingsAutomationCrudHint => 'Tạo, sửa, bật, tắt và xóa rule';

  @override
  String get settingsProvisioningDevice => 'Provisioning thiết bị';

  @override
  String get settingsProvisioningDeviceHint => 'Thêm thiết bị mới vào home này';

  @override
  String get settingsDeleteDevice => 'Xóa device';

  @override
  String get settingsDeleteDeviceHint => 'Chỉ xóa device thuộc home này';

  @override
  String get settingsRediscoverDevice => 'Rediscover device';

  @override
  String get settingsRediscoverDeviceHint =>
      'Yêu cầu home hub phân loại lại device trong home';

  @override
  String get settingsSystemOnly => 'Chỉ hệ thống';

  @override
  String get settingsProductionConfig => 'Cấu hình production';

  @override
  String get settingsProductionConfigHint =>
      'Chỉ admin được đổi tenant, site và định danh hệ thống';

  @override
  String get settingsMqttTlsSecurity => 'Bảo mật MQTT/TLS';

  @override
  String get settingsMqttTlsSecurityHint =>
      'Chỉ admin được đổi broker, certificate và security config';

  @override
  String get settingsCloudConnection => 'Kết nối cloud';

  @override
  String get settingsHttpsStatus => 'Trạng thái HTTPS';

  @override
  String get settingsAdvanced => 'Nâng cao';

  @override
  String get settingsConnectionSettings => 'Cài đặt kết nối';

  @override
  String get settingsPreferences => 'Tùy chọn';

  @override
  String get settingsAppearance => 'Giao diện';

  @override
  String get settingsTheme => 'Chủ đề';

  @override
  String get themeLightLabel => 'Sáng';

  @override
  String get themeDarkLabel => 'Tối';

  @override
  String get themeGreyLabel => 'Màu kem';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get languageEnglishLabel => 'Tiếng Anh';

  @override
  String get languageVietnameseLabel => 'Tiếng Việt';

  @override
  String get settingsLanguageHint =>
      'Đổi chữ trong app. Mã trạng thái giữ English.';

  @override
  String get settingsCloud => 'Cloud';

  @override
  String get settingsApiBaseUrl => 'API base URL';

  @override
  String get settingsPollInterval => 'Chu kỳ poll';

  @override
  String get settingsCommandTimeout => 'Timeout lệnh';

  @override
  String get settingsWorkspace => 'Workspace';

  @override
  String get settingsDeviceInventory => 'Danh sách thiết bị';

  @override
  String get settingsDeviceInventoryHint => 'Xem tất cả thiết bị cloud';

  @override
  String get settingsCloudLogs => 'Nhật ký cloud';

  @override
  String get settingsCloudLogsHint => 'Xem lịch sử sự kiện';

  @override
  String get settingsAbout => 'Thông tin';

  @override
  String get settingsVersion => 'Phiên bản';

  @override
  String get settingsBuild => 'Build';

  @override
  String get settingsDiagnosticsLabel => 'Chẩn đoán';

  @override
  String get settingsDiagnostics => 'Mở chẩn đoán';

  @override
  String get settingsSession => 'Phiên';

  @override
  String get settingsLogout => 'Đăng xuất';

  @override
  String get settingsLogoutHint => 'Kết thúc phiên tài khoản';

  @override
  String get settingsLogoutConfirmTitle => 'Đăng xuất?';

  @override
  String get settingsLogoutConfirmBody =>
      'Kết thúc phiên tài khoản trên thiết bị này.';

  @override
  String get settingsLogoutConfirmCancel => 'Hủy';

  @override
  String get settingsLogoutConfirmAction => 'Đăng xuất';

  @override
  String get logsNoEvents => 'Chưa có nhật ký sự kiện.';

  @override
  String get refreshTooltip => 'Làm mới';

  @override
  String get retryLabel => 'Thử lại';

  @override
  String get cancelLabel => 'Hủy';

  @override
  String get closeTooltip => 'Đóng';

  @override
  String get backLabel => 'Quay lại';

  @override
  String get deleteLabel => 'Xóa';

  @override
  String get deleteRuleTooltip => 'Xóa quy tắc';

  @override
  String get devicesMetricLabel => 'Thiết bị';

  @override
  String get onlineMetricLabel => 'Trực tuyến';

  @override
  String get unreachableMetricLabel => 'Mất kết nối';

  @override
  String get quickLightsTitle => 'Điều khiển đèn nhanh';

  @override
  String get noLightNodeMessage => 'Không tìm thấy thiết bị đèn.';

  @override
  String get newRuleTitle => 'Quy tắc mới';

  @override
  String get newRuleSubtitle =>
      'Khi có điều gì xảy ra, thực hiện một hành động.';

  @override
  String get createRuleTitle => 'Tạo quy tắc';

  @override
  String get ruleNameLabel => 'Tên quy tắc';

  @override
  String get ruleNameHint => 'Ví dụ: Có chuyển động thì bật đèn phòng lab';

  @override
  String get quickTemplateLabel => 'Mẫu nhanh';

  @override
  String get expandQuickTemplateTooltip => 'Mở danh sách mẫu nhanh';

  @override
  String get collapseQuickTemplateTooltip => 'Thu gọn danh sách mẫu nhanh';

  @override
  String get triggerDeviceLabel => 'Thiết bị kích hoạt';

  @override
  String get targetLightsLabel => 'Đèn mục tiêu';

  @override
  String selectedCount(int count) {
    return 'Đã chọn $count';
  }

  @override
  String get enabledLabel => 'Kích hoạt';

  @override
  String get previewLabel => 'Xem trước';

  @override
  String get noTriggerDevicesMessage =>
      'Không có switch, motion hoặc environment sensor khả dụng';

  @override
  String get noLightDevicesMessage => 'Không có thiết bị đèn khả dụng';

  @override
  String get chooseTriggerDeviceMessage => 'Hãy chọn thiết bị kích hoạt trước';

  @override
  String get toggleLabel => 'Đảo trạng thái';

  @override
  String get turnOnLabel => 'Bật';

  @override
  String get turnOffLabel => 'Tắt';

  @override
  String get occupiedLabel => 'Có người';

  @override
  String get unoccupiedLabel => 'Không có người';

  @override
  String get ruleEnabledLabel => 'Bật - quy tắc đang hoạt động';

  @override
  String get ruleDisabledLabel => 'Tắt - quy tắc không hoạt động';

  @override
  String get saveRuleLabel => 'Lưu quy tắc';

  @override
  String get automationRulesTitle => 'Quy tắc automation';

  @override
  String get rulesSectionTitle => 'Danh sách quy tắc';

  @override
  String ruleCount(int count) {
    return '$count quy tắc';
  }

  @override
  String get deleteRuleTitle => 'Xóa quy tắc?';

  @override
  String deleteRuleBody(String name) {
    return 'Thao tác này xóa \"$name\" khỏi danh sách đồng bộ của home hub.';
  }

  @override
  String get ruleCreatedMessage =>
      'Đã tạo quy tắc. Đang chờ đồng bộ xuống home hub.';

  @override
  String get noMatchingDeviceMessage => 'Không tìm thấy thiết bị phù hợp.';

  @override
  String get clearSearchTooltip => 'Xóa nội dung tìm kiếm';

  @override
  String get notificationCenterTitle => 'Trung tâm thông báo';

  @override
  String get markAllReadLabel => 'Đánh dấu tất cả đã đọc';

  @override
  String unreadCount(int count) {
    return 'Chưa đọc $count';
  }

  @override
  String get importantEventsLabel => 'Sự kiện quan trọng từ Cloud và home hub';

  @override
  String get noNotificationsMessage => 'Không có thông báo trong nhóm này.';

  @override
  String get markReadLabel => 'Đánh dấu đã đọc';

  @override
  String get notificationCategoryAll => 'Tất cả';

  @override
  String get notificationCategoryCommand => 'Lệnh';

  @override
  String get notificationCategoryAutomation => 'Automation';

  @override
  String get notificationCategoryGateway => 'Home hub';

  @override
  String get notificationCategoryDevice => 'Thiết bị';

  @override
  String get notificationCategorySystem => 'Hệ thống';

  @override
  String get notificationCategoryOta => 'OTA';

  @override
  String get notificationCategoryOther => 'Khác';

  @override
  String get profileUsernameLabel => 'Tên đăng nhập';

  @override
  String get profileUserIdLabel => 'Mã người dùng';

  @override
  String get profileRoleLabel => 'Vai trò';

  @override
  String get profileHomeIdLabel => 'Mã nhà';

  @override
  String get profileExpiresAtLabel => 'Hết hạn lúc';

  @override
  String get profileApiLabel => 'API';

  @override
  String get provisioningWizardTitle => 'Trình hướng dẫn provisioning';

  @override
  String get roomIdLabel => 'Mã phòng';

  @override
  String get scanQrLabel => 'Quét QR';

  @override
  String get useManualLabel => 'Nhập thủ công';

  @override
  String get qrJsonLabel => 'QR JSON';

  @override
  String get clearLabel => 'Xóa';

  @override
  String get startProvisioningLabel => 'Bắt đầu provisioning';

  @override
  String get scanProvisioningQrTitle => 'Quét QR provisioning';

  @override
  String get provisioningSessionCreated => 'Đã tạo phiên trên Cloud.';

  @override
  String get provisioningPermitOpen =>
      'Cửa sổ join đang chấp nhận thiết bị này.';

  @override
  String get provisioningJoining => 'Thiết bị đang join vào mạng Zigbee.';

  @override
  String get provisioningJoined =>
      'Thiết bị đã join và sẵn sàng sử dụng trong phòng.';

  @override
  String get provisioningFailed => 'Provisioning thất bại.';

  @override
  String get provisioningExpired => 'Phiên provisioning đã hết hạn.';

  @override
  String get provisioningCancelled => 'Phiên provisioning đã bị hủy.';

  @override
  String get provisioningReady => 'Nhập phòng và định danh thiết bị.';

  @override
  String get deviceIdentityRequired => 'Cần định danh thiết bị';

  @override
  String get deviceIdentityTitle => 'Định danh thiết bị';

  @override
  String get deviceTypeLabel => 'Loại';

  @override
  String get modelLabel => 'Model';

  @override
  String get deviceDetailTitle => 'Chi tiết thiết bị';

  @override
  String get renameDeviceLabel => 'Đổi tên thiết bị';

  @override
  String get recentEventsTitle => 'Sự kiện gần đây';

  @override
  String get displayNameLabel => 'Tên hiển thị';

  @override
  String get saveLabel => 'Lưu';

  @override
  String get statusLabel => 'Trạng thái';

  @override
  String get roomLabel => 'Phòng';

  @override
  String get occupancyLabel => 'Trạng thái có người';

  @override
  String get reportedLabel => 'Báo cáo lúc';

  @override
  String get onlineLabel => 'Trực tuyến';

  @override
  String get offlineLabel => 'Ngoại tuyến';

  @override
  String get occupancyOccupiedLabel => 'Có người';

  @override
  String get occupancyUnoccupiedLabel => 'Không có người';

  @override
  String get occupancyUnknownLabel => 'Chưa xác định';

  @override
  String get occupancyTimelineTitle => 'Lịch sử trạng thái có người';

  @override
  String get latestOccupancyLabel => 'Trạng thái gần nhất';

  @override
  String get noEventYetMessage => 'Chưa có sự kiện';

  @override
  String get noOccupancyEventMessage =>
      'Chưa có sự kiện occupancy cho sensor này.';

  @override
  String get commandSentMessage => 'Đã gửi tới Cloud API';

  @override
  String get commandQueuedMessage => 'Home hub đã đưa lệnh vào hàng đợi';

  @override
  String get commandWaitingMessage => 'Đang chờ thiết bị phản hồi';

  @override
  String get commandAcknowledgedMessage => 'Home hub đã xác nhận lệnh';

  @override
  String get commandFailedMessage => 'Lệnh thất bại';

  @override
  String get commandTimeoutMessage => 'Không có phản hồi trong thời gian chờ';

  @override
  String get noActiveCommandMessage => 'Không có lệnh đang chạy';

  @override
  String get lastCommandTitle => 'Lệnh gần nhất';

  @override
  String get noneLabel => 'không có';

  @override
  String retryTargetLabel(String target) {
    return 'Thử lại $target';
  }

  @override
  String get noRecentEventMessage => 'Thiết bị này chưa có sự kiện gần đây.';

  @override
  String get deviceRegistryUpdatedMessage => 'Đã cập nhật device registry';

  @override
  String get gatewayHealthUpdatedMessage => 'Đã cập nhật trạng thái home hub';

  @override
  String get eventUpdatedMessage => 'Đã cập nhật sự kiện';

  @override
  String get errorTimeoutMessage => 'Mạng phản hồi quá lâu. Vui lòng thử lại.';

  @override
  String get errorOfflineMessage =>
      'Không có kết nối mạng. Hãy kiểm tra Wi-Fi hoặc dữ liệu di động.';

  @override
  String get errorValidationMessage =>
      'Dữ liệu không hợp lệ. Hãy kiểm tra lại các trường nhập.';

  @override
  String get errorUnauthorizedMessage =>
      'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.';

  @override
  String get errorServerMessage =>
      'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';

  @override
  String get errorUnknownMessage =>
      'Đã xảy ra lỗi chưa xác định. Vui lòng thử lại.';

  @override
  String get errorLoginContext => 'Đăng nhập thất bại';

  @override
  String get errorPasswordChangeContext => 'Đổi mật khẩu thất bại';

  @override
  String get errorLoadRulesContext => 'Không tải được quy tắc automation';

  @override
  String get errorCreateRuleContext => 'Không tạo được quy tắc automation';

  @override
  String get errorDeleteRuleContext => 'Không xóa được quy tắc automation';

  @override
  String get errorUpdateRuleContext => 'Không cập nhật được quy tắc automation';

  @override
  String get errorCloudConnectionContext => 'Không kết nối được Cloud API';

  @override
  String get errorRenameDeviceContext => 'Không đổi được tên thiết bị';

  @override
  String get gatewayOnlineTitle => 'Home hub đang trực tuyến';

  @override
  String get gatewayOfflineTitle => 'Home hub đang ngoại tuyến';

  @override
  String get gatewayUnknownTitle => 'Chưa xác định trạng thái home hub';

  @override
  String get gatewayMockTitle => 'Nhật ký home hub mô phỏng';

  @override
  String gatewayLastReport(String time) {
    return 'Báo cáo gần nhất: $time';
  }

  @override
  String get gatewayLatestEvent => 'Đã nhận sự kiện Cloud gần nhất';

  @override
  String get gatewayNoStatus => 'Không tìm thấy nhật ký trạng thái home hub';

  @override
  String get gatewayOfflineDetail => 'Home hub báo đang ngoại tuyến';

  @override
  String get signInTitle => 'Đăng nhập';

  @override
  String get signInSubtitle => 'Truy cập tài khoản Smart Home của bạn.';

  @override
  String get usernameLabel => 'Tên đăng nhập';

  @override
  String get passwordLabel => 'Mật khẩu';

  @override
  String get usernameRequiredMessage => 'Hãy nhập tên đăng nhập';

  @override
  String get passwordRequiredMessage => 'Hãy nhập mật khẩu';

  @override
  String get loginAction => 'Đăng nhập';

  @override
  String get changePasswordTitle => 'Đổi mật khẩu';

  @override
  String get currentPasswordLabel => 'Mật khẩu hiện tại';

  @override
  String get newPasswordLabel => 'Mật khẩu mới';

  @override
  String get requiredMessage => 'Bắt buộc';

  @override
  String get passwordMinimumMessage => 'Sử dụng ít nhất 8 ký tự';

  @override
  String get updatePasswordAction => 'Cập nhật mật khẩu';

  @override
  String get emptyRulesTitle => 'Chưa có quy tắc automation';

  @override
  String get emptyRulesBody =>
      'Tạo quy tắc cho sự kiện từ motion, switch hoặc environment sensor. Cloud sẽ lưu và đồng bộ xuống home hub.';

  @override
  String get whenLabel => 'KHI';

  @override
  String get thenLabel => 'THÌ';

  @override
  String get occupancyChangesLabel => 'trạng thái có người thay đổi';

  @override
  String occupancyChangesValue(String value) {
    return 'trạng thái có người thay đổi: $value';
  }

  @override
  String get togglesLabel => 'đảo trạng thái';

  @override
  String get environmentTitle => 'Môi trường';

  @override
  String get temperatureLabel => 'Nhiệt độ';

  @override
  String get humidityLabel => 'Độ ẩm';

  @override
  String get zigbeeLocalLabel => 'Zigbee nội bộ';

  @override
  String get sensorConditionLabel => 'Điều kiện';

  @override
  String get metricLabel => 'Chỉ số';

  @override
  String get operatorLabel => 'Toán tử';

  @override
  String get thresholdLabel => 'Ngưỡng';

  @override
  String get greaterThanOrEqualLabel => 'Lớn hơn hoặc bằng';

  @override
  String get lessThanOrEqualLabel => 'Nhỏ hơn hoặc bằng';

  @override
  String get degreesCelsiusUnit => '°C';

  @override
  String get percentUnit => '%';

  @override
  String get scheduleOnTemplate => 'Lịch bật';

  @override
  String get scheduleOffTemplate => 'Lịch tắt';

  @override
  String get scheduleTriggerLabel => 'Lịch';

  @override
  String get cronPresetWeekdaySeven => 'Mỗi ngày trong tuần lúc 07:00';

  @override
  String get cronPresetSundayTwentyTwo => 'Mỗi Chủ nhật lúc 22:00';

  @override
  String get cronPresetEverySixHours => 'Mỗi 6 giờ';

  @override
  String get rawCronLabel => 'Cron tùy chỉnh';

  @override
  String get targetTypeLabel => 'Loại mục tiêu';

  @override
  String get directLightLabel => 'Đèn trực tiếp';

  @override
  String get sceneLabel => 'Scene';

  @override
  String get noScenesAvailable => 'Không có scene khả dụng';

  @override
  String get sceneUnavailableMessage =>
      'Scene chưa khả dụng. Hãy chọn một đèn trực tiếp.';

  @override
  String get invalidCronMessage => 'Nhập biểu thức cron hợp lệ gồm năm trường';
}
