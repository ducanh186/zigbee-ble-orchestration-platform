import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zigbee_smart_building/domain/models/provisioning_session.dart';
import 'package:zigbee_smart_building/domain/repositories/provisioning_repository.dart';
import 'package:zigbee_smart_building/l10n/app_localizations.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/features/provisioning/views/provisioning_view.dart';

void main() {
  const validQrJson =
      '{"version":1,"eui64":"A8D417FEFF570B00","device_type":"light","model":"EFR32MG12_LIGHT_KIT"}';

  testWidgets(
    'renders wizard shell with start disabled until device payload exists',
    (tester) async {
      await tester.pumpWidget(_wrap(const ProvisioningView()));

      expect(find.text('Gateway ID'), findsNothing);
      expect(find.text('Room ID'), findsOneWidget);
      expect(find.text('Device identity required'), findsOneWidget);

      await _scrollUntilVisible(
        tester,
        find.byKey(const Key('provisioning-start-button')),
      );
      final startButton = tester.widget<FilledButton>(
        find.byKey(const Key('provisioning-start-button')),
      );
      expect(startButton.onPressed, isNull);
    },
  );

  testWidgets('manual QR JSON populates identity and enables start', (
    tester,
  ) async {
    final repository = _FakeProvisioningRepository();

    await tester.pumpWidget(
      _wrap(
        const ProvisioningView(pollInterval: Duration.zero),
        repository: repository,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('provisioning-manual-qr-field')),
      validQrJson,
    );
    await tester.tap(find.byKey(const Key('provisioning-apply-manual-button')));
    await tester.pumpAndSettle();

    await _scrollUntilVisible(tester, find.text('A8D417FEFF570B00'));
    expect(find.text('A8D417FEFF570B00'), findsOneWidget);
    expect(find.text('EFR32MG12_LIGHT_KIT'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.byKey(const Key('provisioning-room-field')),
      delta: -240,
    );
    await tester.enterText(
      find.byKey(const Key('provisioning-room-field')),
      'lab',
    );
    await tester.pump();
    await _scrollUntilVisible(
      tester,
      find.byKey(const Key('provisioning-start-button')),
    );
    await tester.tap(find.byKey(const Key('provisioning-start-button')));
    await tester.pumpAndSettle();

    expect(repository.createCount, 1);
    expect(repository.createdPayload?.eui64, 'A8D417FEFF570B00');
    await _scrollUntilVisible(tester, find.text('JOINED'), delta: -240);
    expect(find.text('JOINED'), findsOneWidget);
  });

  testWidgets(
    'invalid manual QR JSON keeps start disabled and does not call Cloud',
    (tester) async {
      final repository = _FakeProvisioningRepository();

      await tester.pumpWidget(
        _wrap(
          const ProvisioningView(pollInterval: Duration.zero),
          repository: repository,
        ),
      );

      await tester.enterText(
        find.byKey(const Key('provisioning-manual-qr-field')),
        '{"version":1,"eui64":"bad"}',
      );
      await tester.tap(
        find.byKey(const Key('provisioning-apply-manual-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('The data is invalid. Check the input fields.'),
        findsOneWidget,
      );
      await _scrollUntilVisible(
        tester,
        find.byKey(const Key('provisioning-start-button')),
      );
      final startButton = tester.widget<FilledButton>(
        find.byKey(const Key('provisioning-start-button')),
      );
      expect(startButton.onPressed, isNull);
      expect(repository.createCount, 0);
    },
  );

  testWidgets('empty manual QR does not show JSON parser error', (
    tester,
  ) async {
    final repository = _FakeProvisioningRepository();

    await tester.pumpWidget(
      _wrap(
        const ProvisioningView(pollInterval: Duration.zero),
        repository: repository,
      ),
    );

    await tester.tap(find.byKey(const Key('provisioning-apply-manual-button')));
    await tester.pumpAndSettle();

    expect(find.text('Unexpected end of input'), findsNothing);
    expect(find.text('Device identity required'), findsOneWidget);
    await _scrollUntilVisible(
      tester,
      find.byKey(const Key('provisioning-start-button')),
    );
    final startButton = tester.widget<FilledButton>(
      find.byKey(const Key('provisioning-start-button')),
    );
    expect(startButton.onPressed, isNull);
    expect(repository.createCount, 0);
  });

  testWidgets('scan QR populates identity and clear removes it before start', (
    tester,
  ) async {
    final repository = _FakeProvisioningRepository();

    await tester.pumpWidget(
      _wrap(
        ProvisioningView(
          pollInterval: Duration.zero,
          qrScanLauncher: (_) async => validQrJson,
        ),
        repository: repository,
      ),
    );

    await tester.tap(find.byKey(const Key('provisioning-scan-button')));
    await tester.pumpAndSettle();

    await _scrollUntilVisible(tester, find.text('A8D417FEFF570B00'));
    expect(find.text('A8D417FEFF570B00'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.byKey(const Key('provisioning-clear-payload-button')),
      delta: -240,
    );
    await tester.tap(
      find.byKey(const Key('provisioning-clear-payload-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Device identity required'), findsOneWidget);
    await _scrollUntilVisible(
      tester,
      find.byKey(const Key('provisioning-start-button')),
    );
    final startButton = tester.widget<FilledButton>(
      find.byKey(const Key('provisioning-start-button')),
    );
    expect(startButton.onPressed, isNull);
    expect(repository.createCount, 0);
  });

  testWidgets('starts provisioning and displays polled terminal status', (
    tester,
  ) async {
    final repository = _FakeProvisioningRepository();
    final payload = ProvisioningQrPayload.parseJson(
      jsonEncode({
        'version': 1,
        'eui64': 'A8D417FEFF570B00',
        'device_type': 'light',
        'model': 'EFR32MG12_LIGHT_KIT',
      }),
    );

    await tester.pumpWidget(
      _wrap(
        ProvisioningView(initialPayload: payload, pollInterval: Duration.zero),
        repository: repository,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('provisioning-room-field')),
      'lab',
    );
    await tester.pump();
    await _scrollUntilVisible(
      tester,
      find.byKey(const Key('provisioning-start-button')),
    );
    await tester.tap(find.byKey(const Key('provisioning-start-button')));
    await tester.pumpAndSettle();

    expect(repository.createdGatewayId, 'gw-ubuntu-01');
    expect(repository.createdRoomId, 'lab');
    expect(repository.createdPayload, payload);
    await _scrollUntilVisible(tester, find.text('JOINED'), delta: -240);
    expect(find.text('JOINED'), findsOneWidget);
    expect(find.text('EFR32MG12_LIGHT_KIT'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final startButton = tester.widget<FilledButton>(
      find.byKey(const Key('provisioning-start-button')),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('cancels an active provisioning session', (tester) async {
    final repository = _FakeProvisioningRepository(
      pollStatuses: [ProvisioningStatus.permitOpen],
    );
    final payload = ProvisioningQrPayload.parseJson(
      jsonEncode({
        'version': 1,
        'eui64': 'A8D417FEFF570B00',
        'device_type': 'switch',
      }),
    );

    await tester.pumpWidget(
      _wrap(
        ProvisioningView(initialPayload: payload, pollInterval: Duration.zero),
        repository: repository,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('provisioning-room-field')),
      'lab',
    );
    await tester.pump();
    await _scrollUntilVisible(
      tester,
      find.byKey(const Key('provisioning-start-button')),
    );
    await tester.tap(find.byKey(const Key('provisioning-start-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('provisioning-cancel-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('provisioning-cancel-button')));
    await tester.pumpAndSettle();

    expect(repository.cancelledSessionId, 'session-01');
    await _scrollUntilVisible(tester, find.text('CANCELLED'), delta: -240);
    expect(find.text('CANCELLED'), findsOneWidget);
  });
}

Widget _wrap(Widget child, {ProvisioningRepository? repository}) {
  return Provider<ProvisioningRepository>.value(
    value: repository ?? _FakeProvisioningRepository(),
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.theme(AppThemeMode.light),
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _scrollUntilVisible(
  WidgetTester tester,
  Finder finder, {
  double delta = 240,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

class _FakeProvisioningRepository implements ProvisioningRepository {
  _FakeProvisioningRepository({
    this.pollStatuses = const [
      ProvisioningStatus.pending,
      ProvisioningStatus.permitOpen,
      ProvisioningStatus.joined,
    ],
  });

  final List<ProvisioningStatus> pollStatuses;
  String? createdGatewayId;
  String? createdRoomId;
  ProvisioningQrPayload? createdPayload;
  String? cancelledSessionId;
  int createCount = 0;

  @override
  Future<ProvisioningSession> createSession({
    required String gatewayId,
    required String roomId,
    required ProvisioningQrPayload payload,
  }) async {
    createCount += 1;
    createdGatewayId = gatewayId;
    createdRoomId = roomId;
    createdPayload = payload;
    return _session(ProvisioningStatus.pending);
  }

  @override
  Future<ProvisioningSession> fetchSession(String sessionId) async {
    return _session(ProvisioningStatus.permitOpen);
  }

  @override
  Future<ProvisioningSession> cancelSession(String sessionId) async {
    cancelledSessionId = sessionId;
    return _session(ProvisioningStatus.cancelled);
  }

  @override
  Stream<ProvisioningSession> pollSession(
    String sessionId, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 30,
  }) {
    return Stream.fromIterable(pollStatuses.map(_session));
  }

  ProvisioningSession _session(ProvisioningStatus status) {
    return ProvisioningSession(
      sessionId: 'session-01',
      status: status,
      gatewayId: createdGatewayId ?? 'gw-ubuntu-01',
      roomId: createdRoomId ?? 'lab',
      eui64: 'A8D417FEFF570B00',
      deviceType: createdPayload?.deviceType ?? ProvisioningDeviceType.light,
      model: createdPayload?.model,
    );
  }
}
