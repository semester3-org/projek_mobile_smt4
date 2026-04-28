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
  // ── Base URL ───────────────────────────────────────────────────────────────
  // Server: php -S localhost:8000 router.php
  //
  // Web / iOS Simulator / Desktop  → localhost:8000
  // Android Emulator               → 10.0.2.2:8000
  // Device fisik                   → IP laptop:8000  (cek via: ipconfig)
  // ──────────────────────────────────────────────────────────────────────────
  static String get baseUrl {
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
    required String role,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/register'),
            headers: _publicHeaders,
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'password': password,
              'displayName': displayName.trim(),
              'role': role.toLowerCase(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Server mengembalikan response kosong'};
      }

      final data = jsonDecode(response.body);
      return {
        'success': data['success'] == true,
        'data': data['data'],
        'message': data['message'] ??
            (data['success'] == true ? 'Registrasi berhasil' : 'Registrasi gagal'),
      };
    } on SocketException {
      return {
        'success': false,
        'message': 'Koneksi gagal. Pastikan server PHP berjalan (php -S localhost:8000).',
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
      final response = await http
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
        return {'success': false, 'message': 'Server mengembalikan response kosong'};
      }

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['data'] != null) {
        final userData = data['data'] as Map<String, dynamic>;
        final token = userData['token'] as String? ?? '';
        if (token.isNotEmpty) {
          await AuthStorage.saveAuth(
            token: token,
            userId: userData['id'] as String? ?? '',
            displayName: userData['displayName'] as String? ?? '',
            role: userData['role'] as String? ?? 'user',
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
        'message': 'Koneksi gagal. Pastikan server PHP berjalan (php -S localhost:8000).',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timeout. Coba lagi.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/forgot-password'),
            headers: _publicHeaders,
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Server mengembalikan response kosong'};
      }
      final data = jsonDecode(response.body);
      return {
        'success': data['success'] == true,
        'message': data['message'] ?? 'Gagal mengirim link reset password',
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
      final response = await http
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
        return {'success': false, 'message': 'Server mengembalikan response kosong'};
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
    try {
      var uri = Uri.parse('$baseUrl/$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await http
          .get(uri, headers: await _authHeaders())
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

  static Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
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
      final response = await http
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
      final response = await http
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

  static ApiResponse<Map<String, dynamic>> _parseResponse(http.Response response) {
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