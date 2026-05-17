import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/data/repositories/mock_automation_repository.dart';
import 'package:zigbee_smart_building/data/repositories/mock_device_repository.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/repositories/auth_repository.dart';
import 'package:zigbee_smart_building/main.dart';
import 'package:zigbee_smart_building/ui/features/auth/view_models/auth_view_model.dart';
import 'package:zigbee_smart_building/ui/features/auth/views/login_view.dart';
import 'package:zigbee_smart_building/ui/features/shell/views/smart_building_shell.dart';

/// Fake repository that NEVER returns a valid session. The bypass test
/// must succeed despite the user being unauthenticated.
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
    'hideLogin=true skips LoginView and renders SmartBuildingShell directly even when AuthViewModel is unauthenticated',
    (tester) async {
      final unauthVm = AuthViewModel(
        repository: _NeverAuthenticatedRepository(),
      );

      await tester.pumpWidget(
        ZigbeeSmartBuildingApp(
          repository: MockDeviceRepository(),
          automationRepository: MockAutomationRepository(),
          apiBaseUrl: 'mock',
          useMockApi: true,
          authViewModelOverride: unauthVm,
          hideLogin: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(unauthVm.isAuthenticated, isFalse,
          reason: 'precondition: view model must be unauthenticated');
      expect(find.byType(LoginView), findsNothing,
          reason: 'hideLogin=true must skip LoginView');
      expect(find.byType(SmartBuildingShell), findsOneWidget,
          reason: 'hideLogin=true must boot directly into the shell');
    },
  );

  testWidgets(
    'hideLogin=false (default) still gates LoginView when AuthViewModel is unauthenticated',
    (tester) async {
      final unauthVm = AuthViewModel(
        repository: _NeverAuthenticatedRepository(),
      );

      await tester.pumpWidget(
        ZigbeeSmartBuildingApp(
          repository: MockDeviceRepository(),
          automationRepository: MockAutomationRepository(),
          apiBaseUrl: 'mock',
          useMockApi: true,
          authViewModelOverride: unauthVm,
          // hideLogin omitted -> default false
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget,
          reason: 'default behavior preserved: login screen still shown');
      expect(find.byType(SmartBuildingShell), findsNothing);
    },
  );
}
