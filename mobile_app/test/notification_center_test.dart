import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:zigbee_smart_building/data/models/device_state_api_model.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';
import 'package:zigbee_smart_building/domain/models/command_result.dart';
import 'package:zigbee_smart_building/domain/models/device_power.dart';
import 'package:zigbee_smart_building/domain/models/event_log.dart';
import 'package:zigbee_smart_building/domain/models/smart_device.dart';
import 'package:zigbee_smart_building/domain/repositories/device_repository.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/core/widgets/status_badge.dart';
import 'package:zigbee_smart_building/ui/features/devices/view_models/device_dashboard_view_model.dart';
import 'package:zigbee_smart_building/ui/features/logs/views/logs_view.dart';
import 'package:zigbee_smart_building/ui/features/logs/widgets/notification_event_tile.dart';

/// Fake repository that returns whatever events the test wires in. The other
/// methods aren't exercised by the notification-center widget tests but are
/// implemented because [DeviceRepository] is abstract.
class _FakeDeviceRepository implements DeviceRepository {
  _FakeDeviceRepository({List<EventLog> events = const []}) : _events = events;

  final List<EventLog> _events;

  @override
  Future<CloudStatus> fetchCloudStatus() async => const CloudStatus.mock();

  @override
  Future<List<SmartDevice>> fetchDevices() async => const [];

  @override
  Future<List<EventLog>> fetchEvents({String? deviceId}) async => _events;

  @override
  Future<CommandResult> sendLightPowerCommand({
    required String deviceId,
    required DevicePower target,
  }) async => throw UnimplementedError();

  @override
  Future<CommandResult> fetchCommand(String commandId) async =>
      throw UnimplementedError();

  @override
  Future<List<DeviceStateApiModel>> refreshDeviceStates(
    List<String> deviceIds,
  ) async => const [];
}

Future<DeviceDashboardViewModel> _pumpLogs(
  WidgetTester tester,
  List<EventLog> events,
) async {
  final repository = _FakeDeviceRepository(events: events);
  final viewModel = DeviceDashboardViewModel(
    repository: repository,
    pollInterval: null,
  );
  await viewModel.load();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme(AppThemeMode.light),
      home: ChangeNotifierProvider<DeviceDashboardViewModel>.value(
        value: viewModel,
        child: const Scaffold(body: LogsView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return viewModel;
}

void main() {
  group('Notification center', () {
    testWidgets(
      'renders motion / automation success / automation failed tiles with category badges',
      (tester) async {
        final events = [
          const EventLog(
            id: '1',
            deviceId: 'pir-01',
            eventType: 'occupancy_changed',
            message: 'occupancy=occupied',
            occurredAt: '07:00 05/17/2026',
            source: 'gateway',
          ),
          const EventLog(
            id: '2',
            deviceId: 'light-01',
            eventType: 'automation.executed',
            message: 'Rule "Motion lights" executed',
            occurredAt: '07:05 05/17/2026',
            source: 'gateway',
            commandId: 'cmd-1',
          ),
          const EventLog(
            id: '3',
            deviceId: 'light-02',
            eventType: 'automation.failed',
            message: 'Rule "Motion lights" failed: timeout',
            occurredAt: '07:10 05/17/2026',
            source: 'gateway',
          ),
        ];

        await _pumpLogs(tester, events);

        final tiles = tester.widgetList<NotificationEventTile>(
          find.byType(NotificationEventTile),
        );
        expect(tiles, hasLength(3));

        // The view always sorts newest-first by [occurredAt], so the order is
        // 07:10 (failed) > 07:05 (success) > 07:00 (motion).
        final categories = tiles.map((tile) => tile.event.category).toList();
        expect(categories, [
          EventCategory.automationFailed,
          EventCategory.automationExecuted,
          EventCategory.motion,
        ]);

        // Each tile renders a StatusBadge with the matching tone.
        final tones = tester
            .widgetList<StatusBadge>(find.byType(StatusBadge))
            .map((badge) => badge.tone)
            .toList();
        expect(tones, [BadgeTone.error, BadgeTone.success, BadgeTone.primary]);

        // Visible badge labels are deterministic and human-readable.
        expect(find.text('Motion'), findsOneWidget);
        expect(find.text('Automation'), findsOneWidget);
        expect(find.text('Failed'), findsOneWidget);
      },
    );

    testWidgets('newest-first ordering survives an out-of-order event list', (
      tester,
    ) async {
      final events = [
        // Intentionally inserted middle-first then oldest then newest.
        const EventLog(
          id: 'b',
          eventType: 'occupancy_changed',
          message: 'middle',
          occurredAt: '08:00 05/17/2026',
        ),
        const EventLog(
          id: 'a',
          eventType: 'occupancy_changed',
          message: 'oldest',
          occurredAt: '07:00 05/17/2026',
        ),
        const EventLog(
          id: 'c',
          eventType: 'occupancy_changed',
          message: 'newest',
          occurredAt: '09:00 05/17/2026',
        ),
      ];

      await _pumpLogs(tester, events);

      final tiles = tester.widgetList<NotificationEventTile>(
        find.byType(NotificationEventTile),
      );
      final ids = tiles.map((tile) => tile.event.id).toList();
      expect(ids, ['c', 'b', 'a']);
    });

    testWidgets(
      'unknown event types render with a neutral badge rather than crashing',
      (tester) async {
        final events = [
          const EventLog(
            id: 'u',
            deviceId: 'gw-1',
            eventType: 'something_unmapped',
            message: 'who knows',
            occurredAt: '07:00 05/17/2026',
          ),
        ];

        await _pumpLogs(tester, events);

        final tile = tester.widget<NotificationEventTile>(
          find.byType(NotificationEventTile),
        );
        expect(tile.event.category, EventCategory.other);

        final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
        expect(badge.tone, BadgeTone.neutral);
        expect(badge.label, 'Event');
      },
    );
  });
}
