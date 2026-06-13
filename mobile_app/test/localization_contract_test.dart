import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/l10n/app_localizations_en.dart';
import 'package:zigbee_smart_building/l10n/app_localizations_vi.dart';

void main() {
  test('environment schedule and scene keys exist in both locales', () {
    expect(AppLocalizationsEn().environmentTitle, 'Environment');
    expect(AppLocalizationsVi().environmentTitle, 'Môi trường');
    expect(AppLocalizationsEn().scheduleOnTemplate, 'Schedule on');
    expect(AppLocalizationsVi().scheduleOnTemplate, 'Lịch bật');
    expect(AppLocalizationsEn().noScenesAvailable, 'No scenes available');
    expect(AppLocalizationsVi().noScenesAvailable, 'Không có scene khả dụng');
  });
}
