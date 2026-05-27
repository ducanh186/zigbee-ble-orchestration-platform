import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zigbee_smart_building/domain/models/provisioning_session.dart';
import 'package:zigbee_smart_building/domain/repositories/provisioning_repository.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/features/provisioning/views/provisioning_view.dart';

void main() {
  testWidgets('renders wizard shell with start disabled until device payload exists', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProvisioningView()));

    expect(find.text('Gateway ID'), findsOneWidget);
    expect(find.text('Room ID'), findsOneWidget);
    expect(find.text('Device identity required'), findsOneWidget);

    final startButton = tester.widget<FilledButton>(
      find.byKey(const Key('provisioning-start-button')),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('starts provisioning and displays polled terminal status', (
    tester,
  ) async {
    final repository = _FakeProvisioningRepository();
    final payload = ProvisioningQrPayload.parseJson(
      jsonEncode({
        'version': 1,
        'eui64': 'A8D417FEFF570B00',
        'install_code': '83FED3407A939723A5C639B26916D505C3B5',
        'device_type': 'light',
        'model': 'EFR32MG12_LIGHT_KIT',
      }),
    );

    await tester.pumpWidget(
      _wrap(
        ProvisioningView(
          initialPayload: payload,
          pollInterval: Duration.zero,
        ),
        repository: repository,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('provisioning-room-field')),
      'lab',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('provisioning-start-button')));
    await tester.pumpAndSettle();

    expect(repository.createdGatewayId, 'gw-ubuntu-01');
    expect(repository.createdRoomId, 'lab');
    expect(repository.createdPayload, payload);
    expect(find.text('JOINED'), findsOneWidget);
    expect(find.text('EFR32MG12_LIGHT_KIT'), findsOneWidget);
  });

  testWidgets('cancels an active provisioning session', (tester) async {
    final repository = _FakeProvisioningRepository(
      pollStatuses: [ProvisioningStatus.permitOpen],
    );
    final payload = ProvisioningQrPayload.parseJson(
      jsonEncode({
        'version': 1,
        'eui64': 'A8D417FEFF570B00',
        'install_code': '83FED3407A939723A5C639B26916D505C3B5',
        'device_type': 'switch',
      }),
    );

    await tester.pumpWidget(
      _wrap(
        ProvisioningView(
          initialPayload: payload,
          pollInterval: Duration.zero,
        ),
        repository: repository,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('provisioning-room-field')),
      'lab',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('provisioning-start-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('provisioning-cancel-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('provisioning-cancel-button')));
    await tester.pumpAndSettle();

    expect(repository.cancelledSessionId, 'session-01');
    expect(find.text('CANCELLED'), findsOneWidget);
  });
}

Widget _wrap(
  Widget child, {
  ProvisioningRepository? repository,
}) {
  return Provider<ProvisioningRepository>.value(
    value: repository ?? _FakeProvisioningRepository(),
    child: MaterialApp(
      theme: AppTheme.theme(AppThemeMode.light),
      home: Scaffold(body: child),
    ),
  );
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

  @override
  Future<ProvisioningSession> createSession({
    required String gatewayId,
    required String roomId,
    required ProvisioningQrPayload payload,
  }) async {
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
