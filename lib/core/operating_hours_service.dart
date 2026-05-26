/// Cek jam operasional merchant berdasarkan waktu perangkat (real-time).
class OperatingHoursService {
  OperatingHoursService._();

  /// Parse "08:00 - 21:00" atau gunakan open/close terpisah.
  static ({String open, String close}) parseHours({
    String? openHours,
    String? openTime,
    String? closeTime,
  }) {
    var open = _normalizeTime(openTime);
    var close = _normalizeTime(closeTime);

    final combined = (openHours ?? '').trim();
    if (combined.contains('-')) {
      final parts = combined.split('-');
      if (parts.length >= 2) {
        open = _normalizeTime(parts.first.trim());
        close = _normalizeTime(parts.last.trim());
      }
    }

    return (open: open.isEmpty ? '08:00' : open, close: close.isEmpty ? '21:00' : close);
  }

  static String _normalizeTime(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return value;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static int _toMinutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  /// Apakah merchant buka pada [at] (default: sekarang).
  static bool isOpenNow({
    String? openHours,
    String? openTime,
    String? closeTime,
    DateTime? at,
  }) {
    final hours = parseHours(
      openHours: openHours,
      openTime: openTime,
      closeTime: closeTime,
    );
    final now = at ?? DateTime.now();
    final current = now.hour * 60 + now.minute;
    final openMin = _toMinutes(hours.open);
    final closeMin = _toMinutes(hours.close);

    if (openMin == closeMin) return true;
    if (closeMin > openMin) {
      return current >= openMin && current < closeMin;
    }
    // Tutup melewati tengah malam
    return current >= openMin || current < closeMin;
  }

  static String statusLabel({
    required bool isInactive,
    String? openHours,
    String? openTime,
    String? closeTime,
    DateTime? at,
  }) {
    if (isInactive) return 'Tutup';
    if (!isOpenNow(
      openHours: openHours,
      openTime: openTime,
      closeTime: closeTime,
      at: at,
    )) {
      return 'Tutup';
    }
    return 'Buka';
  }
}
