import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/domain/models/light_scene.dart';
import 'package:zigbee_smart_building/domain/models/device_power.dart';
import 'package:zigbee_smart_building/domain/models/smart_device.dart';
import 'package:zigbee_smart_building/domain/repositories/scene_repository.dart';
import 'package:zigbee_smart_building/l10n/app_localizations.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/features/automation/widgets/scene_target_section.dart';

void main() {
  testWidgets('direct light remains selectable when scenes are unavailable', (
    tester,
  ) async {
    ScheduleTargetSelection? selected;
    await tester.pumpWidget(
      _wrap(
        SceneTargetSection(
          lights: [_light()],
          scenes: const [],
          availability: SceneAvailability.unavailable,
          onChanged: (value) => selected = value,
        ),
      ),
    );

    expect(find.text('Direct light'), findsOneWidget);
    expect(find.text('No scenes available'), findsOneWidget);
    await tester.tap(find.text('Lab Light'));
    await tester.pump();

    expect(selected, isA<DirectLightTarget>());
    expect((selected! as DirectLightTarget).deviceId, 'light-1');
  });

  testWidgets('scene selection emits scene target', (tester) async {
    ScheduleTargetSelection? selected;
    await tester.pumpWidget(
      _wrap(
        SceneTargetSection(
          lights: [_light()],
          scenes: const [
            LightScene(
              groupId: 'group-lab',
              sceneId: 'scene-all-on',
              label: 'Lab all on',
              deviceIds: ['light-1'],
            ),
          ],
          availability: SceneAvailability.available,
          onChanged: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.text('Scene'));
    await tester.pump();
    await tester.tap(find.text('Lab all on'));
    await tester.pump();

    expect(selected, isA<SceneTarget>());
    expect((selected! as SceneTarget).sceneId, 'scene-all-on');
  });
}

SmartDevice _light() {
  return const SmartDevice(
    id: 'light-1',
    deviceType: 'light',
    name: 'Lab Light',
    eui64: '00124b0000000001',
    roomId: 'lab',
    isOnline: true,
    power: DevicePower.off,
  );
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
