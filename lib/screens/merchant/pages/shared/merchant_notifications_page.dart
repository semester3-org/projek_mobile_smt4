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
    return _items.where((item) {
      switch (_filter) {
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
                  selectedIndex:
                      _filters.indexWhere((item) => item.$1 == _filter),
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
  });

  final MerchantNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = item.isUnread;
    final icon = _iconFor(item);
    final title = _displayTitle(item.title);
    final message = _displayMessage(item.message);
    return MerchantCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    unread ? MerchantPalette.softBlue : const Color(0xFFF0F2F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: MerchantPalette.primary),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MerchantPalette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
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

  IconData? _iconFor(MerchantNotification item) {
    final type = item.type;
    final text = '${item.type} ${item.title} ${item.message}'.toLowerCase();
    if (type == 'promo' || text.contains('promo') || text.contains('diskon')) {
      return Icons.local_offer_outlined;
    }
    if (text.contains('laundry') && text.contains('selesai')) {
      return Icons.task_alt_rounded;
    }
    if (type == 'order' ||
        text.contains('pesanan baru') ||
        text.contains('pesanan dibuat') ||
        text.contains('menunggu konfirmasi')) {
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
    if (type == 'review') {
      return Icons.star_outline_rounded;
    }
    return null;
  }

  String _displayTitle(String title) {
    return title
        .replaceAll('Total laundry sudah ditetapkan',
            'Total pembayaran telah ditentukan')
        .replaceAll(
            'Total laundry ditetapkan', 'Total pembayaran telah ditentukan');
  }

  String _displayMessage(String message) {
    return message
        .replaceAll('Total laundry sudah ditetapkan',
            'Total pembayaran laundry telah ditentukan.')
        .replaceAll('siap dibayar', 'siap untuk dibayar');
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
