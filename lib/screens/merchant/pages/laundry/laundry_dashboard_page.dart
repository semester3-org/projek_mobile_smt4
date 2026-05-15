import 'package:flutter/material.dart';

import '../../../../auth/auth_scope.dart';
import '../../merchant_ui.dart';
import '../shared/merchant_notifications_page.dart';

class LaundryDashboardPage extends StatelessWidget {
  const LaundryDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final displayName = AuthScope.of(context).session?.displayName.trim() ?? '';
    final merchantName = displayName.isEmpty ? 'Laundry Jaya' : displayName;

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
        MerchantMetricCard(
          title: 'TOTAL PESANAN',
          value: '42',
          trailing: MerchantStatusPill(
            label: '+12%',
            color: MerchantPalette.success,
            background: MerchantPalette.success.withValues(alpha: 0.13),
          ),
        ),
        const SizedBox(height: 12),
        const MerchantCard(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              Icon(
                Icons.local_laundry_service_outlined,
                color: MerchantPalette.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pesanan sedang dicuci: 8 Pesanan',
                  style: TextStyle(
                    color: MerchantPalette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Row(
          children: [
            Expanded(
              child: MerchantMetricCard(
                title: 'PRODUK AKTIF',
                value: '15',
                subtitle: 'Item',
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: MerchantMetricCard(
                title: 'PROMO BERJALAN',
                value: '3',
                subtitle: 'LIVE',
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const MerchantPromoBanner(
          title: 'Tingkatkan Penjualan dengan Promo Kilat!',
        ),
        const SizedBox(height: 30),
        const MerchantSectionHeader(
          title: 'Pesanan Terbaru',
          actionLabel: 'Lihat Semua',
        ),
        const SizedBox(height: 10),
        const _RecentLaundryOrderCard(
          orderId: '#ORD-29384',
          title: 'Cuci Kiloan Reguler',
          meta: '2kg - Baru saja - Rp 14.000',
          status: 'DICUCI',
          color: MerchantPalette.warning,
        ),
        const SizedBox(height: 14),
        const _RecentLaundryOrderCard(
          orderId: '#ORD-29381',
          title: 'Cuci Sepatu Premium',
          meta: '1 psg - 15 menit yang lalu - Rp 45.000',
          status: 'SELESAI',
          color: MerchantPalette.success,
        ),
        const SizedBox(height: 14),
        const _RecentLaundryOrderCard(
          orderId: '#ORD-29378',
          title: 'Cuci Karpet',
          meta: '12m2 - 1 jam yang lalu - Rp 120.000',
          status: 'PENGIRIMAN',
          color: Color(0xFF1D4ED8),
        ),
        const MerchantBottomSpacer(),
      ],
    );
  }
}

class _RecentLaundryOrderCard extends StatelessWidget {
  const _RecentLaundryOrderCard({
    required this.orderId,
    required this.title,
    required this.meta,
    required this.status,
    required this.color,
  });

  final String orderId;
  final String title;
  final String meta;
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
            child: const Icon(
              Icons.local_laundry_service_outlined,
              color: MerchantPalette.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderId,
                  style: const TextStyle(
                    color: MerchantPalette.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    color: MerchantPalette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  maxLines: 2,
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
