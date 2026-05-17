import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:zigbee_smart_building/app_runtime_config.dart';
import 'package:zigbee_smart_building/domain/models/ota_campaign.dart';
import 'package:zigbee_smart_building/domain/repositories/ota_repository.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/core/widgets/status_badge.dart';
import 'package:zigbee_smart_building/ui/features/settings/view_models/ota_progress_view_model.dart';
import 'package:zigbee_smart_building/ui/features/settings/views/settings_view.dart';

/// Fake repository returning hardcoded campaigns. Used to drive the
/// progress widget through each [OtaProgressState].
class _FakeOtaRepository implements OtaRepository {
  _FakeOtaRepository(this._campaigns);

  final List<OtaCampaign> _campaigns;

  @override
  Future<List<OtaCampaign>> listCampaigns() async => _campaigns;
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required List<OtaCampaign> campaigns,
}) async {
  final viewModel = OtaProgressViewModel(
    repository: _FakeOtaRepository(campaigns),
  );
  await viewModel.load();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme(AppThemeMode.light),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          Provider(
            create: (_) =>
                AppRuntimeConfig(apiBaseUrl: 'mock', useMockApi: true),
          ),
          ChangeNotifierProvider<OtaProgressViewModel>.value(value: viewModel),
        ],
        child: Scaffold(body: SettingsView(onOpenLight: (_) {})),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Scroll the OTA section into view; the settings list is long enough on
  // the default test surface that "Cap nhat firmware" is off-screen until
  // we drag past the workspace cards.
  await tester.dragUntilVisible(
    find.text('CAP NHAT FIRMWARE'),
    find.byType(CustomScrollView).last,
    const Offset(0, -100),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('OTA progress screen', () {
    testWidgets(
      'renders queued / running / succeeded / failed badges with the correct tone',
      (tester) async {
        const campaigns = [
          OtaCampaign(
            id: 'ota-queued',
            firmwareVersion: '3',
            deviceIds: ['light-01'],
            state: OtaProgressState.queued,
          ),
          OtaCampaign(
            id: 'ota-running',
            firmwareVersion: '3',
            deviceIds: ['light-02', 'light-03'],
            state: OtaProgressState.running,
            progress: 0.42,
          ),
          OtaCampaign(
            id: 'ota-succeeded',
            firmwareVersion: '2',
            deviceIds: ['light-04'],
            state: OtaProgressState.succeeded,
            progress: 1.0,
          ),
          OtaCampaign(
            id: 'ota-failed',
            firmwareVersion: '5',
            deviceIds: ['light-05'],
            state: OtaProgressState.failed,
            errorMessage: 'checksum mismatch',
          ),
        ];

        await _pumpSettings(tester, campaigns: campaigns);

        // Section title is the Vietnamese (ASCII) "Cap nhat firmware",
        // uppercased by SectionTitle.
        expect(find.text('CAP NHAT FIRMWARE'), findsOneWidget);

        // Each campaign id is rendered.
        expect(find.text('ota-queued'), findsOneWidget);
        expect(find.text('ota-running'), findsOneWidget);
        expect(find.text('ota-succeeded'), findsOneWidget);
        expect(find.text('ota-failed'), findsOneWidget);

        // Badge labels match the four states.
        expect(find.text('Queued'), findsOneWidget);
        expect(find.text('Running'), findsOneWidget);
        expect(find.text('Succeeded'), findsOneWidget);
        expect(find.text('Failed'), findsOneWidget);

        // Each campaign row produces one StatusBadge with the documented tone.
        final badges = tester
            .widgetList<StatusBadge>(find.byType(StatusBadge))
            .where(
              (badge) => const {
                'Queued',
                'Running',
                'Succeeded',
                'Failed',
              }.contains(badge.label),
            )
            .toList();
        expect(badges, hasLength(4));
        final tonesByLabel = {
          for (final badge in badges) badge.label: badge.tone,
        };
        expect(tonesByLabel['Queued'], BadgeTone.neutral);
        expect(tonesByLabel['Running'], BadgeTone.primary);
        expect(tonesByLabel['Succeeded'], BadgeTone.success);
        expect(tonesByLabel['Failed'], BadgeTone.error);
      },
    );

    testWidgets('running row exposes the rolled-up progress percentage', (
      tester,
    ) async {
      const campaigns = [
        OtaCampaign(
          id: 'ota-running',
          firmwareVersion: '3',
          deviceIds: ['light-02', 'light-03'],
          state: OtaProgressState.running,
          progress: 0.42,
        ),
      ];

      await _pumpSettings(tester, campaigns: campaigns);

      // Subtitle joins firmware version, device count, and progress %.
      expect(find.textContaining('42%'), findsOneWidget);
      expect(find.textContaining('Firmware v3'), findsOneWidget);
      expect(find.textContaining('2 devices'), findsOneWidget);
    });

    testWidgets('failed row surfaces the error message from the cloud', (
      tester,
    ) async {
      const campaigns = [
        OtaCampaign(
          id: 'ota-failed',
          firmwareVersion: '5',
          deviceIds: ['light-05'],
          state: OtaProgressState.failed,
          errorMessage: 'checksum mismatch',
        ),
      ];

      await _pumpSettings(tester, campaigns: campaigns);

      expect(find.textContaining('checksum mismatch'), findsOneWidget);
    });

    testWidgets('queued row does not advertise a progress percentage', (
      tester,
    ) async {
      const campaigns = [
        OtaCampaign(
          id: 'ota-queued',
          firmwareVersion: '3',
          deviceIds: ['light-01'],
          state: OtaProgressState.queued,
        ),
      ];

      await _pumpSettings(tester, campaigns: campaigns);

      // No % glyph appears in any visible Text inside the row when the
      // campaign is still queued (progress is null).
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets(
      'settings view hides the OTA section entirely when no view model is provided',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.theme(AppThemeMode.light),
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => ThemeController()),
                Provider(
                  create: (_) =>
                      AppRuntimeConfig(apiBaseUrl: 'mock', useMockApi: true),
                ),
              ],
              child: Scaffold(body: SettingsView(onOpenLight: (_) {})),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Without a provider, the OTA section short-circuits to nothing
        // and the "Cap nhat firmware" title never enters the tree.
        expect(find.text('CAP NHAT FIRMWARE'), findsNothing);
      },
    );
  });
}
