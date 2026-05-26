import 'package:flutter/material.dart';

import '../../../../auth/auth_scope.dart';
import '../../../../auth/roles.dart';
import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/merchant_models.dart';
import '../../merchant_ui.dart';
import 'merchant_order_detail_page.dart';

class MerchantNotificationsPage extends StatefulWidget {
  const MerchantNotificationsPage({super.key});

  @override
  State<MerchantNotificationsPage> createState() =>
      _MerchantNotificationsPageState();
}

class _MerchantNotificationsPageState extends State<MerchantNotificationsPage> {
  List<MerchantNotification> _items = [];
  bool _loading = true;
  String? _error;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await MerchantRepository.getNotifications();
    if (!mounted) return;
    setState(() {
      _items = result.data ?? [];
      _error = result.error;
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    await MerchantRepository.markAllNotificationsRead();
    if (!mounted) return;
    setState(() {
      _items = _items
          .map((item) => MerchantNotification(
                id: item.id,
                title: item.title,
                message: item.message,
                type: item.type,
                status: 'dibaca',
                createdAt: item.createdAt,
                actionUrl: item.actionUrl,
                actionButtonText: item.actionButtonText,
              ))
          .toList();
    });
  }

  Future<void> _openNotification(MerchantNotification item) async {
    await MerchantRepository.markNotificationRead(item.id);
    if (!mounted) return;
    setState(() {
      _items = _items
          .map((current) => current.id == item.id
              ? MerchantNotification(
                  id: current.id,
                  title: current.title,
                  message: current.message,
                  type: current.type,
                  status: 'dibaca',
                  createdAt: current.createdAt,
                  actionUrl: current.actionUrl,
                  actionButtonText: current.actionButtonText,
                )
              : current)
          .toList();
    });

    final orderId = item.orderIdFromAction;
    if (orderId == null || orderId.isEmpty) return;

    await _openOrderDetail(orderId);
    _load();
  }

  Future<void> _openOrderDetail(String orderId) async {
    final merchantType = AuthScope.of(context).session?.merchantType;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MerchantOrderDetailPage(
          isLaundry: merchantType != MerchantType.catering,
          orderId: orderId,
        ),
      ),
    );
  }

  List<MerchantNotification> get _visibleItems {
    final now = DateTime.now();
    return _items.where((item) {
      switch (_filter) {
        case 'baru':
          return now.difference(item.createdAt).inHours < 24;
        case 'belum_dibaca':
          return item.isUnread;
        case 'dibaca':
          return !item.isUnread;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;
    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'Notifikasi',
        showAvatar: false,
        showBack: true,
        actionIcon: Icons.refresh_rounded,
        onAction: _load,
      ),
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 120),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          MerchantCard(
            child: Text(
              _error!,
              style: const TextStyle(color: MerchantPalette.danger),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: MerchantFilterChips(
                  labels: _filters.map((item) => item.$2).toList(),
                  selectedIndex: _filters.indexWhere((item) => item.$1 == _filter),
                  onSelected: (index) =>
                      setState(() => _filter = _filters[index].$1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Baca semuanya'),
            ),
          ),
          const SizedBox(height: 8),
          if (visibleItems.isEmpty)
          const MerchantCard(
            child: Text(
              'Belum ada notifikasi.',
              style: TextStyle(color: MerchantPalette.muted),
            ),
          )
          else
          ...visibleItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _NotificationTile(
                item: item,
                onTap: () => _openNotification(item),
                onOpenOrder: item.orderIdFromAction == null
                    ? null
                    : () => _openOrderDetail(item.orderIdFromAction!),
              ),
            ),
          ),
        ],
        const MerchantBottomSpacer(),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    this.onOpenOrder,
  });

  final MerchantNotification item;
  final VoidCallback onTap;
  final VoidCallback? onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final unread = item.status == 'baru';
    return MerchantCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  unread ? MerchantPalette.softBlue : const Color(0xFFF0F2F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconFor(item.type), color: MerchantPalette.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: MerchantPalette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.message,
                  style: const TextStyle(
                    color: MerchantPalette.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _timeLabel(item.createdAt),
                  style: const TextStyle(
                    color: MerchantPalette.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (onOpenOrder != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onOpenOrder,
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('Lihat Detail Pesanan'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (unread)
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: MerchantPalette.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'payment':
        return Icons.payments_outlined;
      case 'promo':
        return Icons.local_offer_outlined;
      case 'review':
        return Icons.star_outline_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String _timeLabel(DateTime time) {
    final local = time.isUtc ? time.toLocal() : time;
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return '${diff.inSeconds.clamp(1, 59)} detik lalu';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}
