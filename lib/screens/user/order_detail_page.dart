import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/user_repository.dart';
import '../../models/order.dart';
import 'user_theme.dart';
import 'user_widgets.dart';

class UserOrderDetailPage extends StatefulWidget {
  const UserOrderDetailPage({super.key, required this.order});

  final Order order;

  @override
  State<UserOrderDetailPage> createState() => _UserOrderDetailPageState();
}

class _UserOrderDetailPageState extends State<UserOrderDetailPage> {
  late Order _order;
  Timer? _refreshTimer;
  bool _confirmingPayment = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshOrder(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshOrder() async {
    final id = _order.databaseId ?? _order.id;
    final result = await UserRepository.getOrderDetail(id);
    if (!mounted || result.data == null) return;
    setState(() => _order = result.data!);
  }

  Future<void> _confirmPayment() async {
    final id = _order.databaseId ?? _order.id;
    setState(() => _confirmingPayment = true);
    final result = await UserRepository.confirmMerchantPayment(id);
    if (!mounted) return;
    setState(() {
      _confirmingPayment = false;
      if (result.data != null) _order = result.data!;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Konfirmasi pembayaran dikirim ke merchant'
              : result.error ?? 'Gagal mengonfirmasi pembayaran',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
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
            children: [
              Text(
                'Alamat tujuan',
                style: TextStyle(
                  color: UserTheme.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                order.deliveryAddress ??
                    'Kos Sentra Ruang, Kamar S302\nJl. Melati No. 45, Jakarta Selatan',
                style: const TextStyle(color: UserTheme.muted, height: 1.35),
              ),
              if ((order.estimatedTime ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Estimasi: ${order.estimatedTime}',
                  style: const TextStyle(
                    color: UserTheme.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
                  Expanded(
                    child: Text(
                      order.needsPaymentConfirmation
                          ? 'Konfirmasi setelah pembayaran dilakukan'
                          : 'Pembayaran tercatat di sistem pesanan',
                      style: const TextStyle(color: UserTheme.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (order.needsPaymentConfirmation)
            FilledButton(
              onPressed: _confirmingPayment ? null : _confirmPayment,
              style: FilledButton.styleFrom(
                backgroundColor: UserTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(
                _confirmingPayment ? 'Mengirim...' : 'Saya Sudah Bayar',
              ),
            )
          else
            _PaymentStatusNotice(order: order),
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
          if (order.canCancel)
            TextButton(
              onPressed: () {},
              child: const Text(
                'Batalkan Pesanan',
                style: TextStyle(
                  color: UserTheme.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Paket catering aktif tidak dapat dibatalkan sampai periode berjalan selesai.',
                textAlign: TextAlign.center,
                style: TextStyle(color: UserTheme.muted, fontSize: 12),
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
      child: Column(
        children: [
          Row(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6DF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFFD88A)),
                ),
                child: Text(
                  order.statusLabel.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFB55B00),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _OrderProgressBar(status: order.status),
        ],
      ),
    );
  }
}

class _OrderProgressBar extends StatelessWidget {
  const _OrderProgressBar({required this.status});

  final String status;

  static const _steps = [
    ('pending', 'Menunggu'),
    ('confirmed', 'Diterima'),
    ('in_progress', 'Diproses'),
    ('completed', 'Selesai'),
  ];

  int get _currentIndex {
    switch (status) {
      case 'confirmed':
        return 1;
      case 'in_progress':
        return 2;
      case 'completed':
        return 3;
      case 'cancelled':
        return -1;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex;
    return Column(
      children: [
        Row(
          children: List.generate(_steps.length, (index) {
            final active = current >= index;
            return Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(right: index == _steps.length - 1 ? 0 : 6),
                decoration: BoxDecoration(
                  color: active ? UserTheme.primary : const Color(0xFFE3E9F3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: _steps.map((step) {
            final index = _steps.indexOf(step);
            final active = current >= index;
            return Expanded(
              child: Text(
                step.$2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? UserTheme.primaryDark : UserTheme.muted,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final subtotal =
        order.items.fold<double>(0, (sum, item) => sum + item.subtotal);
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

class _PaymentStatusNotice extends StatelessWidget {
  const _PaymentStatusNotice({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final label = order.paymentStatusLabel?.trim().isNotEmpty == true
        ? order.paymentStatusLabel!
        : 'Pembayaran tercatat';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFD2EAFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: UserTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: UserTheme.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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
