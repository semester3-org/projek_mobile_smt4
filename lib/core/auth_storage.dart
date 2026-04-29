import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan JWT token dan data user di SharedPreferences.
/// Tambahkan dependency: shared_preferences: ^2.2.0
class AuthStorage {
  static const _keyToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyDisplayName = 'display_name';
  static const _keyRole = 'user_role';

  static Future<void> saveAuth({
    required String token,
    required String userId,
    required String displayName,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyDisplayName, displayName);
    await prefs.setString(_keyRole, role);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  static Future<void> updateDisplayName(String displayName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisplayName, displayName);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyDisplayName);
    await prefs.remove(_keyRole);
  }
}
