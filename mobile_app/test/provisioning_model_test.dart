import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/data/models/provisioning_api_model.dart';
import 'package:zigbee_smart_building/domain/models/provisioning_session.dart';

void main() {
  group('ProvisioningQrPayload', () {
    test('parses valid v1 QR JSON without exposing install code', () {
      final payload = ProvisioningQrPayload.parseJson(
        jsonEncode({
          'version': 1,
          'eui64': 'a8d417feff570b00',
          'device_type': 'light',
          'model': 'EFR32MG12_LIGHT_KIT',
        }),
      );

      expect(payload.version, 1);
      expect(payload.eui64, 'A8D417FEFF570B00');
      expect(payload.deviceType, ProvisioningDeviceType.light);
      expect(payload.model, 'EFR32MG12_LIGHT_KIT');
    });

    test('rejects invalid QR JSON before posting to Cloud', () {
      expect(
        () => ProvisioningQrPayload.parseJson('not-json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unsupported QR schema version', () {
      expect(
        () => ProvisioningQrPayload.parseJson(
          jsonEncode({
            'version': 2,
            'eui64': 'A8D417FEFF570B00',
            'device_type': 'light',
          }),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid EUI64 values', () {
      expect(
        () => ProvisioningQrPayload.parseJson(
          jsonEncode({
            'version': 1,
            'eui64': '0xA8D417FEFF570B00',
            'device_type': 'light',
          }),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unsupported provisioning device type', () {
      expect(
        () => ProvisioningQrPayload.parseJson(
          jsonEncode({
            'version': 1,
            'eui64': 'A8D417FEFF570B00',
            'device_type': 'occupancy',
          }),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects QR payloads that contain an install code', () {
      expect(
        () => ProvisioningQrPayload.parseJson(
          jsonEncode({
            'version': 1,
            'eui64': 'A8D417FEFF570B00',
            'device_type': 'light',
            'install_code': '83FED3407A939723A5C639B26916D505C3B5',
          }),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Provisioning API models', () {
    test('serializes create-session request using contract shape', () {
      final request = ProvisioningSessionCreateApiModel(
        gatewayId: 'gw-ubuntu-01',
        roomId: 'lab',
        payload: ProvisioningQrPayload.parseJson(
          jsonEncode({
            'version': 1,
            'eui64': 'A8D417FEFF570B00',
            'device_type': 'switch',
            'model': 'EFR32MG12_SWITCH_KIT',
          }),
        ),
      );

      expect(request.toJson(), {
        'gateway_id': 'gw-ubuntu-01',
        'room_id': 'lab',
        'device': {
          'eui64': 'A8D417FEFF570B00',
          'device_type': 'switch',
          'model': 'EFR32MG12_SWITCH_KIT',
        },
      });
    });

    test('maps session response and never expects install_code from Cloud', () {
      final apiModel = ProvisioningSessionApiModel.fromJson({
        'session_id': 'session-01',
        'status': 'permit_open',
        'gateway_id': 'gw-ubuntu-01',
        'room_id': 'lab',
        'eui64': 'A8D417FEFF570B00',
        'device_type': 'motion',
        'model': 'EFR32MG12_PIR_KIT',
        'reason': null,
        'expires_at': '10:00 05/27/2026',
        'created_at': '09:59 05/27/2026',
        'updated_at': '10:00 05/27/2026',
      });

      final session = apiModel.toDomain();

      expect(session.sessionId, 'session-01');
      expect(session.status, ProvisioningStatus.permitOpen);
      expect(session.gatewayId, 'gw-ubuntu-01');
      expect(session.roomId, 'lab');
      expect(session.eui64, 'A8D417FEFF570B00');
      expect(session.deviceType, ProvisioningDeviceType.motion);
      expect(session.model, 'EFR32MG12_PIR_KIT');
      expect(session.reason, isNull);
      expect(session.isTerminal, isFalse);
    });

    test('maps terminal provisioning statuses', () {
      expect(
        ProvisioningStatus.fromJson('joined'),
        ProvisioningStatus.joined,
      );
      expect(
        ProvisioningStatus.fromJson('failed'),
        ProvisioningStatus.failed,
      );
      expect(
        ProvisioningStatus.fromJson('expired'),
        ProvisioningStatus.expired,
      );
      expect(
        ProvisioningStatus.fromJson('cancelled'),
        ProvisioningStatus.cancelled,
      );
    });
  });
}
