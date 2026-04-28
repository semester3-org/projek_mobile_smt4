import '../../core/api_service.dart';
import '../../models/kos_listing.dart';

/// Hasil generik dari repository agar konsisten di seluruh app.
class RepoResult<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;

  const RepoResult.ok(this.data) : error = null;
  const RepoResult.fail(this.error) : data = null;
}

/// Semua akses data kos — menggantikan DummyData.kosList.
class KosRepository {
  KosRepository._();

  static const _endpoint = 'api/kos_listings_public';

  // ── Ambil semua kos (dengan filter opsional) ─────────────────────────────

  static Future<RepoResult<List<KosListing>>> getAll({
    String? search,
    int? maxPrice,
    List<String>? facilities,
  }) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (maxPrice != null) params['max_price'] = maxPrice.toString();
    if (facilities != null && facilities.isNotEmpty) {
      params['facilities'] = facilities.join(',');
    }

    final res = await ApiService.get(
      _endpoint,
      queryParams: params.isEmpty ? null : params,
    );

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat daftar kos');
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => KosListing.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list);
    } catch (e) {
      return RepoResult.fail('Gagal memproses data: $e');
    }
  }

  // ── Ambil detail satu kos ─────────────────────────────────────────────────

  static Future<RepoResult<KosListing>> getById(String id) async {
    final res = await ApiService.get(_endpoint, queryParams: {'id': id});

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Kos tidak ditemukan');
    }

    try {
      final kos =
          KosListing.fromJson(res.data!['data'] as Map<String, dynamic>);
      return RepoResult.ok(kos);
    } catch (e) {
      return RepoResult.fail('Gagal memproses data: $e');
    }
  }
}