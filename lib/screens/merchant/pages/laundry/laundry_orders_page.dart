import 'package:flutter/material.dart';

import '../../merchant_ui.dart';
import '../shared/merchant_notifications_page.dart';
import '../shared/merchant_order_detail_page.dart';

class LaundryOrdersPage extends StatelessWidget {
  const LaundryOrdersPage({super.key});

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
      floatingActionButton: FloatingActionButton(
        backgroundColor: MerchantPalette.primaryLight,
        foregroundColor: Colors.white,
        onPressed: () {},
        child: const Icon(Icons.add_rounded),
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
          'Kelola pesanan laundry harian Anda dengan mudah.',
          style: TextStyle(
            color: MerchantPalette.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        const MerchantSearchField(
          hint: 'Cari nama pelanggan atau layanan...',
        ),
        const SizedBox(height: 28),
        const MerchantFilterChips(labels: ['Semua', 'Pending', 'Diproses']),
        const SizedBox(height: 28),
        _LaundryOrderCard(
          orderId: '#ORD-202401',
          customer: 'Budi Santoso',
          status: 'Pending',
          statusColor: MerchantPalette.danger,
          lines: const [
            _OrderInfoLine(
              icon: Icons.inventory_2_outlined,
              text: 'Cuci Lipat 5kg + Pewangi Premium',
            ),
            _OrderInfoLine(
              icon: Icons.schedule_rounded,
              text: 'Estimasi: Hari ini, 16:00',
            ),
          ],
          price: 'Rp 45.000',
          actionLabel: 'Proses',
          onTap: () => _openDetail(context),
        ),
        const SizedBox(height: 22),
        _LaundryOrderCard(
          orderId: '#ORD-202405',
          customer: 'Siti Aminah',
          status: 'Diproses',
          statusColor: const Color(0xFF1D4ED8),
          lines: const [
            _OrderInfoLine(
              icon: Icons.dry_cleaning_outlined,
              text: 'Cuci Setrika 10kg (Express)',
            ),
            _OrderInfoLine(
              icon: Icons.local_shipping_outlined,
              text: 'Antar ke: Jl. Melati No. 12',
            ),
          ],
          price: 'Rp 120.000',
          actionLabel: 'Detail',
          outlinedAction: true,
          onTap: () => _openDetail(context),
        ),
        const SizedBox(height: 22),
        _LaundryOrderCard(
          orderId: '#ORD-202398',
          customer: 'Andi Wijaya',
          status: 'Selesai',
          statusColor: MerchantPalette.muted,
          lines: const [
            _OrderInfoLine(
              icon: Icons.check_circle_outline_rounded,
              text: 'Cuci Karpet (Besar) x 2',
            ),
            _OrderInfoLine(
              icon: Icons.payments_outlined,
              text: 'Metode: QRIS - Paid',
            ),
          ],
          price: 'Rp 150.000',
          actionLabel: '',
          disabled: true,
          onTap: () => _openDetail(context),
        ),
        const SizedBox(height: 22),
        _LaundryOrderCard(
          orderId: '#ORD-202409',
          customer: 'Rina Pratama',
          status: 'Pending',
          statusColor: MerchantPalette.danger,
          lines: const [
            _OrderInfoLine(
              icon: Icons.bed_outlined,
              text: 'Bed Cover King Size',
            ),
            _OrderInfoLine(
              icon: Icons.local_shipping_outlined,
              text: 'Pick-up Request',
            ),
          ],
          price: 'Rp 65.000',
          actionLabel: 'Terima',
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
        builder: (_) => const MerchantOrderDetailPage(isLaundry: true),
      ),
    );
  }
}

class _LaundryOrderCard extends StatelessWidget {
  const _LaundryOrderCard({
    required this.orderId,
    required this.customer,
    required this.status,
    required this.statusColor,
    required this.lines,
    required this.price,
    required this.actionLabel,
    required this.onTap,
    this.outlinedAction = false,
    this.disabled = false,
  });

  final String orderId;
  final String customer;
  final String status;
  final Color statusColor;
  final List<_OrderInfoLine> lines;
  final String price;
  final String actionLabel;
  final VoidCallback onTap;
  final bool outlinedAction;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final contentColor = disabled ? const Color(0xFF8F96A3) : null;

    return MerchantCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      color: disabled ? Colors.white.withValues(alpha: 0.74) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  orderId,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: disabled
                        ? const Color(0xFF9AA2AE)
                        : MerchantPalette.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              MerchantStatusPill(label: status, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            customer,
            style: TextStyle(
              color: contentColor ?? MerchantPalette.text,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          for (final line in lines) ...[
            line.copyWith(color: contentColor),
            const SizedBox(height: 12),
          ],
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  price,
                  style: TextStyle(
                    color: disabled
                        ? const Color(0xFF7C8796)
                        : MerchantPalette.primary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (actionLabel.isNotEmpty)
                outlinedAction
                    ? OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MerchantPalette.primary,
                          side: const BorderSide(
                            color: MerchantPalette.primary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(actionLabel),
                      )
                    : FilledButton(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: MerchantPalette.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(actionLabel),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderInfoLine extends StatelessWidget {
  const _OrderInfoLine({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  _OrderInfoLine copyWith({Color? color}) {
    return _OrderInfoLine(
      icon: icon,
      text: text,
      color: color ?? this.color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? MerchantPalette.muted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: MerchantPalette.primary, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
