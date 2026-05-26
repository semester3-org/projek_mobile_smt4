import 'package:flutter/material.dart';

import '../../data/repositories/user_repository.dart';
import '../../models/notification.dart';
import '../../models/order.dart';
import '../user/order_detail_page.dart';
import '../user/user_theme.dart';
import '../user/user_widgets.dart';
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

  static const _filters = [
    ('semua', 'Semua'),
    ('baru', 'Baru Masuk'),
    ('belum_dibaca', 'Belum Dibaca'),
    ('dibaca', 'Sudah Dibaca'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await UserRepository.getNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = result.data ?? [];
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    await UserRepository.markAllNotificationsRead();
    if (!mounted) return;
    setState(() {
      _notifications = _notifications.map((notification) {
        return notification.copyWith(
          status: 'dibaca',
          hasAction:
              notification.hasAction || _hasImplicitAction(notification.type),
          actionButtonText:
              notification.actionButtonText ?? _actionText(notification.type),
        );
      }).toList();
    });
  }

  Future<void> _handleAction(AppNotification notification) async {
    await UserRepository.markNotificationRead(notification.id);
    if (mounted) {
      setState(() {
        _notifications = _notifications
            .map((item) =>
                item.id == notification.id ? item.copyWith(status: 'dibaca') : item)
            .toList();
      });
    }

    if (notification.type == 'room') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BillingListPage()),
      );
      return;
    }

    final actionUrl = notification.actionUrl ?? '';
    if (actionUrl.startsWith('order:')) {
      _openOrderDetailById(actionUrl.substring('order:'.length));
      return;
    }

    final service = notification.type == 'payment' ? 'laundry' : notification.type;
    if (service == 'laundry' || service == 'catering' || service == 'order') {
      _openOrderDetail(service == 'order' ? null : service);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(notification.title)),
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
        SnackBar(content: Text(result.error ?? 'Detail pesanan belum tersedia')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserOrderDetailPage(order: order),
      ),
    );
  }

  bool _hasImplicitAction(String type) {
    return type == 'payment' ||
        type == 'laundry' ||
        type == 'catering' ||
        type == 'order';
  }

  String? _actionText(String type) {
    if (_hasImplicitAction(type)) return 'Lihat Detail';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final visibleNotifications = _visibleNotifications;
    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 20,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: UserTheme.softBlue,
              child: Icon(Icons.person, color: UserTheme.primary),
            ),
            SizedBox(width: 12),
            Text(
              'Sentra Ruang',
              style: TextStyle(
                color: UserTheme.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
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
                  Row(
                    children: [
                      Text(
                        'Notifikasi',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: UserTheme.text,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const Spacer(),
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
                    ],
                  ),
                  const SizedBox(height: 12),
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
                          notification: _withAction(notification),
                          onAction: () => _handleAction(notification),
                        ),
                      ),
                    ),
                  const UserBottomSpacer(),
                ],
              ),
      ),
    );
  }

  AppNotification _withAction(AppNotification notification) {
    return notification.copyWith(
      hasAction: notification.hasAction || _hasImplicitAction(notification.type),
      actionButtonText:
          notification.actionButtonText ?? _actionText(notification.type),
    );
  }

  List<AppNotification> get _visibleNotifications {
    final now = DateTime.now();
    return _notifications.where((notification) {
      switch (_filter) {
        case 'baru':
          return now.difference(notification.createdAt).inHours < 24;
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
    required this.onAction,
  });

  final AppNotification notification;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(notification.type);
    final isNew = notification.isNew;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [UserTheme.softShadow(opacity: 0.05)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_typeIcon(notification.type), color: color),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
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
                        fontWeight:
                            isNew ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  notification.message,
                  style: const TextStyle(
                    color: UserTheme.muted,
                    height: 1.42,
                  ),
                ),
                if (notification.hasAction) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: UserTheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(notification.actionButtonText ?? 'Lihat'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'payment':
        return UserTheme.success;
      case 'catering':
        return const Color(0xFFFF3B30);
      case 'laundry':
        return const Color(0xFF8A3FFC);
      case 'order':
        return UserTheme.primaryDark;
      case 'room':
        return UserTheme.primary;
      case 'promo':
        return const Color(0xFFE58500);
      default:
        return UserTheme.muted;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'payment':
        return Icons.check_circle_outline_rounded;
      case 'catering':
        return Icons.error_outline_rounded;
      case 'laundry':
        return Icons.local_laundry_service_outlined;
      case 'order':
        return Icons.receipt_long_outlined;
      case 'room':
        return Icons.info_outline_rounded;
      case 'promo':
        return Icons.local_offer_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _relativeTime(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    final diff = DateTime.now().difference(local);
    if (diff.inDays >= 1) return '${diff.inDays} hari lalu';
    if (diff.inHours >= 1) return '${diff.inHours} jam lalu';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} menit lalu';
    return 'Baru saja';
  }
}
