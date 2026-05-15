import 'package:flutter/material.dart';

import '../../../../auth/auth_scope.dart';
import '../../merchant_ui.dart';
import '../shared/merchant_notifications_page.dart';

class CateringDashboardPage extends StatelessWidget {
  const CateringDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final displayName = AuthScope.of(context).session?.displayName.trim() ?? '';
    final merchantName = displayName.isEmpty ? 'Sentra Catering' : displayName;

    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'MerchantHub',
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MerchantNotificationsPage(),
          ),
        ),
      ),
      children: [
        Text(
          'Halo, $merchantName!',
          style: const TextStyle(
            color: MerchantPalette.text,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Berikut performa bisnismu hari ini.',
          style: TextStyle(
            color: MerchantPalette.muted,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 28),
        MerchantCard(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: MerchantPalette.primary,
                    size: 18,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Total Pesanan',
                    style: TextStyle(
                      color: MerchantPalette.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    '42',
                    style: TextStyle(
                      color: MerchantPalette.text,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  MerchantStatusPill(
                    label: '+12%',
                    color: MerchantPalette.success,
                    background: MerchantPalette.success.withValues(alpha: 0.13),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pesanan sedang diproses',
                      style: TextStyle(
                        color: MerchantPalette.muted,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '8 Pesanan',
                    style: TextStyle(
                      color: MerchantPalette.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Row(
          children: [
            Expanded(
              child: MerchantMetricCard(
                title: 'Produk Aktif',
                value: '128',
                icon: Icons.inventory_2_outlined,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: MerchantMetricCard(
                title: 'Promo Berjalan',
                value: '3',
                icon: Icons.local_offer_outlined,
                subtitle: 'LIVE',
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const MerchantPromoBanner(
          title: 'Tingkatkan Penjualan dengan Promo Flash!',
        ),
        const SizedBox(height: 30),
        const MerchantSectionHeader(
          title: 'Pesanan Terbaru',
          actionLabel: 'Lihat Semua',
        ),
        const SizedBox(height: 10),
        const _RecentCateringOrderCard(
          orderId: '#ORD-29384',
          title: '2x Paket Nasi Box Ayam Bakar',
          meta: 'Baru saja - Rp 75.000',
          icon: Icons.lunch_dining_outlined,
          status: 'DIPROSES',
          color: MerchantPalette.warning,
        ),
        const SizedBox(height: 14),
        const _RecentCateringOrderCard(
          orderId: '#ORD-29381',
          title: '5x Snack Box Premium',
          meta: '15 menit yang lalu - Rp 125.000',
          icon: Icons.bakery_dining_outlined,
          status: 'SELESAI',
          color: MerchantPalette.success,
        ),
        const SizedBox(height: 14),
        const _RecentCateringOrderCard(
          orderId: '#ORD-29378',
          title: '1x Catering Harian (3 Hari)',
          meta: '1 jam yang lalu - Rp 450.000',
          icon: Icons.ramen_dining_outlined,
          status: 'PENGIRIMAN',
          color: Color(0xFF1D4ED8),
        ),
        const MerchantBottomSpacer(),
      ],
    );
  }
}

class _RecentCateringOrderCard extends StatelessWidget {
  const _RecentCateringOrderCard({
    required this.orderId,
    required this.title,
    required this.meta,
    required this.icon,
    required this.status,
    required this.color,
  });

  final String orderId;
  final String title;
  final String meta;
  final IconData icon;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: MerchantPalette.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderId,
                  style: const TextStyle(
                    color: MerchantPalette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPalette.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: MerchantPalette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MerchantStatusPill(label: status, color: color),
        ],
      ),
    );
  }
}
