import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/payment_methods.dart';
import '../../core/realtime_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/order.dart';
import '../user/order_detail_page.dart';

/// Helper untuk format currency
String formatCurrency(double amount) {
  return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  )}';
}

/// Helper untuk format date
String formatDate(DateTime date) {
  const months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Helper untuk format datetime dengan jam
String formatDateTime(DateTime date) {
  const months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} ${date.year} $hour:$minute';
}

/// Halaman daftar pesanan/orders user
class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  List<Order> _orders = [];
  bool _isLoading = true;
  String _filterService = 'semua';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    RealtimeService().startUserOrderPolling();
    RealtimeService().addEventListener('order_status_updated', _loadOrders);
  }

  @override
  void dispose() {
    RealtimeService().removeEventListener('order_status_updated', _loadOrders);
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    final result = await UserRepository.getOrders();
    if (!mounted) return;
    setState(() {
      _orders = (result.data ?? [])
          .where((order) => order.service == 'laundry' || order.service == 'catering')
          .toList();
      _error = result.error;
      _isLoading = false;
    });
  }

  List<Order> get _filteredOrders {
    if (_filterService == 'semua') return _orders;
    return _orders.where((o) => o.service == _filterService).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Semua',
                        selected: _filterService == 'semua',
                        onSelected: () =>
                            setState(() => _filterService = 'semua'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Catering',
                        selected: _filterService == 'catering',
                        onSelected: () =>
                            setState(() => _filterService = 'catering'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Laundry',
                        selected: _filterService == 'laundry',
                        onSelected: () =>
                            setState(() => _filterService = 'laundry'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                ],
                // Daftar orders
                if (_filteredOrders.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Tidak ada pesanan untuk layanan ini',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  ..._filteredOrders.map((order) {
                    return _OrderCard(order: order);
                  }),
              ],
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primaryGreen,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  Color _getStatusColor() {
    if (order.readyToPay) return const Color(0xFF1475C8);
    if (order.awaitingWeighing) return Colors.orange;
    switch (order.status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getServiceIcon() {
    switch (order.service) {
      case 'catering':
        return Icons.restaurant;
      case 'laundry':
        return Icons.local_laundry_service;
      case 'kos':
        return Icons.apartment;
      default:
        return Icons.shopping_bag;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          _showOrderDetail(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.id,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.merchantName,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (order.readyToPay) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Total ${formatCurrency(order.totalAmount)} siap dibayar — tap untuk bayar',
                    style: const TextStyle(
                      color: Color(0xFF00508F),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (order.isLaundry &&
                  (order.serviceEstimateLabel ?? order.estimatedTime ?? '')
                      .isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Estimasi layanan: ${order.serviceEstimateLabel ?? order.estimatedTime}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(_getServiceIcon(),
                      size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 4),
                  Text(
                    order.service.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    formatDate(order.orderDate),
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 12),
              if ((order.paymentMethodLabel ?? order.paymentMethod ?? '')
                  .isNotEmpty) ...[
                Text(
                  order.paymentMethodLabel ??
                      PaymentMethodHelper.getDisplayName(order.paymentMethod),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.awaitingWeighing ? 'Total (ditimbang)' : 'Total',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    order.awaitingWeighing && order.totalAmount <= 0
                        ? 'Menunggu'
                        : formatCurrency(order.totalAmount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserOrderDetailPage(order: order),
      ),
    );
  }
}
