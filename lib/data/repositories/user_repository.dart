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
  static const Duration _merchantListCacheTtl = Duration(seconds: 25);
  static final Map<String, _MerchantListCacheEntry> _merchantListCache = {};

  static final StreamController<void> _profileRefreshController =
      StreamController<void>.broadcast();

  static Stream<void> get profileRefreshRequests =>
      _profileRefreshController.stream;

  static void requestProfileRefresh() {
    if (!_profileRefreshController.isClosed) {
      _profileRefreshController.add(null);
    }
  }

  static Future<RepoResult<UserDashboard>> getDashboard({
    required String displayName,
  }) async {
    final res = await ApiService.get('api/user_dashboard');

    if (!res.success) {
      return RepoResult.ok(UserDashboard.fallback(displayName));
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      return RepoResult.ok(UserDashboard.fromJson(data));
    } catch (_) {
      return RepoResult.ok(UserDashboard.fallback(displayName));
    }
  }

  static Future<RepoResult<List<UserMerchant>>> getMerchants(
    String type, {
    double? latitude,
    double? longitude,
  }) async {
    final cacheKey = _merchantListCacheKey(type, latitude, longitude);
    final cached = _merchantListCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _merchantListCacheTtl) {
      return RepoResult.ok(List<UserMerchant>.of(cached.items));
    }

    final params = {'type': type};
    if (latitude != null && longitude != null) {
      params['lat'] = latitude.toString();
      params['lng'] = longitude.toString();
    }
    final res = await ApiService.get(
      'api/user_merchants',
      queryParams: params,
    );

    if (!res.success) {
      return RepoResult.ok(_fallbackMerchants(type));
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => UserMerchant.fromJson(e as Map<String, dynamic>))
          .toList();
      final unique = _dedupeMerchants(list);
      final items = unique.isEmpty ? _fallbackMerchants(type) : unique;
      _merchantListCache[cacheKey] = _MerchantListCacheEntry(
        List<UserMerchant>.of(items),
        DateTime.now(),
      );
      return RepoResult.ok(items);
    } catch (_) {
      return RepoResult.ok(_fallbackMerchants(type));
    }
  }

  static Future<RepoResult<UserMerchant>> getMerchantDetail({
    required String type,
    required String id,
    double? latitude,
    double? longitude,
  }) async {
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
      return RepoResult.ok(_fallbackMerchants(type).first);
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      return RepoResult.ok(UserMerchant.fromJson(data));
    } catch (_) {
      return RepoResult.ok(_fallbackMerchants(type).first);
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

  static Future<RepoResult<List<BillingRecord>>> getBillings() async {
    final res = await ApiService.get('api/user_billings');

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memuat tagihan');
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => BillingRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(await _applyLocalBillingStatuses(list));
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

    final data = res.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const RepoResult.fail('Response status Midtrans tidak valid');
    }

    return RepoResult.ok(data);
  }

  static Future<RepoResult<List<Order>>> getOrders() async {
    final res = await ApiService.get('api/user_orders');

    if (!res.success) {
      return RepoResult.ok(_fallbackOrders());
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list.isEmpty ? _fallbackOrders() : list);
    } catch (_) {
      return RepoResult.ok(_fallbackOrders());
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

  static Future<RepoResult<List<AppNotification>>> getNotifications() async {
    final res = await ApiService.get('api/user_notifications');

    if (!res.success) {
      return RepoResult.ok(_fallbackNotifications());
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      return RepoResult.ok(list.isEmpty ? _fallbackNotifications() : list);
    } catch (_) {
      return RepoResult.ok(_fallbackNotifications());
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
    return const RepoResult.ok(true);
  }

  static Future<RepoResult<bool>> markAllNotificationsRead() async {
    final res = await ApiService.put('api/user_notifications', {
      'action': 'mark_all_read',
    });
    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal membaca semua notifikasi');
    }
    return const RepoResult.ok(true);
  }

  static Future<bool> hasUnreadNotifications() async {
    final result = await getNotifications();
    return (result.data ?? const <AppNotification>[])
        .any((notification) => notification.isUnread);
  }

  static Future<RepoResult<UserProfile>> getProfile({
    required String displayName,
    required String email,
    required String role,
  }) async {
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
      return RepoResult.ok(
          await _mergeLocalProfile(UserProfile.fromJson(data)));
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
  }) async {
    final res = await ApiService.put('api/user_profile', {
      'displayName': displayName.trim(),
      'phone': phone?.trim() ?? '',
      'address': address?.trim() ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'photoUrl': photoUrl?.trim() ?? '',
    });

    if (!res.success) {
      return RepoResult.fail(res.message ?? 'Gagal memperbarui profil');
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      final profile = UserProfile.fromJson(data);
      await _saveLocalProfile(profile);
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
    return (prefs.getStringList(_favoriteMerchantsKey) ?? const []).toSet();
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

  static List<UserMerchant> _fallbackMerchants(String type) {
    switch (type) {
      case 'laundry':
        return const [
          UserMerchant(
            id: 'l1',
            type: 'laundry',
            name: 'Clean & Fresh Laundry',
            subtitle: 'Antar jemput dan express 6 jam',
            address: 'Jl. Sudirman No. 45, Jakarta Pusat',
            rating: 4.8,
            reviewCount: 120,
            distanceKm: 0.8,
            imageUrl:
                'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?w=900',
            status: 'Tersedia',
            tags: ['ANTAR JEMPUT', 'EXPRESS 6 JAM'],
            minPrice: 8000,
            priceUnit: '/kg',
            eta: '25-30 mnt',
            openHours: '08:00 - 21:00',
            description:
                'Laundry cepat dengan layanan cuci lipat, setrika, satuan, dan antar jemput area Sentra Ruang.',
            phone: '+62 812-3456-7890',
            email: 'halo@cleanfresh.id',
            menuItems: [
              MerchantMenuItem(
                id: 'l1-s1',
                name: 'Cuci Lipat (Kg)',
                description: 'Regular',
                price: 8000,
                imageUrl:
                    'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=400',
              ),
              MerchantMenuItem(
                id: 'l1-s2',
                name: 'Cuci Setrika (Kg)',
                description: 'Rapi dan wangi',
                price: 12000,
                imageUrl:
                    'https://images.unsplash.com/photo-1521656693074-0ef32e80a5d5?w=400',
              ),
            ],
            reviews: [
              MerchantReview(
                reviewer: 'Siska Amelia',
                rating: 5,
                comment:
                    'Hasil cucian sangat bersih dan wangi. Pengirimannya juga cepat, kurirnya ramah.',
                timeLabel: '2 hari yang lalu',
              ),
              MerchantReview(
                reviewer: 'Budi Santoso',
                rating: 4,
                comment:
                    'Layanan oke, lipatan rapi sekali. Secara keseluruhan puas dengan hasilnya.',
                timeLabel: '1 minggu yang lalu',
              ),
            ],
          ),
          UserMerchant(
            id: 'l2',
            type: 'laundry',
            name: 'Kiloan Express',
            subtitle: 'Cuci sepatu dan kiloan cepat',
            address: 'Jl. Melati No. 18, Jakarta Selatan',
            rating: 4.5,
            reviewCount: 80,
            distanceKm: 1.2,
            imageUrl:
                'https://images.unsplash.com/photo-1626806819282-2c1dc01a5e0c?w=900',
            status: 'Tersedia',
            tags: ['CUCI SEPATU', 'KILOAN'],
            minPrice: 7500,
            priceUnit: '/kg',
            eta: '35-45 mnt',
            openHours: '07:00 - 22:00',
            description:
                'Pilihan praktis untuk cuci kiloan, sepatu, dan perawatan pakaian harian.',
            phone: '+62 812-1111-2244',
            email: 'cs@kiloanexpress.id',
            menuItems: [],
            reviews: [],
          ),
        ];
      case 'catering':
        return const [
          UserMerchant(
            id: 'cat1',
            type: 'catering',
            name: 'Green Garden Catering',
            subtitle: 'Masakan sehat dan diet kalori',
            address: 'Jl. Kemang Raya No. 9, Jakarta Selatan',
            rating: 4.8,
            reviewCount: 124,
            distanceKm: 1.2,
            imageUrl:
                'https://images.unsplash.com/photo-1543353071-873f17a7a088?w=900',
            status: 'Tersedia',
            tags: ['DIET SEHAT', 'HARIAN'],
            minPrice: 25000,
            priceUnit: '',
            eta: '25-30 mnt',
            openHours: '08:00 - 20:00',
            description:
                'Menu harian bergizi untuk penghuni kos, cocok untuk makan siang dan makan malam.',
            phone: '+62 812-4455-7788',
            email: 'order@greengarden.id',
            menuItems: [
              MerchantMenuItem(
                id: 'cat1-m1',
                name: 'Paket Nasi Kotak Premium',
                description: 'Lengkap dengan 5 lauk pauk',
                price: 45000,
                imageUrl:
                    'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=400',
              ),
              MerchantMenuItem(
                id: 'cat1-m2',
                name: 'Catering Diet Sehat',
                description: 'Rendah kalori, tinggi protein',
                price: 55000,
                imageUrl:
                    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400',
              ),
            ],
            reviews: [
              MerchantReview(
                reviewer: 'Anita Wijaya',
                rating: 5,
                comment:
                    'Makanannya enak dan porsinya pas. Kemasan juga sangat rapi.',
                timeLabel: '2 jam yang lalu',
              ),
              MerchantReview(
                reviewer: 'Budi Santoso',
                rating: 4.5,
                comment:
                    'Pengirimannya tepat waktu. Menu catering dietnya membantu pola makan.',
                timeLabel: 'Kemarin',
              ),
            ],
          ),
          UserMerchant(
            id: 'cat2',
            type: 'catering',
            name: 'Dapur Nusantara',
            subtitle: 'Masakan tradisional Indonesia',
            address: 'Jl. Panglima Polim No. 11',
            rating: 4.9,
            reviewCount: 210,
            distanceKm: 2.5,
            imageUrl:
                'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=900',
            status: 'Tersedia',
            tags: ['NASI BOX', 'PRASMANAN'],
            minPrice: 35000,
            priceUnit: '',
            eta: '35-45 mnt',
            openHours: '07:00 - 21:00',
            description: 'Menu nusantara untuk kebutuhan harian dan acara kos.',
            phone: '+62 812-9988-1010',
            email: 'dapur@nusantara.id',
            menuItems: [],
            reviews: [],
          ),
        ];
      default:
        return const [];
    }
  }

  static List<Order> _fallbackOrders() {
    return [
      Order(
        id: 'SR-CATER-88219',
        merchantName: 'Dapur Nusantara',
        service: 'catering',
        orderDate: DateTime(2023, 10, 24, 14, 20),
        totalAmount: 90000,
        status: 'pending',
        paymentMethod: 'GOPAY',
        items: [
          OrderItem(
            name: 'Nasi Goreng Spesial Nusantara',
            quantity: 2,
            price: 35000,
            subtotal: 70000,
          ),
          OrderItem(
            name: 'Es Jeruk Peras Murni',
            quantity: 1,
            price: 15000,
            subtotal: 15000,
          ),
        ],
      ),
      Order(
        id: 'SR-LAUNDRY-001',
        merchantName: 'Clean & Fresh Laundry Express',
        service: 'laundry',
        orderDate: DateTime(2023, 10, 24, 14, 20),
        totalAmount: 70000,
        status: 'pending',
        paymentMethod: 'GOPAY',
        items: [
          OrderItem(
            name: 'Cuci Lipat (Regular)',
            quantity: 5,
            price: 8000,
            subtotal: 40000,
          ),
          OrderItem(
            name: 'Cuci Satuan - Jaket',
            quantity: 1,
            price: 25000,
            subtotal: 25000,
          ),
        ],
      ),
    ];
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
