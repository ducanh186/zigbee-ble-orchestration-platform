import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zigbee_smart_building/data/repositories/mock_automation_repository.dart';
import 'package:zigbee_smart_building/data/repositories/mock_device_repository.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/repositories/auth_repository.dart';
import 'package:zigbee_smart_building/main.dart';
import 'package:zigbee_smart_building/ui/features/auth/view_models/auth_view_model.dart';

class FakeAuthRepository implements AuthRepository {
  int loginCalls = 0;
  int logoutCalls = 0;
  bool shouldFail = false;

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    loginCalls++;
    if (shouldFail) {
      throw const ApiException(
        statusCode: 401,
        kind: ApiErrorKind.unauthorized,
        message: 'invalid credentials',
      );
    }
    return AuthSession(
      accessToken: 'test-token',
      userId: username,
      expiresAt: DateTime.utc(2026, 12, 31),
    );
  }

  @override
  Future<AuthSession?> refreshSession({required String refreshToken}) async =>
      null;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required AuthViewModel authViewModel,
}) async {
  await tester.pumpWidget(
    ZigbeeSmartBuildingApp(
      repository: MockDeviceRepository(),
      automationRepository: MockAutomationRepository(),
      apiBaseUrl: 'mock',
      useMockApi: true,
      authViewModelOverride: authViewModel,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows login screen when not authenticated', (tester) async {
    final repo = FakeAuthRepository();
    final viewModel = AuthViewModel(repository: repo);

    await _pumpApp(tester, authViewModel: viewModel);

    expect(find.text('Sign in'), findsWidgets);
    // The shell content should not be visible while unauthenticated.
    expect(find.text('QUICK LIGHTS'), findsNothing);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('successful login transitions to the authenticated shell', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    final viewModel = AuthViewModel(repository: repo);

    await _pumpApp(tester, authViewModel: viewModel);

    await tester.enterText(find.byKey(const Key('login-username')), 'parent');
    await tester.enterText(find.byKey(const Key('login-password')), 'password');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(repo.loginCalls, 1);
    expect(viewModel.isAuthenticated, isTrue);

    // Authenticated shell content is visible.
    expect(find.text('QUICK LIGHTS'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    // Login form is gone.
    expect(find.byKey(const Key('login-submit')), findsNothing);
  });

  testWidgets('failed login shows error and stays on login screen', (
    tester,
  ) async {
    final repo = FakeAuthRepository()..shouldFail = true;
    final viewModel = AuthViewModel(repository: repo);

    await _pumpApp(tester, authViewModel: viewModel);

    await tester.enterText(find.byKey(const Key('login-username')), 'parent');
    await tester.enterText(find.byKey(const Key('login-password')), 'wrong');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(viewModel.isAuthenticated, isFalse);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    // The banner shows the friendly Vietnamese message, not raw HTTP text.
    expect(find.textContaining('Dang nhap that bai'), findsOneWidget);
    expect(find.textContaining('invalid credentials'), findsNothing);
    expect(find.textContaining('API 401'), findsNothing);
  });

  testWidgets('logout from settings returns to the login screen', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    final viewModel = AuthViewModel(repository: repo);

    await _pumpApp(tester, authViewModel: viewModel);

    // Sign in.
    await tester.enterText(find.byKey(const Key('login-username')), 'parent');
    await tester.enterText(find.byKey(const Key('login-password')), 'password');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('QUICK LIGHTS'), findsOneWidget);

    // Open Settings tab.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Scroll to the Logout row at the bottom of Settings.
    await tester.scrollUntilVisible(
      find.text('Logout'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Logout'), findsOneWidget);
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(repo.logoutCalls, 1);
    expect(viewModel.isAuthenticated, isFalse);
    // We are back at the login screen.
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(find.text('QUICK LIGHTS'), findsNothing);
  });
}
