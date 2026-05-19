import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/data/repositories/mock_automation_repository.dart';
import 'package:zigbee_smart_building/data/repositories/mock_device_repository.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/repositories/auth_repository.dart';
import 'package:zigbee_smart_building/main.dart';
import 'package:zigbee_smart_building/ui/features/auth/view_models/auth_view_model.dart';
import 'package:zigbee_smart_building/ui/features/auth/views/login_view.dart';
import 'package:zigbee_smart_building/ui/features/shell/views/smart_building_shell.dart';

class _NeverAuthenticatedRepository implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    throw StateError('login should not be called when hideLogin is true');
  }

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets(
    'hideLogin=true skips LoginView and renders SmartBuildingShell directly',
    (tester) async {
      final unauthenticated = AuthViewModel(
        repository: _NeverAuthenticatedRepository(),
      );

      await tester.pumpWidget(
        ZigbeeSmartBuildingApp(
          repository: MockDeviceRepository(),
          automationRepository: MockAutomationRepository(),
          apiBaseUrl: 'mock',
          useMockApi: true,
          authViewModelOverride: unauthenticated,
          hideLogin: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(unauthenticated.isAuthenticated, isFalse);
      expect(find.byType(LoginView), findsNothing);
      expect(find.byType(SmartBuildingShell), findsOneWidget);
    },
  );

  testWidgets('hideLogin=false still shows LoginView when unauthenticated', (
    tester,
  ) async {
    final unauthenticated = AuthViewModel(
      repository: _NeverAuthenticatedRepository(),
    );

    await tester.pumpWidget(
      ZigbeeSmartBuildingApp(
        repository: MockDeviceRepository(),
        automationRepository: MockAutomationRepository(),
        apiBaseUrl: 'mock',
        useMockApi: true,
        authViewModelOverride: unauthenticated,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginView), findsOneWidget);
    expect(find.byType(SmartBuildingShell), findsNothing);
  });
}
