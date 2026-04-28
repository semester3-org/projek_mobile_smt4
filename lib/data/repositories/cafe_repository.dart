import '../../core/api_service.dart';
import '../../models/cafe_place.dart';
import 'kos_repository.dart' show RepoResult;

/// Semua akses data cafe — menggantikan DummyData.cafes.
class CafeRepository {
  CafeRepository._();

  static const _endpoint = 'api/cafe_places';

  static Future<RepoResult<List<CafePlace>>> getAll() async {
    final res = await ApiService.get(_endpoint);

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat data cafe');
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => CafePlace.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list);
    } catch (e) {
      return RepoResult.fail('Gagal memproses data: $e');
    }
  }
}