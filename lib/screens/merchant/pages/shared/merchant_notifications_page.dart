import 'package:flutter/material.dart';

import '../../merchant_ui.dart';

class MerchantNotificationsPage extends StatelessWidget {
  const MerchantNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'Notifikasi',
        showAvatar: false,
        showBack: true,
        actionIcon: Icons.done_all_rounded,
        onAction: () {},
      ),
      children: const [
        _NotificationTile(
          icon: Icons.receipt_long_outlined,
          title: 'Pesanan baru menunggu verifikasi',
          message: '#ORD-202394 sudah mengirim bukti pembayaran.',
          time: 'Baru saja',
          unread: true,
        ),
        SizedBox(height: 14),
        _NotificationTile(
          icon: Icons.local_offer_outlined,
          title: 'Promo Diskon Kilat aktif',
          message: 'Promo sudah tampil di aplikasi pelanggan.',
          time: '20 menit lalu',
        ),
        SizedBox(height: 14),
        _NotificationTile(
          icon: Icons.star_outline_rounded,
          title: 'Ulasan baru diterima',
          message: 'Andi memberi rating 5 untuk layanan Anda.',
          time: '1 jam lalu',
        ),
        MerchantBottomSpacer(),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    this.unread = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String time;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
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
            child: Icon(icon, color: MerchantPalette.primary),
          ),
          const SizedBox(width: 14),
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
                  time,
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
}
