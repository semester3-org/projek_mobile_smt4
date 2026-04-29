import 'package:flutter/material.dart';

import '../../models/order.dart';
import 'user_theme.dart';
import 'user_widgets.dart';

class UserOrderDetailPage extends StatelessWidget {
  const UserOrderDetailPage({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final serviceIcon = _serviceIcon(order.service);

    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Detail Pesanan',
          style: TextStyle(
            color: UserTheme.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        children: [
          _OrderStatusCard(order: order),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: UserTheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(serviceIcon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _serviceLabel(order.service),
                      style: const TextStyle(
                        color: UserTheme.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      order.merchantName,
                      style: const TextStyle(color: UserTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _OrderItemsCard(order: order),
          const SizedBox(height: 18),
          _InfoCard(
            icon: Icons.local_shipping_outlined,
            title: 'Informasi Pengiriman',
            children: const [
              Text(
                'Budi Setiawan',
                style: TextStyle(
                  color: UserTheme.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Kos Sentra Ruang, Kamar S302\nJl. Melati No. 45, Jakarta Selatan',
                style: TextStyle(color: UserTheme.muted, height: 1.35),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Metode Pembayaran',
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEF8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.paymentMethod ?? 'GOPAY',
                      style: const TextStyle(
                        color: UserTheme.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Saldo Terpotong Otomatis',
                      style: TextStyle(color: UserTheme.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: UserTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text('Bayar Sekarang'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: UserTheme.text,
              side: BorderSide(color: Colors.blueGrey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text('Hubungi Admin'),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              'Batalkan Pesanan',
              style: TextStyle(
                color: UserTheme.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _serviceIcon(String service) {
    switch (service) {
      case 'laundry':
        return Icons.local_laundry_service_rounded;
      case 'catering':
        return Icons.restaurant_rounded;
      case 'cafe':
        return Icons.local_cafe_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  String _serviceLabel(String service) {
    switch (service) {
      case 'laundry':
        return 'Layanan Laundry';
      case 'catering':
        return 'Layanan Catering';
      case 'cafe':
        return 'Pesanan Kafe';
      default:
        return 'Pesanan';
    }
  }
}

class _OrderStatusCard extends StatelessWidget {
  const _OrderStatusCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [UserTheme.softShadow(opacity: 0.05)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ID Pesanan',
                  style: TextStyle(
                    color: UserTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '#${order.id}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: UserTheme.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: UserTheme.muted,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatShortDate(order.orderDate),
                      style: const TextStyle(color: UserTheme.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6DF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFFFD88A)),
            ),
            child: Text(
              order.status.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFB55B00),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final subtotal = order.items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final delivery =
        (order.totalAmount - subtotal).clamp(0, double.infinity).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [UserTheme.softShadow(opacity: 0.05)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Rincian Item',
              style: TextStyle(
                color: UserTheme.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Divider(color: Colors.blueGrey.shade50, height: 1),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: UserTheme.softBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: UserTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: UserTheme.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.quantity} pcs x ${formatUserCurrency(item.price)}',
                                style: const TextStyle(color: UserTheme.muted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatUserCurrency(item.subtotal),
                          style: const TextStyle(
                            color: UserTheme.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(color: Colors.blueGrey.shade100),
                const SizedBox(height: 10),
                _TotalRow(label: 'Subtotal', value: subtotal),
                const SizedBox(height: 10),
                _TotalRow(label: 'Biaya Antar-Jemput', value: delivery),
                const SizedBox(height: 14),
                _TotalRow(
                  label: 'Total Pembayaran',
                  value: order.totalAmount,
                  strong: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? UserTheme.text : UserTheme.muted,
              fontSize: strong ? 16 : 14,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          formatUserCurrency(value),
          style: TextStyle(
            color: strong ? UserTheme.primaryDark : UserTheme.text,
            fontSize: strong ? 18 : 14,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [UserTheme.softShadow(opacity: 0.05)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: UserTheme.primaryDark),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: UserTheme.primaryDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}
