import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan JWT token dan data user di SharedPreferences.
/// Tambahkan dependency: shared_preferences: ^2.2.0
class AuthStorage {
  static const _keyToken = 'auth_token';
  static const _keySessionId = 'session_id';
  static const _keyUserId = 'user_id';
  static const _keyEmail = 'user_email';
  static const _keyDisplayName = 'display_name';
  static const _keyRole = 'user_role';
  static const _keyMerchantType = 'merchant_type';

  static Future<void> saveAuth({
    required String token,
    String? sessionId,
    required String userId,
    required String email,
    required String displayName,
    required String role,
    String? merchantType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    if (sessionId != null && sessionId.isNotEmpty) {
      await prefs.setString(_keySessionId, sessionId);
    }
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyDisplayName, displayName);
    await prefs.setString(_keyRole, role);
    if (merchantType != null && merchantType.isNotEmpty) {
      await prefs.setString(_keyMerchantType, merchantType);
    } else {
      await prefs.remove(_keyMerchantType);
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  static Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDisplayName);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  static Future<String?> getMerchantType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMerchantType);
  }

  static Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySessionId);
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
    await prefs.remove(_keySessionId);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyDisplayName);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyMerchantType);
  }
}
