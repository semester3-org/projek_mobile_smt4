import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_service.dart';
import '../../models/billing_record.dart';
import '../../models/notification.dart';
import '../../models/catering_subscriber.dart';
import '../../models/order.dart';
import '../../models/user_dashboard.dart';
import '../../models/user_merchant.dart';
import '../../models/user_profile.dart';
import 'kos_repository.dart' show RepoResult;

class UserRepository {
  UserRepository._();

  static const String _profileKey = 'user_profile';
  static const String _billingStatusKey = 'user_billing_statuses';
  static const String _favoriteMerchantsKey = 'favorite_merchants';
  static const Duration _dashboardCacheTtl = Duration(seconds: 12);
  static const Duration _merchantListCacheTtl = Duration(seconds: 5);
  static const Duration _merchantDetailCacheTtl = Duration(seconds: 5);
  static const Duration _notificationCountCacheTtl = Duration(seconds: 8);
  static const Duration _profileCacheTtl = Duration(seconds: 15);
  static const Duration _favoriteKeysCacheTtl = Duration(seconds: 5);
  static _DashboardCacheEntry? _dashboardCache;
  static final Map<String, _MerchantListCacheEntry> _merchantListCache = {};
  static final Map<String, _MerchantDetailCacheEntry> _merchantDetailCache = {};
  static _ProfileCacheEntry? _profileCache;
  static _BillingCacheEntry? _billingCache;
  static Set<String>? _favoriteKeysCache;
  static DateTime? _favoriteKeysCachedAt;
  static int? _unreadNotificationCountCache;
  static DateTime? _unreadNotificationCountCachedAt;
  static final StreamController<void> _notificationCountController =
      StreamController<void>.broadcast();

  static final StreamController<void> _profileRefreshController =
      StreamController<void>.broadcast();
  static final StreamController<void> _favoriteController =
      StreamController<void>.broadcast();

  static Stream<void> get profileRefreshRequests =>
      _profileRefreshController.stream;

  static Stream<void> get notificationCountChanges =>
      _notificationCountController.stream;

  static Stream<void> get favoriteChanges => _favoriteController.stream;

  static void _notifyNotificationCountChanged() {
    if (!_notificationCountController.isClosed) {
      _notificationCountController.add(null);
    }
  }

  static void requestProfileRefresh() {
    if (!_profileRefreshController.isClosed) {
      _profileRefreshController.add(null);
    }
  }

  static void _notifyFavoriteChanged() {
    if (!_favoriteController.isClosed) {
      _favoriteController.add(null);
    }
  }

  static void clearSessionCache() {
    _dashboardCache = null;
    _merchantListCache.clear();
    _merchantDetailCache.clear();
    _profileCache = null;
    _billingCache = null;
    _favoriteKeysCache = null;
    _favoriteKeysCachedAt = null;
    _unreadNotificationCountCache = null;
    _unreadNotificationCountCachedAt = null;
    _notifyNotificationCountChanged();
    _notifyFavoriteChanged();
  }

  static Future<RepoResult<UserDashboard>> getDashboard({
    required String displayName,
    bool forceRefresh = false,
  }) async {
    final cached = _dashboardCache;
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) < _dashboardCacheTtl) {
      return RepoResult.ok(cached.dashboard);
    }

    final res = await ApiService.get('api/user_dashboard');

    if (!res.success) {
      return RepoResult.ok(UserDashboard.fallback(displayName));
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      final dashboard = UserDashboard.fromJson(data);
      _dashboardCache = _DashboardCacheEntry(dashboard, DateTime.now());
      return RepoResult.ok(dashboard);
    } catch (_) {
      return RepoResult.ok(UserDashboard.fallback(displayName));
    }
  }

  static Future<RepoResult<List<UserMerchant>>> getMerchants(
    String type, {
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _merchantListCacheKey(type, latitude, longitude);
    final cached = _merchantListCache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) < _merchantListCacheTtl) {
      return RepoResult.ok(List<UserMerchant>.of(cached.items));
    }

    final params = {'type': type, 'summary': '1'};
    if (latitude != null && longitude != null) {
      params['lat'] = latitude.toString();
      params['lng'] = longitude.toString();
    }
    final res = await ApiService.get(
      'api/user_merchants',
      queryParams: params,
    );

    if (!res.success) {
      if (cached != null) {
        return RepoResult.ok(List<UserMerchant>.of(cached.items));
      }
      return RepoResult.fail(res.message ?? 'Gagal memuat merchant');
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => UserMerchant.fromJson(e as Map<String, dynamic>))
          .toList();
      final unique = _dedupeMerchants(list);
      final items = unique;
      _merchantListCache[cacheKey] = _MerchantListCacheEntry(
        List<UserMerchant>.of(items),
        DateTime.now(),
      );
      return RepoResult.ok(items);
    } catch (_) {
      if (cached != null) {
        return RepoResult.ok(List<UserMerchant>.of(cached.items));
      }
      return const RepoResult.fail('Gagal membaca data merchant');
    }
  }

  static Future<RepoResult<UserMerchant>> getMerchantDetail({
    required String type,
    required String id,
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _merchantDetailCacheKey(type, id, latitude, longitude);
    final cached = _merchantDetailCache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) < _merchantDetailCacheTtl) {
      return RepoResult.ok(cached.item);
    }

    final params = {'type': type, 'id': id};
    if (latitude != null && longitude != null) {
      params['lat'] = latitude.toString();
      params['lng'] = longitude.toString();
    }
    final res = await ApiService.get(
      'api/user_merchants',
      queryParams: params,
    );

    if (!res.success) {
      if (cached != null) return RepoResult.ok(cached.item);
      return RepoResult.fail(res.message ?? 'Gagal memuat detail merchant');
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      final merchant = UserMerchant.fromJson(data);
      _merchantDetailCache[cacheKey] =
          _MerchantDetailCacheEntry(merchant, DateTime.now());
      return RepoResult.ok(merchant);
    } catch (_) {
      if (cached != null) return RepoResult.ok(cached.item);
      return const RepoResult.fail('Gagal membaca detail merchant');
    }
  }

  static String _merchantListCacheKey(
    String type,
    double? latitude,
    double? longitude,
  ) {
    final lat = latitude == null ? 'none' : latitude.toStringAsFixed(3);
    final lng = longitude == null ? 'none' : longitude.toStringAsFixed(3);
    return '$type:$lat:$lng';
  }

  static String _merchantDetailCacheKey(
    String type,
    String id,
    double? latitude,
    double? longitude,
  ) {
    final lat = latitude == null ? 'none' : latitude.toStringAsFixed(3);
    final lng = longitude == null ? 'none' : longitude.toStringAsFixed(3);
    return '$type:$id:$lat:$lng';
  }

  static Future<RepoResult<List<BillingRecord>>> getBillings({
    bool forceRefresh = false,
  }) async {
    final cached = _billingCache;
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) <
            const Duration(seconds: 8)) {
      return RepoResult.ok(cached.items);
    }

    final res = await ApiService.get('api/user_billings');

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat tagihan');
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => BillingRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      final applied = await _applyLocalBillingStatuses(list);
      _billingCache = _BillingCacheEntry(applied, DateTime.now());
      return RepoResult.ok(applied);
    } catch (_) {
      return const RepoResult.fail('Gagal membaca data tagihan');
    }
  }

  static Future<RepoResult<bool>> cancelBillingOrder({
    required String billingId,
    required bool keepDueDateIfPaid,
    DateTime? paidUntil,
  }) async {
    final res = await ApiService.put('api/user_billings', {
      'id': billingId,
      'action': 'cancel_order',
      'keep_due_date_if_paid': keepDueDateIfPaid,
      if (paidUntil != null) 'paid_until': paidUntil.toIso8601String(),
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal membatalkan order');
    }

    _billingCache = null;
    return const RepoResult.ok(true);
  }

  static Future<RepoResult<Map<String, dynamic>>> createMidtransPayment({
    required String orderId,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String paymentMethod,
  }) async {
    final res = await ApiService.post('api/midtrans', {
      'order_id': orderId,
      'amount': amount,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'payment_method': paymentMethod,
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal membuat transaksi Midtrans');
    }

    final data = res.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const RepoResult.fail('Response Midtrans tidak valid');
    }

    _billingCache = null;
    return RepoResult.ok(data);
  }

  static Future<RepoResult<Map<String, dynamic>>> createOrderMidtransPayment({
    required String orderId,
    required String paymentMethod,
  }) async {
    final res = await ApiService.post('api/midtrans', {
      'action': 'create_order_payment',
      'order_id': orderId,
      'payment_method': paymentMethod,
    });

    if (!res.success) {
      return RepoResult.fail(
          res.message ?? 'Gagal membuat pembayaran Midtrans');
    }

    final data = res.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const RepoResult.fail('Response Midtrans tidak valid');
    }

    return RepoResult.ok(data);
  }

  static Future<RepoResult<Map<String, dynamic>>> syncOrderMidtransStatus({
    required String midtransOrderId,
  }) async {
    final res = await ApiService.post('api/midtrans', {
      'action': 'sync_order_status',
      'midtrans_order_id': midtransOrderId,
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal mengecek status Midtrans');
    }

    final data = res.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const RepoResult.fail('Response status Midtrans tidak valid');
    }

    return RepoResult.ok(data);
  }

  static Future<RepoResult<Map<String, dynamic>>> syncMidtransPaymentStatus({
    required String midtransOrderId,
  }) async {
    final res = await ApiService.post('api/midtrans', {
      'action': 'sync_status',
      'midtrans_order_id': midtransOrderId,
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal mengecek status Midtrans');
    }

    _billingCache = null;
    final data = res.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const RepoResult.fail('Response status Midtrans tidak valid');
    }

    return RepoResult.ok(data);
  }

  static Future<RepoResult<List<Order>>> getOrders() async {
    final res = await ApiService.get('api/user_orders');

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat pesanan');
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list);
    } catch (e) {
      return RepoResult.fail('Gagal membaca pesanan: $e');
    }
  }

  static Future<RepoResult<Order>> createOrder({
    required UserMerchant merchant,
    required List<MerchantMenuItem> items,
    required String deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    required String estimatedTime,
    required String paymentMethod,
    int? subscriptionDays,
    Map<String, int>? quantities,
    List<String> addonIds = const [],
    String? customerName,
    String? customerPhone,
    String? notes,
  }) async {
    final res = await ApiService.post('api/user_orders', {
      'merchantId':
          merchant.merchantId.isNotEmpty ? merchant.merchantId : merchant.id,
      'service': merchant.type,
      'deliveryAddress': deliveryAddress,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'estimatedTime': estimatedTime,
      'paymentMethod': paymentMethod,
      if (subscriptionDays != null) 'subscriptionDays': subscriptionDays,
      'customerName': customerName ?? '',
      'customerPhone': customerPhone ?? '',
      'notes': notes ?? '',
      if (merchant.type == 'laundry' && addonIds.isNotEmpty)
        'addonIds': addonIds,
      'items': items
          .map((item) => {
                'productId': item.id,
                'name': item.name,
                'quantity': quantities?[item.id] ?? 1,
                'price': item.price,
              })
          .toList(),
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal membuat pesanan');
    }

    try {
      return RepoResult.ok(
        Order.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (_) {
      return const RepoResult.fail('Gagal membaca pesanan yang dibuat');
    }
  }

  static Future<RepoResult<Order>> getOrderDetail(String id) async {
    final res = await ApiService.get(
      'api/user_orders',
      queryParams: {'id': id},
    );
    if (res.success && res.data != null) {
      try {
        return RepoResult.ok(
          Order.fromJson(res.data!['data'] as Map<String, dynamic>),
        );
      } catch (_) {}
    }

    if (res.statusCode != 404) {
      return RepoResult.fail(res.message ?? 'Gagal memuat pesanan');
    }

    final result = await getOrders();
    if (!result.isSuccess) {
      return RepoResult.fail(result.error ?? 'Gagal memuat pesanan');
    }
    for (final order in result.data ?? <Order>[]) {
      if (order.id == id || order.databaseId == id) {
        return RepoResult.ok(order);
      }
    }
    return const RepoResult.fail('Pesanan tidak ditemukan');
  }

  static Future<RepoResult<Order>> cancelOrder(String orderId) async {
    final res = await ApiService.put('api/user_orders', {
      'id': orderId,
      'action': 'cancel_order',
    });
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal membatalkan pesanan');
    }
    try {
      return RepoResult.ok(
        Order.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (_) {
      return const RepoResult.fail('Gagal membaca status pesanan');
    }
  }

  static Future<RepoResult<bool>> submitLaundryIssueReport({
    required String orderId,
    required String serviceName,
    required String reason,
    String? photoUrl,
  }) async {
    return submitMerchantIssueReport(
      orderId: orderId,
      serviceType: 'laundry',
      serviceName: serviceName,
      reason: reason,
      photoUrl: photoUrl,
    );
  }

  static Future<RepoResult<bool>> submitMerchantIssueReport({
    required String orderId,
    required String serviceType,
    required String serviceName,
    required String reason,
    String? photoUrl,
    List<String> photoUrls = const [],
  }) async {
    final res = await ApiService.post('api/merchant_issue_reports', {
      'orderId': orderId,
      'serviceType': serviceType,
      'serviceName': serviceName,
      'reason': reason,
      'photoUrl': photoUrl ?? '',
      if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
    });

    if (!res.success) {
      return RepoResult.fail(
        res.message ?? 'Gagal mengirim pengaduan merchant',
      );
    }
    return const RepoResult.ok(true);
  }

  static Future<RepoResult<List<CateringSubscriber>>> getCateringSubscriptions({
    String status = 'all',
  }) async {
    final res = await ApiService.get(
      'api/catering_subscribers',
      queryParams: {'status': status},
    );
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat langganan');
    }
    try {
      final list = (res.data!['data'] as List)
          .map((e) => CateringSubscriber.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list);
    } catch (e) {
      return RepoResult.fail('Gagal membaca langganan: $e');
    }
  }

  static Future<RepoResult<Map<String, dynamic>>> getTransactionReceipt(
    String orderId,
  ) async {
    final res = await ApiService.post('api/transaction_receipts', {
      'orderId': orderId,
    });
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat struk');
    }
    try {
      return RepoResult.ok(res.data!['data'] as Map<String, dynamic>);
    } catch (e) {
      return RepoResult.fail('Format struk tidak valid: $e');
    }
  }

  static Future<RepoResult<Order>> confirmMerchantPayment(
      String orderId) async {
    final res = await ApiService.put('api/user_orders', {
      'id': orderId,
      'action': 'confirm_payment',
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal mengonfirmasi pembayaran');
    }

    try {
      return RepoResult.ok(
        Order.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (_) {
      return const RepoResult.fail('Gagal membaca status pesanan terbaru');
    }
  }

  static Future<RepoResult<Order>> cancelCateringSubscription(
      String orderId) async {
    final res = await ApiService.put('api/user_orders', {
      'id': orderId,
      'action': 'cancel_subscription',
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal membatalkan langganan');
    }

    try {
      return RepoResult.ok(
        Order.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (_) {
      return const RepoResult.fail('Gagal membaca status langganan terbaru');
    }
  }

  static Future<RepoResult<List<AppNotification>>> getNotifications({
    bool allowFallback = true,
    int limit = 30,
  }) async {
    final res = await ApiService.get(
      'api/user_notifications',
      queryParams: {'limit': limit.toString()},
    );

    if (!res.success) {
      return allowFallback
          ? RepoResult.ok(_fallbackNotifications())
          : RepoResult.fail(res.message ?? 'Gagal memuat notifikasi');
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(
          list.isEmpty && allowFallback ? _fallbackNotifications() : list);
    } catch (_) {
      return allowFallback
          ? RepoResult.ok(_fallbackNotifications())
          : const RepoResult.fail('Gagal membaca notifikasi');
    }
  }

  static Future<RepoResult<bool>> markNotificationRead(String id) async {
    final res = await ApiService.put('api/user_notifications', {
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
    final res = await ApiService.put('api/user_notifications', {
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
      'api/user_notifications',
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

  static Future<RepoResult<bool>> updateNotificationPresence({
    required bool isActive,
    String? fcmToken,
    String platform = 'flutter',
  }) async {
    final payload = <String, dynamic>{
      'isActive': isActive,
      'platform': platform,
      if (fcmToken != null && fcmToken.trim().isNotEmpty)
        'fcmToken': fcmToken.trim(),
    };
    final res =
        await ApiService.post('api/user_notification_presence', payload);
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memperbarui notifikasi');
    }
    return const RepoResult.ok(true);
  }

  static Future<RepoResult<UserProfile>> getProfile({
    required String displayName,
    required String email,
    required String role,
    bool forceRefresh = false,
  }) async {
    final cached = _profileCache;
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) < _profileCacheTtl) {
      return RepoResult.ok(cached.profile);
    }

    final res = await ApiService.get('api/user_profile');

    if (!res.success) {
      return RepoResult.ok(await _mergeLocalProfile(UserProfile(
        id: '',
        email: email,
        displayName: displayName,
        role: role,
      )));
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      final profile = await _mergeLocalProfile(UserProfile.fromJson(data));
      _profileCache = _ProfileCacheEntry(profile, DateTime.now());
      return RepoResult.ok(profile);
    } catch (_) {
      return RepoResult.ok(await _mergeLocalProfile(UserProfile(
        id: '',
        email: email,
        displayName: displayName,
        role: role,
      )));
    }
  }

  static Future<RepoResult<UserProfile>> connectKosCode(
    String accessCode, [
    String? roomNumber,
    bool confirmStopPreviousRent = false,
  ]) async {
    final payload = {
      'accessCode': accessCode,
      if (roomNumber != null && roomNumber.isNotEmpty) 'roomNumber': roomNumber,
      'confirmStopPreviousRent': confirmStopPreviousRent,
    };
    final res = await ApiService.post('api/user_profile', payload);

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menyambungkan kode kos');
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      final profile = UserProfile.fromJson(data);
      await _saveLocalProfile(profile);
      _profileCache = _ProfileCacheEntry(profile, DateTime.now());
      _dashboardCache = null;
      _merchantListCache.clear();
      _merchantDetailCache.clear();
      requestProfileRefresh();
      return RepoResult.ok(profile);
    } catch (_) {
      return const RepoResult.fail('Gagal membaca data profil terbaru');
    }
  }

  static Future<RepoResult<UserProfile>> updateProfile({
    required String displayName,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    String? photoUrl,
    String? ktpPhoto,
  }) async {
    final res = await ApiService.put('api/user_profile', {
      'displayName': displayName.trim(),
      'phone': phone?.trim() ?? '',
      'address': address?.trim() ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'photoUrl': photoUrl?.trim() ?? '',
      'ktpPhoto': ktpPhoto?.trim() ?? '',
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memperbarui profil');
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      final profile = UserProfile.fromJson(data);
      await _saveLocalProfile(profile);
      _profileCache = _ProfileCacheEntry(profile, DateTime.now());
      _dashboardCache = null;
      requestProfileRefresh();
      return RepoResult.ok(profile);
    } catch (_) {
      return const RepoResult.fail('Gagal membaca data profil terbaru');
    }
  }

  static Future<RepoResult<bool>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await ApiService.post('api/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal mengubah kata sandi');
    }

    return const RepoResult.ok(true);
  }

  static Future<Set<String>> getFavoriteMerchantKeys() async {
    final cachedAt = _favoriteKeysCachedAt;
    final cached = _favoriteKeysCache;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _favoriteKeysCacheTtl) {
      return Set<String>.of(cached);
    }

    final res = await ApiService.get('api/user_favorite_merchants');
    if (res.success) {
      try {
        final data = res.data!['data'] as Map<String, dynamic>;
        final keys = (data['keys'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toSet();
        await _saveFavoriteMerchantKeys(keys);
        return keys;
      } catch (_) {
        // Fall through to local cache.
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final keys =
        (prefs.getStringList(_favoriteMerchantsKey) ?? const []).toSet();
    _favoriteKeysCache = Set<String>.of(keys);
    _favoriteKeysCachedAt = DateTime.now();
    _notifyFavoriteChanged();
    return keys;
  }

  static Future<bool> isMerchantFavorite({
    required String type,
    required String merchantId,
  }) async {
    final keys = await getFavoriteMerchantKeys();
    return keys.contains(_merchantKey(type, merchantId));
  }

  static Future<bool> toggleMerchantFavorite(UserMerchant merchant) async {
    final merchantId =
        merchant.merchantId.isNotEmpty ? merchant.merchantId : merchant.id;
    final res = await ApiService.post('api/user_favorite_merchants', {
      'merchantId': merchantId,
      'type': merchant.type,
      'action': 'toggle',
    });

    if (res.success) {
      try {
        final data = res.data!['data'] as Map<String, dynamic>;
        final favorite = data['favorite'] == true;
        final keys = (data['keys'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toSet();
        await _saveFavoriteMerchantKeys(keys);
        return favorite;
      } catch (_) {
        // Fall through to local cache.
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final keys =
        (prefs.getStringList(_favoriteMerchantsKey) ?? const []).toSet();
    final key = _merchantKey(merchant.type, merchantId);
    final next = !keys.contains(key);
    if (next) {
      keys.add(key);
    } else {
      keys.remove(key);
    }
    await prefs.setStringList(_favoriteMerchantsKey, keys.toList()..sort());
    _favoriteKeysCache = Set<String>.of(keys);
    _favoriteKeysCachedAt = DateTime.now();
    _notifyFavoriteChanged();
    return next;
  }

  static Future<RepoResult<List<UserMerchant>>> getFavoriteMerchants() async {
    final keys = await getFavoriteMerchantKeys();
    if (keys.isEmpty) return const RepoResult.ok([]);

    final items = <UserMerchant>[];
    for (final type in {'laundry', 'catering'}) {
      final result = await getMerchants(type);
      final merchants = result.data ?? const <UserMerchant>[];
      items.addAll(
        merchants.where(
            (merchant) => keys.contains(_merchantKey(type, merchant.id))),
      );
    }
    return RepoResult.ok(items);
  }

  static Future<void> _saveFavoriteMerchantKeys(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteMerchantsKey, keys.toList()..sort());
    _favoriteKeysCache = Set<String>.of(keys);
    _favoriteKeysCachedAt = DateTime.now();
    _notifyFavoriteChanged();
  }

  static Future<UserProfile> _mergeLocalProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKeyFor(profile));
    if (raw == null || raw.isEmpty) return profile;

    try {
      final local =
          UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return profile.copyWith(
        displayName: local.displayName.isNotEmpty ? local.displayName : null,
        phone: local.phone,
        address: local.address,
        latitude: local.latitude,
        longitude: local.longitude,
        photoUrl: local.photoUrl,
        ktpPhoto: local.ktpPhoto,
        activeRentHistory: profile.activeRentHistory,
      );
    } catch (_) {
      return profile;
    }
  }

  static Future<void> _saveLocalProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _profileKeyFor(profile), jsonEncode(profile.toJson()));
  }

  static String _profileKeyFor(UserProfile profile) {
    final owner = profile.id.isNotEmpty ? profile.id : profile.email;
    return '$_profileKey:$owner';
  }

  static Future<List<BillingRecord>> _applyLocalBillingStatuses(
    List<BillingRecord> billings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_billingStatusKey);
    if (raw == null || raw.isEmpty) return billings;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return billings.map((billing) {
        final local = map[billing.id] as Map<String, dynamic>?;
        if (local == null || billing.status == 'lunas') return billing;
        return billing.copyWith(
          status: local['status'] as String?,
          paymentMethod: local['paymentMethod'] as String?,
          paymentDate: DateTime.tryParse(local['paymentDate'] as String? ?? ''),
        );
      }).toList();
    } catch (_) {
      return billings;
    }
  }

  static String _merchantKey(String type, String merchantId) =>
      '$type:$merchantId';

  static List<UserMerchant> _dedupeMerchants(List<UserMerchant> merchants) {
    final seen = <String>{};
    final unique = <UserMerchant>[];
    for (final merchant in merchants) {
      final key = merchant.merchantId.isNotEmpty
          ? merchant.merchantId
          : (merchant.id.isNotEmpty ? merchant.id : merchant.placeId);
      if (key.isEmpty || seen.add('${merchant.type}:$key')) {
        unique.add(merchant);
      }
    }
    return unique;
  }

  static Future<RepoResult<UserMerchantReviewState>> getMerchantReviewState({
    required String type,
    required String merchantId,
  }) async {
    final res = await ApiService.get(
      'api/user_ratings',
      queryParams: {'type': type, 'merchantId': merchantId},
    );

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat data ulasan');
    }

    try {
      return RepoResult.ok(
        UserMerchantReviewState.fromJson(
          res.data!['data'] as Map<String, dynamic>,
        ),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca data ulasan: $e');
    }
  }

  static Future<RepoResult<Order>> extendCateringSubscription(
    String orderId, {
    required int days,
  }) async {
    final res = await ApiService.put('api/user_orders', {
      'id': orderId,
      'action': 'extend_subscription',
      'days': days,
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memperpanjang langganan');
    }

    try {
      return RepoResult.ok(
        Order.fromJson(res.data!['data'] as Map<String, dynamic>),
      );
    } catch (_) {
      return const RepoResult.fail('Gagal membaca status langganan terbaru');
    }
  }

  static Future<RepoResult<UserMerchantReviewState>> submitMerchantRating({
    required String type,
    required String merchantId,
    required String productId,
    required int rating,
    required String comment,
    bool update = false,
  }) async {
    final payload = {
      'type': type,
      'merchantId': merchantId,
      'productId': productId,
      'rating': rating,
      'comment': comment,
    };
    final res = update
        ? await ApiService.put('api/user_ratings', payload)
        : await ApiService.post('api/user_ratings', payload);

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal mengirim ulasan');
    }

    try {
      return RepoResult.ok(
        UserMerchantReviewState.fromJson(
          res.data!['data'] as Map<String, dynamic>,
        ),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca data ulasan: $e');
    }
  }

  static Future<RepoResult<UserMerchantReviewState>> deleteMerchantRating({
    required String type,
    required String merchantId,
    required String productId,
  }) async {
    final res = await ApiService.delete(
      'api/user_ratings',
      queryParams: {
        'type': type,
        'merchantId': merchantId,
        'productId': productId,
      },
    );

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal menghapus ulasan');
    }

    try {
      return RepoResult.ok(
        UserMerchantReviewState.fromJson(
          res.data!['data'] as Map<String, dynamic>,
        ),
      );
    } catch (e) {
      return RepoResult.fail('Gagal membaca data ulasan: $e');
    }
  }

  static List<AppNotification> _fallbackNotifications() {
    return [
      AppNotification(
        id: 'notif-1',
        title: 'Pembayaran Laundry Berhasil',
        message:
            'Pembayaran untuk layanan laundry #L-9928 senilai Rp 45.000 telah kami terima. Pakaian Anda sedang diproses.',
        type: 'payment',
        status: 'baru',
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
      AppNotification(
        id: 'notif-2',
        title: 'Pesanan Catering Gagal',
        message:
            'Maaf, pesanan katering untuk makan siang hari ini dibatalkan karena ketersediaan menu. Saldo Anda telah dikembalikan.',
        type: 'catering',
        status: 'dibaca',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'notif-3',
        title: 'Tagihan Kos Menunggu',
        message:
            'Masa sewa kamar Anda akan berakhir dalam 3 hari. Segera lakukan pembayaran untuk bulan depan.',
        type: 'room',
        status: 'dibaca',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        hasAction: true,
        actionButtonText: 'Bayar Sekarang',
      ),
      AppNotification(
        id: 'notif-4',
        title: 'Promo Khusus Member',
        message:
            'Dapatkan diskon 20% untuk layanan cleaning service setiap akhir pekan selama bulan ini.',
        type: 'promo',
        status: 'dibaca',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }
}

class _MerchantListCacheEntry {
  const _MerchantListCacheEntry(this.items, this.createdAt);

  final List<UserMerchant> items;
  final DateTime createdAt;
}

class _DashboardCacheEntry {
  const _DashboardCacheEntry(this.dashboard, this.createdAt);

  final UserDashboard dashboard;
  final DateTime createdAt;
}

class _MerchantDetailCacheEntry {
  const _MerchantDetailCacheEntry(this.item, this.createdAt);

  final UserMerchant item;
  final DateTime createdAt;
}

class _ProfileCacheEntry {
  const _ProfileCacheEntry(this.profile, this.createdAt);

  final UserProfile profile;
  final DateTime createdAt;
}

class _BillingCacheEntry {
  const _BillingCacheEntry(this.items, this.createdAt);

  final List<BillingRecord> items;
  final DateTime createdAt;
}
