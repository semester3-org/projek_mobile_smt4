import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'auth_storage.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int statusCode;

  const ApiResponse({
    required this.success,
    required this.statusCode,
    this.data,
    this.message,
  });

  bool get isUnauthorized => statusCode == 401;
}

class ApiService {
  static final http.Client _client = http.Client();
  static final Map<String, Future<ApiResponse<Map<String, dynamic>>>>
      _inFlightGets = {};
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  // Base URL can be overridden per machine:
  // flutter run --dart-define=API_BASE_URL=http://<host>:8000
  //
  // Defaults:
  // - Web / desktop / iOS simulator: localhost:8000
  // - Android emulator: 10.0.2.2:8000
  // - Physical phone: use --dart-define with your laptop IP.
  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/$'), '');
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (Platform.isAndroid) {
      // Emulator Android → 10.0.2.2 mengarah ke localhost laptop
      return 'http://10.0.2.2:8000';
      // Device fisik → uncomment baris bawah, ganti IP dengan hasil ipconfig
      // return 'http://192.168.1.10:8000';
    } else if (Platform.isIOS) {
      return 'http://localhost:8000';
    } else {
      return 'http://localhost:8000';
    }
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static const Map<String, String> _publicHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── Auth endpoints ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required String role,
    String? merchantType,
  }) async {
    try {
      final body = {
        'email': email.trim().toLowerCase(),
        'password': password,
        'displayName': displayName.trim(),
        'phone': phone.trim(),
        'role': role.toLowerCase(),
      };

      if (merchantType != null) {
        body['merchantType'] = merchantType.toLowerCase();
      }

      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/register'),
            headers: _publicHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server mengembalikan response kosong'
        };
      }

      final data = jsonDecode(response.body);
      return {
        'success': data['success'] == true,
        'data': data['data'],
        'message': data['message'] ??
            (data['success'] == true
                ? 'Registrasi berhasil'
                : 'Registrasi gagal'),
      };
    } on SocketException {
      return {
        'success': false,
        'message':
            'Koneksi gagal. Pastikan server PHP berjalan (php -S localhost:8000).',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timeout. Coba lagi.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/login'),
            headers: _publicHeaders,
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server mengembalikan response kosong'
        };
      }

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['data'] != null) {
        final userData = data['data'] as Map<String, dynamic>;
        final token = userData['token'] as String? ?? '';
        if (token.isNotEmpty) {
          await AuthStorage.saveAuth(
            token: token,
            sessionId: userData['sessionId'] as String?,
            userId: userData['id'] as String? ?? '',
            email: userData['email'] as String? ?? email.trim().toLowerCase(),
            displayName: userData['displayName'] as String? ?? '',
            role: userData['role'] as String? ?? 'user',
            merchantType: userData['merchantType'] as String?,
          );
        }
      }

      return {
        'success': data['success'] == true,
        'data': data['data'],
        'message': data['message'] ??
            (data['success'] == true ? 'Login berhasil' : 'Login gagal'),
      };
    } on SocketException {
      return {
        'success': false,
        'message':
            'Koneksi gagal. Pastikan server PHP berjalan (php -S localhost:8000).',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timeout. Coba lagi.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> loginWithGoogle({
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/login-google'),
            headers: _publicHeaders,
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'displayName': displayName.trim(),
              'photoUrl': photoUrl,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server mengembalikan response kosong'
        };
      }

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['data'] != null) {
        final userData = data['data'] as Map<String, dynamic>;
        final token = userData['token'] as String? ?? '';
        if (token.isNotEmpty) {
          await AuthStorage.saveAuth(
            token: token,
            sessionId: userData['sessionId'] as String?,
            userId: userData['id'] as String? ?? '',
            email: userData['email'] as String? ?? email.trim().toLowerCase(),
            displayName: userData['displayName'] as String? ?? '',
            role: userData['role'] as String? ?? 'user',
            merchantType: userData['merchantType'] as String?,
          );
        }
      }

      return {
        'success': data['success'] == true,
        'data': data['data'],
        'message': data['message'] ??
            (data['success'] == true
                ? 'Login Google berhasil'
                : 'Login Google gagal'),
      };
    } on SocketException {
      return {
        'success': false,
        'message': 'Koneksi gagal. Pastikan server PHP berjalan.',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timeout. Coba lagi.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> restoreSession() async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/session'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server mengembalikan response kosong'
        };
      }

      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        final userData = data['data'] as Map<String, dynamic>;
        await AuthStorage.saveAuth(
          token: userData['token'] as String? ?? token,
          sessionId: userData['sessionId'] as String?,
          userId: userData['id'] as String? ?? '',
          email: userData['email'] as String? ?? '',
          displayName: userData['displayName'] as String? ?? '',
          role: userData['role'] as String? ?? 'user',
          merchantType: userData['merchantType'] as String?,
        );
      }

      return {
        'success': data['success'] == true,
        'data': data['data'],
        'message': data['message'] ??
            (data['success'] == true
                ? 'Session masih aktif'
                : 'Session tidak valid'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  static Future<void> logoutSession() async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) return;

      await _client
          .delete(
            Uri.parse('$baseUrl/api/session'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Local logout should still continue even if server logout fails.
    }
  }

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/forgot-password'),
            headers: _publicHeaders,
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server mengembalikan response kosong'
        };
      }
      final data = jsonDecode(response.body);
      return {
        'success': data['success'] == true,
        'message': data['message'] ?? 'Gagal mengirim token reset password',
        'data': data['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String email,
    required String newPassword,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/reset-password'),
            headers: _publicHeaders,
            body: jsonEncode({
              'token': token.trim(),
              'email': email.trim().toLowerCase(),
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server mengembalikan response kosong'
        };
      }
      final data = jsonDecode(response.body);
      return {
        'success': data['success'] == true,
        'message': data['message'] ??
            (data['success'] == true
                ? 'Password berhasil direset'
                : 'Gagal mereset password'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // ── Generic CRUD dengan JWT ────────────────────────────────────────────────

  static Future<ApiResponse<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    var uri = Uri.parse('$baseUrl/$endpoint');
    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final headers = await _authHeaders();
    final authKey = headers['Authorization'] ?? '';
    final cacheKey = '$uri|$authKey';
    final existing = _inFlightGets[cacheKey];
    if (existing != null) return existing;

    final request = _get(uri, headers).whenComplete(() {
      _inFlightGets.remove(cacheKey);
    });
    _inFlightGets[cacheKey] = request;
    return request;
  }

  static Future<ApiResponse<Map<String, dynamic>>> _get(
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      return _parseResponse(response);
    } on SocketException {
      return const ApiResponse(
          success: false, statusCode: 0, message: 'Tidak ada koneksi internet');
    } on TimeoutException {
      return const ApiResponse(
          success: false,
          statusCode: 0,
          message: 'Request timeout. Coba lagi.');
    } catch (e) {
      return ApiResponse(
          success: false, statusCode: 0, message: 'Terjadi kesalahan: $e');
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/$endpoint'),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _parseResponse(response);
    } on SocketException {
      return const ApiResponse(
          success: false, statusCode: 0, message: 'Tidak ada koneksi internet');
    } catch (e) {
      return ApiResponse(
          success: false, statusCode: 0, message: 'Terjadi kesalahan: $e');
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> put(
    String endpoint,
    Map<String, dynamic> body, {
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await _client
          .put(uri, headers: await _authHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _parseResponse(response);
    } on SocketException {
      return const ApiResponse(
          success: false, statusCode: 0, message: 'Tidak ada koneksi internet');
    } catch (e) {
      return ApiResponse(
          success: false, statusCode: 0, message: 'Terjadi kesalahan: $e');
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> delete(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await _client
          .delete(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 15));
      return _parseResponse(response);
    } on SocketException {
      return const ApiResponse(
          success: false, statusCode: 0, message: 'Tidak ada koneksi internet');
    } catch (e) {
      return ApiResponse(
          success: false, statusCode: 0, message: 'Terjadi kesalahan: $e');
    }
  }

  static ApiResponse<Map<String, dynamic>> _parseResponse(
      http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: json['success'] == true,
        statusCode: response.statusCode,
        data: json,
        message: json['message'] as String?,
      );
    } catch (_) {
      return ApiResponse(
        success: false,
        statusCode: response.statusCode,
        message: 'Gagal memproses response dari server',
      );
    }
  }
}
