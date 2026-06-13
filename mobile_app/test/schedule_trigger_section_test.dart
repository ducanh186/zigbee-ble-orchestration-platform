import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/l10n/app_localizations.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/features/automation/widgets/schedule_trigger_section.dart';

void main() {
  testWidgets('defaults to a valid daily cron at 07:00', (tester) async {
    ScheduleSelection? selected;
    await tester.pumpWidget(
      _wrap(ScheduleTriggerSection(onChanged: (value) => selected = value)),
    );
    await tester.pump(); // flush the post-frame default emit

    expect(selected?.cron, '0 7 * * *');
    expect(selected?.isValid, isTrue);
  });

  testWidgets('weekdays mode emits Mon-Fri cron', (tester) async {
    ScheduleSelection? selected;
    await tester.pumpWidget(
      _wrap(ScheduleTriggerSection(onChanged: (value) => selected = value)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('schedule-mode-weekdays')));
    await tester.pump();

    expect(selected?.cron, '0 7 * * 1-5');
    expect(selected?.isValid, isTrue);
  });

  testWidgets('hourly mode emits minute-of-every-hour cron', (tester) async {
    ScheduleSelection? selected;
    await tester.pumpWidget(
      _wrap(ScheduleTriggerSection(onChanged: (value) => selected = value)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('schedule-mode-hourly')));
    await tester.pump();

    expect(selected?.cron, '0 * * * *');
    expect(selected?.isValid, isTrue);
  });

  testWidgets('weekly mode emits chosen day-of-week cron', (tester) async {
    ScheduleSelection? selected;
    await tester.pumpWidget(
      _wrap(ScheduleTriggerSection(onChanged: (value) => selected = value)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('schedule-mode-weekly')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('schedule-weekday-3'))); // Wed
    await tester.pump();

    expect(selected?.cron, '0 7 * * 3');
    expect(selected?.isValid, isTrue);
  });

  testWidgets('custom mode validates a five-field cron', (tester) async {
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
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('schedule-mode-custom')));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('raw-cron-field')), 'bad cron');
    await tester.pump();
    expect(selected?.isValid, isFalse);
    expect(validationMessage, 'Enter a valid five-field cron expression');

    await tester.enterText(
      find.byKey(const Key('raw-cron-field')),
      '0 7 * * 1-5',
    );
    await tester.pump();
    expect(selected?.cron, '0 7 * * 1-5');
    expect(selected?.isValid, isTrue);
    expect(validationMessage, isNull);
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
