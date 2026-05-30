import 'package:geolocator/geolocator.dart';

import '../data/repositories/user_repository.dart';

/// Koordinat user untuk jarak/ETA merchant: alamat profil dari map lebih
/// diprioritaskan daripada GPS agar card merchant mengikuti alamat tujuan user.
class UserLocationService {
  UserLocationService._();

  static ({double latitude, double longitude})? _cache;
  static DateTime? _cacheAt;

  static Future<({double latitude, double longitude})?> current() async {
    final now = DateTime.now();
    if (_cache != null &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < const Duration(minutes: 2)) {
      return _cache;
    }

    final profile = await UserRepository.getProfile(
      displayName: 'User',
      email: '',
      role: 'user',
    );
    final lat = profile.data?.latitude;
    final lng = profile.data?.longitude;
    if (lat != null && lng != null && _isValid(lat, lng)) {
      _cache = (latitude: lat, longitude: lng);
      _cacheAt = now;
      return _cache;
    }

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (enabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          ).timeout(const Duration(seconds: 8));
          if (_isValid(pos.latitude, pos.longitude)) {
            _cache = (latitude: pos.latitude, longitude: pos.longitude);
            _cacheAt = now;
            return _cache;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static void invalidate() {
    _cache = null;
    _cacheAt = null;
  }

  static bool _isValid(double lat, double lng) {
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
}
