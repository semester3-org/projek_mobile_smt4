import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/user_repository.dart';
import '../../models/notification.dart';
import '../../models/order.dart';
import '../user/merchant_detail_page.dart';
import '../user/order_detail_page.dart';
import '../user/user_theme.dart';
import '../user/user_widgets.dart';
import 'billing_detail_page.dart';
import 'billing_list_page.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String _filter = 'semua';
  Timer? _clockTimer;
  StreamSubscription<void>? _notificationSubscription;
  bool _loadingNotifications = false;
  DateTime? _lastLoadedAt;

  static const _filters = [
    ('semua', 'Semua'),
    ('belum_dibaca', 'Belum Dibaca'),
    ('dibaca', 'Sudah Dibaca'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _notificationSubscription =
        UserRepository.notificationCountChanges.listen((_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final now = DateTime.now();
    if (silent &&
        _lastLoadedAt != null &&
        now.difference(_lastLoadedAt!) < const Duration(seconds: 2)) {
      return;
    }
    if (_loadingNotifications) return;
    _loadingNotifications = true;
    try {
      if (!silent) setState(() => _loading = true);
      final result = await UserRepository.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = result.data ?? [];
        _loading = false;
      });
      _lastLoadedAt = DateTime.now();
    } finally {
      _loadingNotifications = false;
    }
  }

  Future<void> _markAllRead() async {
    await UserRepository.markAllNotificationsRead();
    if (!mounted) return;
    setState(() {
      _notifications = _notifications.map((notification) {
        return notification.copyWith(status: 'dibaca');
      }).toList();
    });
  }

  Future<void> _handleAction(AppNotification notification) async {
    unawaited(UserRepository.markNotificationRead(notification.id));
    if (mounted) {
      setState(() {
        _notifications = _notifications
            .map((item) => item.id == notification.id
                ? item.copyWith(status: 'dibaca')
                : item)
            .toList();
      });
    }
    if (!mounted) return;

    final actionUrl = notification.actionUrl ?? '';
    if (actionUrl.startsWith('billing:')) {
      await _openBillingById(actionUrl.substring('billing:'.length));
      return;
    }

    if (notification.type == 'room' ||
        _looksLikeBillingNotification(notification)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BillingListPage()),
      );
      return;
    }

    if (actionUrl.startsWith('order:')) {
      _openOrderDetailById(actionUrl.substring('order:'.length));
      return;
    }

    if (actionUrl.startsWith('merchant:') || actionUrl.startsWith('promo:')) {
      final prefix = actionUrl.startsWith('promo:') ? 'promo:' : 'merchant:';
      await _openMerchantById(actionUrl.substring(prefix.length));
      return;
    }

    final service =
        notification.type == 'payment' ? 'laundry' : notification.type;
    if (service == 'laundry' || service == 'catering' || service == 'order') {
      _openOrderDetail(service == 'order' ? null : service);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(notification.title)),
    );
  }

  bool _looksLikeBillingNotification(AppNotification notification) {
    final text =
        '${notification.type} ${notification.title} ${notification.message}'
            .toLowerCase();
    return text.contains('tagihan') ||
        text.contains('sewa') ||
        text.contains('kos') ||
        text.contains('kamar');
  }

  Future<void> _openBillingById(String id) async {
    final result = await UserRepository.getBillings();
    if (!mounted) return;

    final matches =
        result.data?.where((billing) => billing.id == id).toList() ?? const [];
    if (matches.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BillingDetailPage(
            billing: matches.first,
            actionsEnabled: false,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BillingListPage()),
    );
  }

  Future<void> _openOrderDetail(String? service) async {
    final result = await UserRepository.getOrders();
    if (!mounted) return;

    Order? selected;
    for (final order in result.data ?? <Order>[]) {
      if (service == null || order.service == service) {
        selected = order;
        break;
      }
    }

    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail pesanan belum tersedia')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserOrderDetailPage(order: selected!),
      ),
    );
  }

  Future<void> _openOrderDetailById(String id) async {
    final result = await UserRepository.getOrderDetail(id);
    if (!mounted) return;

    final order = result.data;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.error ?? 'Detail pesanan belum tersedia')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserOrderDetailPage(order: order),
      ),
    );
  }

  Future<void> _openMerchantById(String merchantId) async {
    var result = await UserRepository.getMerchantDetail(
      type: 'laundry',
      id: merchantId,
    );
    if (result.data == null) {
      result = await UserRepository.getMerchantDetail(
        type: 'catering',
        id: merchantId,
      );
    }

    if (mounted && result.data != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MerchantDetailPage(merchant: result.data!),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toko tidak ditemukan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleNotifications = _visibleNotifications;
    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            color: UserTheme.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text(
              'Tandai semua dibaca',
              style: TextStyle(
                color: UserTheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: UserTheme.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((filter) {
                        return UserFilterChip(
                          label: filter.$2,
                          selected: _filter == filter.$1,
                          onTap: () => setState(() => _filter = filter.$1),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (visibleNotifications.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Belum ada notifikasi.',
                          style: TextStyle(color: UserTheme.muted),
                        ),
                      ),
                    )
                  else
                    ...visibleNotifications.map(
                      (notification) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _NotificationCard(
                          notification: notification,
                          onTap: () => _handleAction(notification),
                        ),
                      ),
                    ),
                  const UserBottomSpacer(),
                ],
              ),
      ),
    );
  }

  List<AppNotification> get _visibleNotifications {
    return _notifications.where((notification) {
      switch (_filter) {
        case 'belum_dibaca':
          return notification.isUnread;
        case 'dibaca':
          return !notification.isUnread;
        default:
          return true;
      }
    }).toList();
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNew = notification.isNew;
    final icon = _typeIcon(notification);
    final title = _displayTitle(notification);
    final message = _displayMessage(notification);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [UserTheme.softShadow(opacity: 0.05)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.black),
              ),
              const SizedBox(width: 18),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: UserTheme.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _relativeTime(notification.createdAt),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isNew
                              ? UserTheme.primary
                              : const Color(0xFF91A1BD),
                          fontSize: 12,
                          fontWeight: isNew ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: UserTheme.muted,
                      height: 1.42,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData? _typeIcon(AppNotification notification) {
    final type = notification.type;
    final text =
        '${notification.type} ${notification.title} ${notification.message}'
            .toLowerCase();
    if (type == 'promo' || text.contains('promo') || text.contains('diskon')) {
      return Icons.local_offer_outlined;
    }
    if (text.contains('laundry') && text.contains('selesai')) {
      return Icons.task_alt_rounded;
    }
    if (type == 'order' ||
        text.contains('pesanan dibuat') ||
        text.contains('pesanan baru')) {
      return Icons.receipt_long_outlined;
    }
    if (text.contains('status') ||
        text.contains('diproses') ||
        text.contains('diterima') ||
        text.contains('siap diantar')) {
      return Icons.sync_alt_rounded;
    }
    if (type == 'payment' ||
        text.contains('bayar') ||
        text.contains('pembayaran')) {
      return Icons.payments_outlined;
    }
    if (type == 'laundry') {
      return Icons.local_laundry_service_outlined;
    }
    if (type == 'catering') {
      return Icons.restaurant_outlined;
    }
    if (type == 'room') return Icons.account_balance_wallet_outlined;
    return null;
  }

  String _displayTitle(AppNotification notification) {
    final legacyPromoName = _legacyPromoName(notification.message);
    if (notification.type == 'promo' &&
        notification.title.toLowerCase().startsWith('promo baru dari') &&
        legacyPromoName != null) {
      return legacyPromoName;
    }
    return notification.title
        .replaceAll('Total laundry sudah ditetapkan',
            'Total pembayaran telah ditentukan')
        .replaceAll(
            'Total laundry ditetapkan', 'Total pembayaran telah ditentukan');
  }

  String _displayMessage(AppNotification notification) {
    if (notification.type == 'promo') {
      return _displayPromoMessage(notification.message);
    }
    return notification.message
        .replaceAll('Total laundry sudah ditetapkan',
            'Merchant telah menetapkan total pembayaran laundry Anda.')
        .replaceAll('siap dibayar', 'siap untuk dibayar');
  }

  String _displayPromoMessage(String message) {
    final raw = message.trim();
    if (raw.isEmpty) return 'Promo baru tersedia untuk Anda.';

    final lower = raw.toLowerCase();
    if (lower.contains('buka detail merchant')) {
      return raw
          .replaceAll('Buka detail merchant', 'Buka detail promo')
          .replaceAll('buka detail merchant', 'buka detail promo');
    }
    if (lower.contains('sudah aktif. cek produk')) {
      return 'Promo baru tersedia untuk Anda.';
    }
    return raw;
  }

  String? _legacyPromoName(String message) {
    final match = RegExp(r'^(.*?)\s+sudah aktif\.', caseSensitive: false)
        .firstMatch(message);
    final name = match?.group(1)?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  String _relativeTime(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    final diff = DateTime.now().difference(local);
    if (diff.inDays >= 1) return '${diff.inDays} hari lalu';
    if (diff.inHours >= 1) return '${diff.inHours} jam lalu';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} menit lalu';
    return '${diff.inSeconds.clamp(1, 59)} detik lalu';
  }
}
