import 'dart:async';

import '../../core/api_service.dart';
import '../../models/catering_package_category.dart';
import '../../models/catering_subscriber.dart';
import '../../models/laundry_service_estimate.dart';
import '../../models/merchant_models.dart';
import 'kos_repository.dart' show RepoResult;

class MerchantRepository {
  MerchantRepository._();

  static const Duration _shortCacheTtl = Duration(seconds: 3);
  static const Duration _notificationCountCacheTtl = Duration(seconds: 8);
  static _DashboardCacheEntry? _dashboardCache;
  static final Map<String, _MerchantOrdersCacheEntry> _ordersCache = {};
  static int? _unreadNotificationCountCache;
  static DateTime? _unreadNotificationCountCachedAt;
  static final StreamController<void> _notificationCountController =
      StreamController<void>.broadcast();

  static Stream<void> get notificationCountChanges =>
      _notificationCountController.stream;

  static void _notifyNotificationCountChanged() {
    if (!_notificationCountController.isClosed) {
      _notificationCountController.add(null);
    }
  }

  static void clearSessionCache() {
    _dashboardCache = null;
    _ordersCache.clear();
    _unreadNotificationCountCache = null;
    _unreadNotificationCountCachedAt = null;
    _notifyNotificationCountChanged();
  }

  static Future<RepoResult<MerchantDashboard>> getDashboard() async {
    final cached = _dashboardCache;
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _shortCacheTtl) {
      return RepoResult.ok(cached.dashboard);
    }

    final res = await ApiService.get('api/merchant_dashboard');
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat dashboard');
    }
    try {
      final dashboard = MerchantDashboard.fromJson(
        res.data!['data'] as Map<String, dynamic>,
      );
      _dashboardCache = _DashboardCacheEntry(dashboard, DateTime.now());
      return RepoResult.ok(dashboard);
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
    final cacheKey = '${status ?? ''}:${search ?? ''}';
    final cached = _ordersCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _shortCacheTtl) {
      return RepoResult.ok(List<MerchantOrder>.of(cached.orders));
    }

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
      _ordersCache[cacheKey] = _MerchantOrdersCacheEntry(
        List<MerchantOrder>.of(data),
        DateTime.now(),
      );
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
    List<String> laundryAddonIds = const [],
    String? deliveryLogId,
  }) async {
    _clearOrderCaches();
    final res = await ApiService.put('api/merchant_orders', {
      'id': id,
      if (status != null) 'status': status,
      if (estimatedTime != null) 'estimatedTime': estimatedTime,
      if (nextStatus) 'action': 'next',
      if (laundryWeightKg != null) 'action': 'set_laundry_total',
      if (laundryWeightKg != null) 'weightKg': laundryWeightKg,
      if (laundryTotalAmount != null) 'totalAmount': laundryTotalAmount,
      if (laundryAddonIds.isNotEmpty) 'addonIds': laundryAddonIds,
      if (deliveryLogId != null) 'deliveryLogId': deliveryLogId,
    });
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memperbarui pesanan');
    }
    try {
      _clearOrderCaches();
      return RepoResult.ok(
        MerchantOrder.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca pesanan terbaru: $e');
    }
  }

  static Future<RepoResult<MerchantOrder>> completeCateringDelivery({
    required String orderId,
    required String deliveryLogId,
    String deliveryNote = '',
    String deliveryPhotoUrl = '',
  }) async {
    _clearOrderCaches();
    final res = await ApiService.put('api/merchant_orders', {
      'id': orderId,
      'action': 'complete_delivery',
      'deliveryLogId': deliveryLogId,
      'deliveryNote': deliveryNote,
      'deliveryPhotoUrl': deliveryPhotoUrl,
    });
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menyelesaikan pengantaran');
    }
    try {
      _clearOrderCaches();
      return RepoResult.ok(
        MerchantOrder.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca pesanan terbaru: $e');
    }
  }

  static Future<RepoResult<MerchantOrder>> rejectOrder({
    required String orderId,
    required String reason,
  }) async {
    _clearOrderCaches();
    final res = await ApiService.put('api/merchant_orders', {
      'id': orderId,
      'action': 'reject_order',
      'reason': reason,
    });
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menolak pesanan');
    }
    try {
      _clearOrderCaches();
      return RepoResult.ok(
        MerchantOrder.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca pesanan terbaru: $e');
    }
  }

  static void _clearOrderCaches() {
    _ordersCache.clear();
    _dashboardCache = null;
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
    String pricingType = 'per_kg',
    int? durationValue,
    String durationUnit = 'day',
    List<MerchantLaundryAddon> addons = const [],
    required String imageUrl,
    required bool isActive,
    int mealDeliveryCount = 1,
    String deliveryTime1 = '07:00',
    String? deliveryTime2,
  }) async {
    final payload = {
      if (id != null && id.isNotEmpty) 'id': id,
      'name': name,
      'description': description,
      'price': price,
      if (price20Days != null) 'price20Days': price20Days,
      'category': category,
      'unit': unit,
      'pricingType': pricingType,
      if (durationValue != null) 'durationValue': durationValue,
      'durationUnit': durationUnit,
      if (addons.isNotEmpty) 'addons': addons.map((e) => e.toJson()).toList(),
      'imageUrl': imageUrl,
      'isActive': isActive,
      'mealDeliveryCount': mealDeliveryCount,
      'deliveryTime1': deliveryTime1,
      if (deliveryTime2 != null && deliveryTime2.isNotEmpty)
        'deliveryTime2': deliveryTime2,
    };
    final res = id == null || id.isEmpty
        ? await ApiService.post('api/merchant_products', payload)
        : await ApiService.put('api/merchant_products', payload);
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menyimpan produk');
    }
    try {
      _dashboardCache = null;
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
    _dashboardCache = null;
    return const RepoResult.ok(true);
  }

  static Future<RepoResult<List<MerchantProductReviewSummary>>>
      getProductReviews({
    int? rating,
  }) async {
    final params = <String, String>{};
    if (rating != null && rating > 0) params['rating'] = rating.toString();
    final res = await ApiService.get(
      'api/merchant_product_reviews',
      queryParams: params.isEmpty ? null : params,
    );
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat ulasan produk');
    }
    try {
      final list = (res.data!['data'] as List)
          .map((item) => MerchantProductReviewSummary.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList();
      return RepoResult.ok(list);
    } catch (e) {
      return RepoResult.fail('Gagal membaca ulasan produk: $e');
    }
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
    String productId = '',
    List<String> productIds = const [],
    required String discountType,
    required double discountValue,
    required double minOrderAmount,
    required double maxDiscountAmount,
    required DateTime? startAt,
    required DateTime? endAt,
    required bool isActive,
    String? status,
    int? usageLimit,
    int perUserUsageLimit = 1,
  }) async {
    final payload = {
      if (id != null && id.isNotEmpty) 'id': id,
      'name': name,
      'description': description,
      if (productId.isNotEmpty) 'productId': productId,
      if (productIds.isNotEmpty) 'productIds': productIds,
      'discountType': discountType,
      'discountValue': discountValue,
      'minOrderAmount': minOrderAmount,
      'maxDiscountAmount': maxDiscountAmount,
      'startAt': startAt?.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'isActive': isActive,
      if (status != null && status.isNotEmpty) 'status': status,
      'perUserUsageLimit': perUserUsageLimit,
      if (usageLimit != null) 'usageLimit': usageLimit,
    };
    final res = id == null || id.isEmpty
        ? await ApiService.post('api/merchant_promos', payload)
        : await ApiService.put('api/merchant_promos', payload);
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menyimpan promo');
    }
    try {
      _dashboardCache = null;
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
    _dashboardCache = null;
    return const RepoResult.ok(true);
  }

  static Future<RepoResult<Map<String, dynamic>>> previewPromo({
    String? merchantId,
    required double subtotal,
    List<String> productIds = const [],
    String? discountType,
    double? discountValue,
    double? minOrderAmount,
    double? maxDiscountAmount,
    String? name,
    String? userId,
  }) async {
    final items = productIds
        .where((id) => id.isNotEmpty)
        .map((id) => {'productId': int.tryParse(id) ?? 0})
        .where((item) => (item['productId'] ?? 0) > 0)
        .toList();

    final payload = <String, dynamic>{
      'subtotal': subtotal,
      if (items.isNotEmpty) 'items': items,
      if (discountType != null && discountType.isNotEmpty)
        'discountType': discountType,
      if (discountValue != null && discountValue > 0)
        'discountValue': discountValue,
      if (minOrderAmount != null) 'minOrderAmount': minOrderAmount,
      if (maxDiscountAmount != null) 'maxDiscountAmount': maxDiscountAmount,
      if (name != null && name.isNotEmpty) 'name': name,
      if (userId != null && userId.isNotEmpty) 'userId': userId,
    };
    if (merchantId != null && merchantId.isNotEmpty) {
      payload['merchantId'] = merchantId;
    }

    final res = await ApiService.post('api/promo_preview', payload);
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal preview promo');
    }
    try {
      return RepoResult.ok(res.data!['data'] as Map<String, dynamic>);
    } catch (e) {
      return RepoResult.fail('Gagal membaca preview promo: $e');
    }
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
    });
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memperbarui profil');
    }
    try {
      _dashboardCache = null;
      return RepoResult.ok(
        MerchantProfile.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca profil terbaru: $e');
    }
  }

  static Future<RepoResult<List<MerchantNotification>>> getNotifications({
    int limit = 30,
  }) async {
    final res = await ApiService.get(
      'api/merchant_notifications',
      queryParams: {'limit': limit.toString()},
    );
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
    _unreadNotificationCountCache = null;
    _notifyNotificationCountChanged();
    return const RepoResult.ok(true);
  }

  static Future<RepoResult<bool>> markAllNotificationsRead() async {
    final res = await ApiService.put('api/merchant_notifications', {
      'action': 'mark_all_read',
    });
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal membaca semua notifikasi');
    }
    _unreadNotificationCountCache = 0;
    _unreadNotificationCountCachedAt = DateTime.now();
    _notifyNotificationCountChanged();
    return const RepoResult.ok(true);
  }

  static Future<bool> hasUnreadNotifications() async {
    return (await unreadNotificationCount()) > 0;
  }

  static void invalidateNotificationCountCache() {
    _unreadNotificationCountCache = null;
    _unreadNotificationCountCachedAt = null;
    _notifyNotificationCountChanged();
  }

  static Future<int> unreadNotificationCount() async {
    final cachedAt = _unreadNotificationCountCachedAt;
    final cached = _unreadNotificationCountCache;
    if (cachedAt != null &&
        cached != null &&
        DateTime.now().difference(cachedAt) < _notificationCountCacheTtl) {
      return cached;
    }
    final res = await ApiService.get(
      'api/merchant_notifications',
      queryParams: const {'count': '1'},
    );
    final payload = res.data?['data'];
    final count = res.success && payload is Map<String, dynamic>
        ? (payload['count'] as num?)?.toInt() ?? 0
        : 0;
    _unreadNotificationCountCache = count;
    _unreadNotificationCountCachedAt = DateTime.now();
    return count;
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
          .map(
              (e) => LaundryServiceEstimate.fromJson(e as Map<String, dynamic>))
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

class _DashboardCacheEntry {
  const _DashboardCacheEntry(this.dashboard, this.createdAt);

  final MerchantDashboard dashboard;
  final DateTime createdAt;
}

class _MerchantOrdersCacheEntry {
  const _MerchantOrdersCacheEntry(this.orders, this.createdAt);

  final List<MerchantOrder> orders;
  final DateTime createdAt;
}
