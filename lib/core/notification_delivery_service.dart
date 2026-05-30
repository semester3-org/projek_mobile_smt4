import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/roles.dart';
import '../data/repositories/user_repository.dart';
import '../models/notification.dart';
import '../screens/merchant/pages/shared/merchant_notifications_page.dart';
import '../screens/merchant/pages/shared/merchant_order_detail_page.dart';
import '../screens/profile/notification_list_page.dart';
import '../screens/user/merchant_detail_page.dart';
import '../screens/user/order_detail_page.dart';
import 'app_navigator.dart';

class NotificationDeliveryService with WidgetsBindingObserver {
  NotificationDeliveryService._();

  static final NotificationDeliveryService instance =
      NotificationDeliveryService._();

  Timer? _pollTimer;
  Timer? _presenceTimer;
  Timer? _bannerTimer;
  bool _running = false;
  bool _foreground = true;
  bool _seededNotifications = false;
  bool _polling = false;
  bool _syncingPresence = false;
  bool? _queuedPresence;
  UserRole _role = UserRole.user;
  MerchantType? _merchantType;
  String? _fcmToken;
  final Set<String> _knownNotificationIds = <String>{};
  final Set<String> _alertedNotificationIds = <String>{};

  String? get fcmToken => _fcmToken;

  void start({
    UserRole role = UserRole.user,
    MerchantType? merchantType,
  }) {
    _role = role;
    _merchantType = merchantType;
    if (_running) return;
    _running = true;
    _foreground = true;
    _seededNotifications = false;
    WidgetsBinding.instance.addObserver(this);
    _sendPresence(true);
    _pollNotifications();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 18),
      (_) => _pollNotifications(),
    );
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _sendPresence(_foreground),
    );
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _pollTimer?.cancel();
    _presenceTimer?.cancel();
    _bannerTimer?.cancel();
    _pollTimer = null;
    _presenceTimer = null;
    _bannerTimer = null;
    _role = UserRole.user;
    _merchantType = null;
    _polling = false;
    _syncingPresence = false;
    WidgetsBinding.instance.removeObserver(this);
    appScaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
    _sendPresence(false);
  }

  Future<void> updateFcmToken(String token) async {
    _fcmToken = token.trim().isEmpty ? null : token.trim();
    if (_running) {
      await _sendPresence(_foreground);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    if (isActive == _foreground) return;
    _foreground = isActive;
    _sendPresence(isActive);
    if (isActive) _pollNotifications();
  }

  Future<void> _sendPresence(bool isActive) async {
    if (_syncingPresence) {
      _queuedPresence = isActive;
      return;
    }
    _syncingPresence = true;
    try {
      final result = await UserRepository.updateNotificationPresence(
        isActive: isActive,
        fcmToken: _fcmToken,
      );
      debugPrint(
        '[FCM] Presence sync ${result.isSuccess ? 'ok' : 'failed'}: '
        'active=$isActive token=${_fcmToken == null ? 'no' : 'yes'}'
        '${result.error == null ? '' : ' error=${result.error}'}',
      );
    } finally {
      _syncingPresence = false;
      final queued = _queuedPresence;
      _queuedPresence = null;
      if (queued != null) {
        unawaited(_sendPresence(queued));
      }
    }
  }

  Future<void> _pollNotifications() async {
    if (!_running || !_foreground) return;
    if (_polling) return;
    _polling = true;

    try {
      final result =
          await UserRepository.getNotifications(allowFallback: false);
      if (!result.isSuccess) return;
      final notifications = result.data ?? const <AppNotification>[];

      if (!_seededNotifications) {
        _knownNotificationIds.addAll(notifications.map((item) => item.id));
        _seededNotifications = true;
        return;
      }

      final newestFirst = notifications.where((item) {
        return item.id.isNotEmpty && !_knownNotificationIds.contains(item.id);
      }).toList();

      _knownNotificationIds.addAll(notifications.map((item) => item.id));

      for (final notification in newestFirst.reversed) {
        if (_shouldShowInAppAlert(notification)) {
          _showInAppAlert(notification);
        }
      }
    } finally {
      _polling = false;
    }
  }

  bool _shouldShowInAppAlert(AppNotification notification) {
    if (_alertedNotificationIds.contains(notification.id)) return false;

    final type = notification.type.toLowerCase();
    if (type == 'payment' || type == 'promo') return true;

    final text =
        '${notification.type} ${notification.title} ${notification.message}'
            .toLowerCase();
    if (type == 'order' || type == 'laundry') {
      return [
        'diterima',
        'total pembayaran',
        'pembayaran berhasil',
        'diverifikasi',
        'diproses',
        'siap diantar',
        'pengiriman',
        'selesai',
      ].any(text.contains);
    }
    return false;
  }

  void _showInAppAlert(AppNotification notification) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    _alertedNotificationIds.add(notification.id);
    _bannerTimer?.cancel();
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFFEAF4FF),
        elevation: 1,
        leading: Icon(
          _iconFor(notification.type),
          color: const Color(0xFF005EA8),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              notification.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              notification.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              _openNotification(notification);
            },
            child: Text(notification.actionButtonText ?? 'Lihat Detail'),
          ),
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
    _bannerTimer = Timer(const Duration(seconds: 5), () {
      messenger.hideCurrentMaterialBanner();
    });
  }

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return Icons.payments_outlined;
      case 'promo':
        return Icons.local_offer_outlined;
      case 'laundry':
      case 'order':
        return Icons.receipt_long_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    await UserRepository.markNotificationRead(notification.id);

    final actionUrl = notification.actionUrl ?? '';
    if (actionUrl.startsWith('order:')) {
      final orderId = actionUrl.substring('order:'.length);
      if (_role == UserRole.merchant) {
        final navigator = appNavigatorKey.currentState;
        if (navigator != null) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => MerchantOrderDetailPage(
                isLaundry: _merchantType != MerchantType.catering,
                orderId: orderId,
              ),
            ),
          );
          return;
        }
      }
      final result = await UserRepository.getOrderDetail(orderId);
      final navigator = appNavigatorKey.currentState;
      if (navigator != null && result.data != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => UserOrderDetailPage(order: result.data!),
          ),
        );
        return;
      }
    }

    if (actionUrl.startsWith('merchant:') || actionUrl.startsWith('promo:')) {
      final prefix = actionUrl.startsWith('promo:') ? 'promo:' : 'merchant:';
      if (await _openMerchant(actionUrl.substring(prefix.length))) {
        return;
      }
    }

    appNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => _role == UserRole.merchant
            ? const MerchantNotificationsPage()
            : const NotificationListPage(),
      ),
    );
  }

  Future<bool> _openMerchant(String merchantId) async {
    var result = await UserRepository.getMerchantDetail(
      type: 'laundry',
      id: merchantId,
    );
    result = result.data != null
        ? result
        : await UserRepository.getMerchantDetail(
            type: 'catering',
            id: merchantId,
          );

    final navigator = appNavigatorKey.currentState;
    if (navigator == null || result.data == null) return false;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => MerchantDetailPage(merchant: result.data!),
      ),
    );
    return true;
  }
}
