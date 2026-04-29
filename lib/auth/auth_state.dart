import 'package:flutter/foundation.dart';
import '../core/api_service.dart';
import '../core/auth_storage.dart';
import 'roles.dart';

@immutable
class AuthSession {
  const AuthSession({
    required this.email,
    required this.role,
    required this.displayName,
  });

  final String email;
  final UserRole role;
  final String displayName;
}

class AuthState extends ChangeNotifier {
  AuthSession? _session;

  AuthSession? get session => _session;
  bool get isLoggedIn => _session != null;

  Future<void> updateDisplayName(String displayName) async {
    final current = _session;
    if (current == null) return;
    _session = AuthSession(
      email: current.email,
      role: current.role,
      displayName: displayName,
    );
    await AuthStorage.updateDisplayName(displayName);
    notifyListeners();
  }

  Future<bool> loginWithCredentials({
    required String email,
    required String password,
  }) async {
    try {
      final result = await ApiService.login(
        email: email,
        password: password,
      );

      if (result['success'] == true) {
        final userData = result['data'] as Map<String, dynamic>;
        _session = AuthSession(
          email: userData['email'],
          role: UserRoleLabel.fromString(userData['role'] as String? ?? ''),
          displayName: userData['displayName'],
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Login error in AuthState: $e');
      return false;
    }
  }

  void logout() {
    _session = null;
    AuthStorage.clear();
    notifyListeners();
  }
}
