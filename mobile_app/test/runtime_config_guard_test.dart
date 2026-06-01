import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/security/runtime_config_guard.dart';

void main() {
  test('release config accepts HTTPS with login enabled', () {
    expect(
      () => validateRuntimeSecurityConfig(
        apiBaseUrl: 'https://cloud.example.test',
        hideLogin: false,
        isReleaseMode: true,
      ),
      returnsNormally,
    );
  });

  test('release config rejects HTTP API base URL', () {
    expect(
      () => validateRuntimeSecurityConfig(
        apiBaseUrl: 'http://98.83.4.87:8000',
        hideLogin: false,
        isReleaseMode: true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('release config rejects hidden login bypass', () {
    expect(
      () => validateRuntimeSecurityConfig(
        apiBaseUrl: 'https://cloud.example.test',
        hideLogin: true,
        isReleaseMode: true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('debug config allows HTTP demo endpoint', () {
    expect(
      () => validateRuntimeSecurityConfig(
        apiBaseUrl: 'http://98.83.4.87:8000',
        hideLogin: true,
        isReleaseMode: false,
      ),
      returnsNormally,
    );
  });
}
