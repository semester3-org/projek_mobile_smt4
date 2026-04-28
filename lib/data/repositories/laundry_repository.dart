import '../../core/api_service.dart';
import '../../models/laundry_place.dart';
import 'kos_repository.dart' show RepoResult;

/// Semua akses data laundry — menggantikan DummyData.laundries.
class LaundryRepository {
  LaundryRepository._();

  static const _endpoint = 'api/laundry_places';

  static Future<RepoResult<List<LaundryPlace>>> getAll() async {
    final res = await ApiService.get(_endpoint);

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat data laundry');
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => LaundryPlace.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list);
    } catch (e) {
      return RepoResult.fail('Gagal memproses data: $e');
    }
  }
}