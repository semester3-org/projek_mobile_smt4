import 'package:flutter/material.dart';

import '../../merchant_ui.dart';
import '../shared/merchant_notifications_page.dart';
import '../shared/merchant_order_detail_page.dart';

class CateringOrdersPage extends StatelessWidget {
  const CateringOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
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
        const Text(
          'Daftar Pesanan',
          style: TextStyle(
            color: MerchantPalette.text,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kelola pesanan katering Anda secara real-time.',
          style: TextStyle(
            color: MerchantPalette.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        const MerchantFilterChips(labels: ['Semua', 'Pending', 'Diproses']),
        const SizedBox(height: 24),
        _CateringOrderCard(
          orderId: '#ORD-2023-8812',
          customer: 'Bapak Ahmad Subagjo',
          status: 'Pending',
          statusColor: MerchantPalette.danger,
          menu: 'Paket Prasmanan VIP',
          meta: '50 Porsi - Kirim 12:00 WIB',
          price: 'Rp 7.500.000',
          imageUrl:
              'https://images.unsplash.com/photo-1543353071-873f17a7a088?w=300',
          primaryAction: 'Proses Pesanan',
          onTap: () => _openDetail(context),
        ),
        const SizedBox(height: 18),
        _CateringOrderCard(
          orderId: '#ORD-2023-8811',
          customer: 'Ibu Siska Wijaya',
          status: 'Diproses',
          statusColor: const Color(0xFF1D4ED8),
          menu: 'Nasi Box Premium',
          meta: '25 Porsi - Kirim 10:30 WIB',
          price: 'Rp 1.875.000',
          imageUrl:
              'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=300',
          primaryAction: 'Selesaikan',
          outlinedAction: true,
          onTap: () => _openDetail(context),
        ),
        const SizedBox(height: 18),
        _CateringOrderCard(
          orderId: '#ORD-2023-8810',
          customer: 'PT. Maju Bersama',
          status: 'Selesai',
          statusColor: MerchantPalette.muted,
          menu: 'Coffee Break Set B',
          meta: '100 Porsi - Selesai 09:00 WIB',
          price: 'Rp 4.000.000',
          imageUrl:
              'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=300',
          primaryAction: 'Lihat Invoice',
          disabled: true,
          onTap: () => _openDetail(context),
        ),
        const MerchantBottomSpacer(),
      ],
    );
  }

  static void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MerchantOrderDetailPage(isLaundry: false),
      ),
    );
  }
}

class _CateringOrderCard extends StatelessWidget {
  const _CateringOrderCard({
    required this.orderId,
    required this.customer,
    required this.status,
    required this.statusColor,
    required this.menu,
    required this.meta,
    required this.price,
    required this.imageUrl,
    required this.primaryAction,
    required this.onTap,
    this.outlinedAction = false,
    this.disabled = false,
  });

  final String orderId;
  final String customer;
  final String status;
  final Color statusColor;
  final String menu;
  final String meta;
  final String price;
  final String imageUrl;
  final String primaryAction;
  final VoidCallback onTap;
  final bool outlinedAction;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final textColor = disabled ? const Color(0xFF8F96A3) : MerchantPalette.text;
    final mutedColor =
        disabled ? const Color(0xFFA2A9B4) : MerchantPalette.muted;

    return MerchantCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      color: disabled ? Colors.white.withValues(alpha: 0.68) : Colors.white,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  orderId,
                  style: TextStyle(
                    color: disabled
                        ? const Color(0xFF9AA2AE)
                        : MerchantPalette.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              MerchantStatusPill(label: status, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            customer,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.22,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 22),
          Row(
            children: [
              Opacity(
                opacity: disabled ? 0.45 : 1,
                child: MerchantImage(
                  url: imageUrl,
                  icon: Icons.restaurant_rounded,
                  width: 68,
                  height: 68,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      menu,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                price,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: disabled
                      ? const Color(0xFF8F96A3)
                      : MerchantPalette.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onTap,
                  child: const Text(
                    'Detail',
                    style: TextStyle(color: MerchantPalette.muted),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: outlinedAction || disabled
                    ? OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: disabled
                              ? MerchantPalette.muted
                              : MerchantPalette.primary,
                          side: BorderSide(
                            color: disabled
                                ? Colors.transparent
                                : MerchantPalette.primary,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(primaryAction),
                      )
                    : FilledButton(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: MerchantPalette.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(primaryAction),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
