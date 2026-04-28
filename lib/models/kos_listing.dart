import '../core/api_service.dart';

// ── Model ──────────────────────────────────────────────────────────────────────

class KosListing {
  const KosListing({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.location,
    required this.description,
    required this.pricePerMonth,
    required this.rating,
    required this.accessCode,
    required this.ownerContact,
    this.imageUrls = const [],
    this.facilities = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String title;
  final String location;
  final String description;
  final int pricePerMonth;
  final double rating;
  final String accessCode;
  final String ownerContact;
  final List<String> imageUrls;   // dari kos_images (public endpoint)
  final List<String> facilities;  // dari kos_facilities (public endpoint)
  final String? createdAt;
  final String? updatedAt;

  factory KosListing.fromJson(Map<String, dynamic> json) => KosListing(
        id:            json['id'] as String,
        ownerId:       json['ownerId'] as String? ?? '',
        title:         json['title'] as String,
        location:      json['location'] as String,
        description:   json['description'] as String? ?? '',
        pricePerMonth: _parseInt(json['pricePerMonth']),
        rating:        _parseDouble(json['rating']),
        accessCode:    json['accessCode'] as String? ?? '',
        ownerContact:  json['ownerContact'] as String? ?? '',
        // Kedua field ini ada di response kos_listings_public.php,
        // tapi tidak ada di kos_listings.php (owner) — default ke list kosong.
        imageUrls:  json['imageUrls']  != null
            ? List<String>.from(json['imageUrls'] as List)
            : const [],
        facilities: json['facilities'] != null
            ? List<String>.from(json['facilities'] as List)
            : const [],
        createdAt:  json['createdAt'] as String?,
        updatedAt:  json['updatedAt'] as String?,
      );

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

// ── Result wrapper ─────────────────────────────────────────────────────────────

class KosListingResult<T> {
  const KosListingResult.success(this.data) : error = null;
  const KosListingResult.failure(this.error) : data = null;

  final T? data;
  final String? error;

  bool get isSuccess => error == null;
}

// ── Repository ────────────────────────────────────────────────────────────────

class KosListingRepository {
  static const _endpoint = 'api/kos_listings.php';

  /// Ambil semua kos milik owner yang sedang login
  static Future<KosListingResult<List<KosListing>>> getMyListings() async {
    final res = await ApiService.get(_endpoint);

    if (!res.success) {
      return KosListingResult.failure(res.message ?? 'Gagal memuat daftar kos');
    }

    final list = (res.data!['data'] as List)
        .map((e) => KosListing.fromJson(e as Map<String, dynamic>))
        .toList();

    return KosListingResult.success(list);
  }
}