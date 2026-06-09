import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/data/storage/secure_token_storage.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';

void main() {
  test(
    'reads and writes refresh token fields and tolerates old sessions',
    () async {
      final previousPlatform = FlutterSecureStoragePlatform.instance;
      addTearDown(() {
        FlutterSecureStoragePlatform.instance = previousPlatform;
      });

      final data = <String, String>{};
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
        data,
      );
      final storage = SecureTokenStorage(storage: const FlutterSecureStorage());

      await storage.saveSession(
        AuthSession(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          username: 'parent',
          userId: 'parent-1',
          displayName: 'Demo Parent',
          role: 'parent',
          homeId: 'home-1',
          mustChangePassword: true,
          expiresAt: DateTime.utc(2026, 5, 16, 12),
          refreshExpiresAt: DateTime.utc(2027, 5, 16, 12),
        ),
      );

      final stored = jsonDecode(data['auth_session']!) as Map<String, Object?>;
      expect(stored['refreshToken'], 'refresh-1');
      expect(stored['refreshExpiresAt'], '2027-05-16T12:00:00.000Z');

      final session = await storage.readSession();
      expect(session?.accessToken, 'access-1');
      expect(session?.refreshToken, 'refresh-1');
      expect(session?.refreshExpiresAt, DateTime.utc(2027, 5, 16, 12));

      data['auth_session'] = jsonEncode(<String, Object?>{
        'accessToken': 'legacy-access',
        'username': 'legacy-parent',
        'expiresAt': '2026-05-16T12:00:00.000Z',
      });

      final legacy = await storage.readSession();
      expect(legacy?.accessToken, 'legacy-access');
      expect(legacy?.refreshToken, isNull);
      expect(legacy?.refreshExpiresAt, isNull);
    },
  );
}
