import 'dart:convert';
import 'dart:io';

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
    expect(AppLocalizationsEn().temperatureLabel, 'Temperature');
    expect(AppLocalizationsVi().temperatureLabel, 'Nhiệt độ');
    expect(AppLocalizationsEn().saveRuleLabel, 'Save rule');
    expect(AppLocalizationsVi().saveRuleLabel, 'Lưu quy tắc');
  });

  test('English and Vietnamese ARB files expose the same keys', () {
    final english =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, Object?>;
    final vietnamese =
        jsonDecode(File('lib/l10n/app_vi.arb').readAsStringSync())
            as Map<String, Object?>;

    expect(vietnamese.keys.toSet(), english.keys.toSet());
  });

  test('UI source has no unlocalized English text literals', () {
    final patterns = [
      RegExp(r"""\bText\(\s*['"]([^'"]+)['"]"""),
      RegExp(r"""\btooltip:\s*['"]([^'"]+)['"]"""),
      RegExp(r"""\bhintText:\s*['"]([^'"]+)['"]"""),
      RegExp(r"""\blabelText:\s*['"]([^'"]+)['"]"""),
      RegExp(r"""\blabel:\s*['"]([^'"]+)['"]"""),
      RegExp(r"""\btitle:\s*['"]([^'"]+)['"]"""),
    ];
    const allowedTechnicalText = {
      'EUI64',
      '>=',
      '<=',
      '•',
    };
    final violations = <String>[];

    for (final file in Directory('lib/ui').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(source)) {
          final text = match.group(1)!;
          if (text.contains(r'$') ||
              allowedTechnicalText.contains(text) ||
              !RegExp('[A-Za-z]').hasMatch(text)) {
            continue;
          }
          violations.add('${file.path}: $text');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
