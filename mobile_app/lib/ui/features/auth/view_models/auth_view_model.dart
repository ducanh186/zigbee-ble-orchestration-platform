import 'package:flutter/foundation.dart';

import '../../../../data/services/api_client.dart';
import '../../../../domain/models/auth_session.dart';
import '../../../../domain/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required AuthRepository repository})
    : _repository = repository;

  final AuthRepository _repository;

  AuthSession? _session;
  bool _isLoading = false;
  String? _errorMessage;

  AuthSession? get session => _session;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _session != null;
  String? get errorMessage => _errorMessage;

  Future<void> login({
    required String username,
    required String password,
  }) async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _repository.login(
        username: username,
        password: password,
      );
    } catch (error) {
      _session = null;
      _errorMessage = friendlyErrorMessage(error, context: 'Dang nhap that bai');
    } finally {
      _isLoading = false;
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
      _errorMessage = null;
      notifyListeners();
    }
  }
}
