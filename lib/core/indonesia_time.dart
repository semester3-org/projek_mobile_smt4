class IndonesiaTime {
  const IndonesiaTime._();

  static int offsetHours({String? address, double? longitude}) {
    if (longitude != null) {
      if (longitude >= 135) return 9;
      if (longitude >= 120) return 8;
      return 7;
    }

    final text = (address ?? '').toLowerCase();
    if (_containsAny(text, const [
      'papua',
      'maluku',
      'jayapura',
      'sorong',
      'manokwari',
      'ambon',
      'ternate',
    ])) {
      return 9;
    }
    if (_containsAny(text, const [
      'bali',
      'ntb',
      'nusa tenggara barat',
      'ntt',
      'nusa tenggara timur',
      'kalimantan selatan',
      'kalimantan timur',
      'kalimantan utara',
      'sulawesi',
      'makassar',
      'denpasar',
      'mataram',
      'kupang',
      'balikpapan',
      'samarinda',
      'banjarmasin',
      'manado',
      'palu',
      'kendari',
      'gorontalo',
    ])) {
      return 8;
    }
    return 7;
  }

  static String label({String? address, double? longitude}) {
    return switch (offsetHours(address: address, longitude: longitude)) {
      9 => 'WIT',
      8 => 'WITA',
      _ => 'WIB',
    };
  }

  static DateTime parse(
    dynamic raw, {
    String? address,
    double? longitude,
    DateTime? fallback,
  }) {
    if (raw is DateTime) {
      return convert(raw, address: address, longitude: longitude);
    }
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return fallback ?? DateTime.now();
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return fallback ?? DateTime.now();
    return convert(parsed, address: address, longitude: longitude);
  }

  static DateTime? tryParse(
    dynamic raw, {
    String? address,
    double? longitude,
  }) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return convert(parsed, address: address, longitude: longitude);
  }

  static DateTime convert(
    DateTime date, {
    String? address,
    double? longitude,
  }) {
    final offset = offsetHours(address: address, longitude: longitude);
    final shifted = date.toUtc().add(Duration(hours: offset));
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  static bool _containsAny(String text, List<String> values) {
    return values.any(text.contains);
  }
}
