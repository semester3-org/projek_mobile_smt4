import '../../core/api_service.dart';
import '../../models/catering_package_category.dart';
import '../../models/catering_subscriber.dart';
import '../../models/laundry_service_estimate.dart';
import '../../models/merchant_models.dart';
import 'kos_repository.dart' show RepoResult;

class MerchantRepository {
  MerchantRepository._();

  static Future<RepoResult<MerchantDashboard>> getDashboard() async {
    final res = await ApiService.get('api/merchant_dashboard');
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat dashboard');
    }
    try {
      return RepoResult.ok(
        MerchantDashboard.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca dashboard: $e');
    }
  }

  static Future<RepoResult<List<MerchantOrder>>> getOrders({
    String? status,
    String? search,
  }) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final res = await ApiService.get(
      'api/merchant_orders',
      queryParams: params.isEmpty ? null : params,
    );
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat pesanan');
    }
    try {
      final data = (res.data!['data'] as List)
          .map((item) => MerchantOrder.fromJson(item as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(data);
    } catch (e) {
      return RepoResult.fail('Gagal membaca pesanan: $e');
    }
  }

  static Future<RepoResult<MerchantOrder>> getOrderDetail(String id) async {
    final res = await ApiService.get(
      'api/merchant_orders',
      queryParams: {'id': id},
    );
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat detail pesanan');
    }
    try {
      return RepoResult.ok(
        MerchantOrder.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca detail pesanan: $e');
    }
  }

  static Future<RepoResult<MerchantOrder>> updateOrder({
    required String id,
    String? status,
    String? estimatedTime,
    bool nextStatus = false,
    double? laundryWeightKg,
    double? laundryTotalAmount,
  }) async {
    final res = await ApiService.put('api/merchant_orders', {
      'id': id,
      if (status != null) 'status': status,
      if (estimatedTime != null) 'estimatedTime': estimatedTime,
      if (nextStatus) 'action': 'next',
      if (laundryWeightKg != null && laundryTotalAmount != null)
        'action': 'set_laundry_total',
      if (laundryWeightKg != null) 'weightKg': laundryWeightKg,
      if (laundryTotalAmount != null) 'totalAmount': laundryTotalAmount,
    });
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memperbarui pesanan');
    }
    try {
      return RepoResult.ok(
        MerchantOrder.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca pesanan terbaru: $e');
    }
  }

  static Future<RepoResult<List<MerchantProduct>>> getProducts() async {
    final res = await ApiService.get('api/merchant_products');
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat produk');
    }
    try {
      final data = (res.data!['data'] as List)
          .map((item) => MerchantProduct.fromJson(item as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(data);
    } catch (e) {
      return RepoResult.fail('Gagal membaca produk: $e');
    }
  }

  static Future<RepoResult<MerchantProduct>> saveProduct({
    String? id,
    required String name,
    required String description,
    required double price,
    double? price20Days,
    required String category,
    required String unit,
    required String imageUrl,
    required bool isActive,
  }) async {
    final payload = {
      if (id != null && id.isNotEmpty) 'id': id,
      'name': name,
      'description': description,
      'price': price,
      if (price20Days != null && price20Days > 0) 'price20Days': price20Days,
      'category': category,
      'unit': unit,
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
    final res = id == null || id.isEmpty
        ? await ApiService.post('api/merchant_products', payload)
        : await ApiService.put('api/merchant_products', payload);
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menyimpan produk');
    }
    try {
      return RepoResult.ok(
        MerchantProduct.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca produk terbaru: $e');
    }
  }

  static Future<RepoResult<bool>> deleteProduct(String id) async {
    final res = await ApiService.delete(
      'api/merchant_products',
      queryParams: {'id': id},
    );
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menghapus produk');
    }
    return const RepoResult.ok(true);
  }

  static Future<RepoResult<List<MerchantPromo>>> getPromos() async {
    final res = await ApiService.get('api/merchant_promos');
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat promo');
    }
    try {
      final data = (res.data!['data'] as List)
          .map((item) => MerchantPromo.fromJson(item as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(data);
    } catch (e) {
      return RepoResult.fail('Gagal membaca promo: $e');
    }
  }

  static Future<RepoResult<MerchantPromo>> savePromo({
    String? id,
    required String name,
    required String description,
    required String productId,
    required String discountType,
    required double discountValue,
    required double minOrderAmount,
    required double maxDiscountAmount,
    required DateTime? startAt,
    required DateTime? endAt,
    required bool isActive,
    int? usageLimit,
  }) async {
    final payload = {
      if (id != null && id.isNotEmpty) 'id': id,
      'name': name,
      'description': description,
      'productId': productId,
      'discountType': discountType,
      'discountValue': discountValue,
      'minOrderAmount': minOrderAmount,
      'maxDiscountAmount': maxDiscountAmount,
      'startAt': startAt?.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'isActive': isActive,
      if (usageLimit != null) 'usageLimit': usageLimit,
    };
    final res = id == null || id.isEmpty
        ? await ApiService.post('api/merchant_promos', payload)
        : await ApiService.put('api/merchant_promos', payload);
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menyimpan promo');
    }
    try {
      return RepoResult.ok(
        MerchantPromo.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca promo terbaru: $e');
    }
  }

  static Future<RepoResult<bool>> deletePromo(String id) async {
    final res = await ApiService.delete(
      'api/merchant_promos',
      queryParams: {'id': id},
    );
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menonaktifkan promo');
    }
    return const RepoResult.ok(true);
  }

  static Future<RepoResult<MerchantProfile>> getProfile() async {
    final res = await ApiService.get('api/merchant_profile');
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat profil merchant');
    }
    try {
      return RepoResult.ok(
        MerchantProfile.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca profil merchant: $e');
    }
  }

  static Future<RepoResult<MerchantProfile>> updateProfile({
    required String businessName,
    required String description,
    required String phone,
    required String address,
    double? latitude,
    double? longitude,
    required String photoUrl,
    required String openTime,
    required String closeTime,
    required List<String> categories,
  }) async {
    final res = await ApiService.put('api/merchant_profile', {
      'businessName': businessName,
      'description': description,
      'phone': phone,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'photoUrl': photoUrl,
      'openTime': openTime,
      'closeTime': closeTime,
      'categories': categories,
    });
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memperbarui profil');
    }
    try {
      return RepoResult.ok(
        MerchantProfile.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca profil terbaru: $e');
    }
  }

  static Future<RepoResult<List<MerchantNotification>>>
      getNotifications() async {
    final res = await ApiService.get('api/merchant_notifications');
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat notifikasi');
    }
    try {
      final data = (res.data!['data'] as List)
          .map((item) =>
              MerchantNotification.fromJson(item as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(data);
    } catch (e) {
      return RepoResult.fail('Gagal membaca notifikasi: $e');
    }
  }

  static Future<RepoResult<bool>> markNotificationRead(String id) async {
    final res = await ApiService.put('api/merchant_notifications', {
      'id': id,
      'action': 'mark_read',
    });
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menandai notifikasi');
    }
    return const RepoResult.ok(true);
  }

  static Future<RepoResult<bool>> markAllNotificationsRead() async {
    final res = await ApiService.put('api/merchant_notifications', {
      'action': 'mark_all_read',
    });
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal membaca semua notifikasi');
    }
    return const RepoResult.ok(true);
  }

  static Future<bool> hasUnreadNotifications() async {
    final result = await getNotifications();
    return (result.data ?? const <MerchantNotification>[])
        .any((item) => item.isUnread);
  }

  static Future<RepoResult<List<CateringSubscriber>>> getCateringSubscribers({
    String status = 'all',
  }) async {
    final res = await ApiService.get(
      'api/catering_subscribers',
      queryParams: {'status': status},
    );
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat pelanggan');
    }
    try {
      final list = (res.data!['data'] as List)
          .map((e) => CateringSubscriber.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list);
    } catch (e) {
      return RepoResult.fail('Gagal membaca pelanggan: $e');
    }
  }

  static Future<RepoResult<List<CateringPackageCategory>>>
      getPackageCategories() async {
    final res = await ApiService.get('api/catering_package_categories');
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat kategori');
    }
    try {
      final list = (res.data!['data'] as List)
          .map((e) =>
              CateringPackageCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list);
    } catch (e) {
      return RepoResult.fail('Gagal membaca kategori: $e');
    }
  }

  static Future<RepoResult<CateringPackageCategory>> savePackageCategory({
    String? id,
    required String categoryName,
    required String description,
    bool isActive = true,
  }) async {
    final payload = {
      if (id != null && id.isNotEmpty) 'id': id,
      'categoryName': categoryName,
      'description': description,
      'isActive': isActive,
    };
    final res = id == null || id.isEmpty
        ? await ApiService.post('api/catering_package_categories', payload)
        : await ApiService.put('api/catering_package_categories', payload);
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menyimpan kategori');
    }
    return RepoResult.ok(
      CateringPackageCategory(
        id: res.data!['data']['id'] as String? ?? id ?? '',
        categoryName: categoryName,
        description: description,
        isActive: isActive,
      ),
    );
  }

  static Future<RepoResult<bool>> deletePackageCategory(String id) async {
    final res = await ApiService.delete(
      'api/catering_package_categories',
      queryParams: {'id': id},
    );
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menghapus kategori');
    }
    return const RepoResult.ok(true);
  }

  static Future<RepoResult<List<LaundryServiceEstimate>>>
      getLaundryEstimates() async {
    final res = await ApiService.get('api/laundry_service_estimates');
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat estimasi');
    }
    try {
      final list = (res.data!['data'] as List)
          .map((e) =>
              LaundryServiceEstimate.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list);
    } catch (e) {
      return RepoResult.fail('Gagal membaca estimasi: $e');
    }
  }

  static Future<RepoResult<LaundryServiceEstimate>> saveLaundryEstimate({
    String? id,
    required String serviceName,
    required int minHours,
    required int maxHours,
    bool isActive = true,
  }) async {
    final payload = {
      if (id != null && id.isNotEmpty) 'id': id,
      'serviceName': serviceName,
      'minHours': minHours,
      'maxHours': maxHours,
      'isActive': isActive,
    };
    final res = id == null || id.isEmpty
        ? await ApiService.post('api/laundry_service_estimates', payload)
        : await ApiService.put('api/laundry_service_estimates', payload);
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menyimpan estimasi');
    }
    return RepoResult.ok(
      LaundryServiceEstimate(
        id: res.data!['data']['id'] as String? ?? id ?? '',
        serviceName: serviceName,
        minHours: minHours,
        maxHours: maxHours,
        estimateLabel: '',
        isActive: isActive,
      ),
    );
  }

  static Future<RepoResult<bool>> deleteLaundryEstimate(String id) async {
    final res = await ApiService.delete(
      'api/laundry_service_estimates',
      queryParams: {'id': id},
    );
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menghapus estimasi');
    }
    return const RepoResult.ok(true);
  }
}
