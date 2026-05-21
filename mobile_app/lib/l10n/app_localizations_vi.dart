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
  String get profileGateway => 'Gateway';

  @override
  String get profileActions => 'Tác vụ';

  @override
  String get profileChangePassword => 'Đổi mật khẩu';

  @override
  String get profileCopyToken => 'Sao chép API token';

  @override
  String get profileSignOut => 'Đăng xuất';

  @override
  String get settingsOperator => 'Người vận hành';

  @override
  String get settingsAccount => 'Tài khoản';

  @override
  String get settingsAppearance => 'Giao diện';

  @override
  String get settingsTheme => 'Chủ đề';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

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
  String get settingsLogout => 'Đăng xuất';

  @override
  String get settingsLogoutHint => 'Kết thúc phiên vận hành';

  @override
  String get logsNoEvents => 'Chưa có nhật ký sự kiện.';
}
