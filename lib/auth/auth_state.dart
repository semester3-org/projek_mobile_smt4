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
    this.merchantType,
  });

  final String email;
  final UserRole role;
  final String displayName;
  final MerchantType? merchantType;
}

class AuthState extends ChangeNotifier {
  AuthSession? _session;
  bool _isRestoring = false;

  AuthSession? get session => _session;
  bool get isLoggedIn => _session != null;
  bool get isRestoring => _isRestoring;

  Future<void> restoreSession() async {
    _isRestoring = true;
    notifyListeners();

    try {
      final result = await ApiService.restoreSession();

      if (result['success'] == true && result['data'] != null) {
        final userData = result['data'] as Map<String, dynamic>;
        final merchantTypeStr = userData['merchantType'] as String?;
        _session = AuthSession(
          email: userData['email'] as String? ?? '',
          role: UserRoleLabel.fromString(userData['role'] as String? ?? ''),
          displayName: userData['displayName'] as String? ?? 'User',
          merchantType: MerchantTypeLabel.fromString(merchantTypeStr),
        );
      } else {
        await AuthStorage.clear();
      }
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final current = _session;
    if (current == null) return;
    _session = AuthSession(
      email: current.email,
      role: current.role,
      displayName: displayName,
      merchantType: current.merchantType,
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
        final merchantTypeStr = userData['merchantType'] as String?;
        _session = AuthSession(
          email: userData['email'],
          role: UserRoleLabel.fromString(userData['role'] as String? ?? ''),
          displayName: userData['displayName'],
          merchantType: MerchantTypeLabel.fromString(merchantTypeStr),
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

  Future<void> logout() async {
    _session = null;
    notifyListeners();
    await ApiService.logoutSession();
    await AuthStorage.clear();
  }
}
