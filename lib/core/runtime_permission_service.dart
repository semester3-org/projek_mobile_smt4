import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RuntimePermissionService {
  RuntimePermissionService._();

  static const MethodChannel _channel =
      MethodChannel('ngekos/runtime_permissions');

  static Future<bool> isGalleryPermissionGranted() async {
    if (kIsWeb) return true;
    try {
      return await _channel.invokeMethod<bool>('isGalleryPermissionGranted') ??
          false;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestGalleryPermission() async {
    if (kIsWeb) return true;
    try {
      return await _channel.invokeMethod<bool>('requestGalleryPermission') ??
          false;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> ensureGalleryPermission(BuildContext context) async {
    if (await isGalleryPermissionGranted()) return true;
    final granted = await requestGalleryPermission();
    if (granted) return true;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aktifkan izin galeri agar bisa memilih foto.',
          ),
        ),
      );
    }
    return false;
  }
}
