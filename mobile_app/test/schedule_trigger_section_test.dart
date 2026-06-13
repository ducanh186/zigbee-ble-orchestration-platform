import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/l10n/app_localizations.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/features/automation/widgets/schedule_trigger_section.dart';

void main() {
  testWidgets('weekday preset emits canonical cron', (tester) async {
    ScheduleSelection? selected;
    await tester.pumpWidget(
      _wrap(ScheduleTriggerSection(onChanged: (value) => selected = value)),
    );

    await tester.tap(find.text('Every weekday 07:00'));
    await tester.pump();

    expect(selected?.cron, '0 7 * * 1-5');
    expect(selected?.isValid, isTrue);
  });

  testWidgets('Sunday and six-hour presets serialize correctly', (
    tester,
  ) async {
    ScheduleSelection? selected;
    await tester.pumpWidget(
      _wrap(ScheduleTriggerSection(onChanged: (value) => selected = value)),
    );

    await tester.tap(find.text('Every Sunday 22:00'));
    await tester.pump();
    expect(selected?.cron, '0 22 * * 0');

    await tester.tap(find.text('Every 6 hours'));
    await tester.pump();
    expect(selected?.cron, '0 */6 * * *');
  });

  testWidgets('invalid custom cron reports form error without helper text', (
    tester,
  ) async {
    ScheduleSelection? selected;
    String? validationMessage;
    await tester.pumpWidget(
      _wrap(
        ScheduleTriggerSection(
          onChanged: (value) => selected = value,
          onValidationChanged: (value) => validationMessage = value,
        ),
      ),
    );

    await tester.tap(find.text('Custom cron'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('raw-cron-field')), 'bad cron');
    await tester.pump();

    expect(selected?.isValid, isFalse);
    expect(validationMessage, 'Enter a valid five-field cron expression');
    expect(find.text(validationMessage!), findsNothing);
    final field = tester.widget<TextField>(
      find.byKey(const Key('raw-cron-field')),
    );
    expect(field.decoration?.helperText, isNull);
    expect(field.decoration?.errorText, isNull);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.theme(AppThemeMode.light),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}
