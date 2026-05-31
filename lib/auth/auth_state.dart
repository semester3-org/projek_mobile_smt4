import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
      debugPrint('Login error in AuthState: $e');
      return false;
    }
  }

  Future<String?> loginWithGoogle() async {
    try {
      final UserCredential userCredential;
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          return 'Login dibatalkan oleh pengguna.';
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      }
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        return 'Gagal mendapatkan profil pengguna dari Firebase.';
      }

      // Source of truth app ada di backend MySQL. Firebase dipakai untuk
      // Google Auth/FCM saja, jadi tidak perlu write ke Firestore.
      final result = await ApiService.loginWithGoogle(
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? 'Google User',
        photoUrl: firebaseUser.photoURL,
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
        return null; // Success
      } else {
        return result['message'] ?? 'Gagal menyimpan data ke database backend.';
      }
    } catch (e) {
      debugPrint('Google Login error in AuthState: $e');
      final errorStr = e.toString();
      if (errorStr.contains('10') ||
          errorStr.contains('developer_error') ||
          errorStr.contains('DEVELOPER_ERROR')) {
        return 'Error 10 (DEVELOPER_ERROR): Pastikan SHA-1 sudah ditambahkan ke Firebase Console, Google Sign-In aktif, dan file google-services.json sudah diperbarui.';
      }
      return 'Terjadi kesalahan login Google: $errorStr';
    }
  }

  Future<void> logout() async {
    _session = null;
    notifyListeners();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await ApiService.logoutSession();
    await AuthStorage.clear();
  }
}
