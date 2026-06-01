import 'package:flutter/foundation.dart';

import '../../../../data/services/api_client.dart';
import '../../../../domain/models/auth_session.dart';
import '../../../../domain/repositories/auth_repository.dart';

enum AuthStatus {
  unauthenticated,
  checking,
  authenticating,
  authenticated,
  refreshing,
  error,
}

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required AuthRepository repository})
    : _repository = repository;

  final AuthRepository _repository;

  AuthSession? _session;
  AuthStatus _status = AuthStatus.unauthenticated;
  String? _errorMessage;

  AuthSession? get session => _session;
  AuthStatus get status => _status;
  bool get isLoading =>
      _status == AuthStatus.checking ||
      _status == AuthStatus.authenticating ||
      _status == AuthStatus.refreshing;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _session != null;
  String? get errorMessage => _errorMessage;

  Future<void> bootstrap() async {
    if (isLoading) {
      return;
    }

    _status = AuthStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _repository.restoreSession();
      _status = _session == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
    } catch (error) {
      _session = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    if (isLoading) {
      return;
    }

    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _repository.login(
        username: username,
        password: password,
      );
      _status = AuthStatus.authenticated;
    } catch (error) {
      _session = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Dang nhap that bai',
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // Swallow logout errors so the local session is always cleared.
    } finally {
      _session = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
    }
  }
}
