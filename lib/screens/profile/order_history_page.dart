import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/order.dart';

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

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    // TODO: Integrasikan dengan API backend untuk fetch orders
    // Contoh dummy data:
    try {
      setState(() {
        _orders = [
          Order(
            id: 'SR-CATER-88219',
            merchantName: 'Dapur Nusantara',
            service: 'catering',
            orderDate: DateTime(2023, 10, 24, 14, 20),
            deliveryDate: DateTime(2023, 10, 24, 18, 0),
            totalAmount: 90000,
            status: 'confirmed',
            items: [
              OrderItem(
                name: 'Nasi Goreng Spesial Nusantara',
                quantity: 2,
                price: 35000,
                subtotal: 70000,
              ),
              OrderItem(
                name: 'Es Jeruk Peras Murni',
                quantity: 1,
                price: 15000,
                subtotal: 15000,
              ),
            ],
            paymentMethod: 'GOPAY',
          ),
          Order(
            id: 'SR-LAUNDRY-001',
            merchantName: 'Clean & Fresh Laundry Express',
            service: 'laundry',
            orderDate: DateTime(2023, 10, 20),
            deliveryDate: DateTime(2023, 10, 22),
            totalAmount: 70000,
            status: 'completed',
            items: [
              OrderItem(
                name: 'Cuci Lipat (Regular)',
                quantity: 5,
                price: 8000,
                subtotal: 40000,
              ),
              OrderItem(
                name: 'Cuci Setrika (Kg)',
                quantity: 1,
                price: 12000,
                subtotal: 12000,
              ),
            ],
            paymentMethod: 'GOPAY',
          ),
          Order(
            id: 'SR-CAFE-456',
            merchantName: 'Kopi Senja',
            service: 'cafe',
            orderDate: DateTime(2023, 10, 15),
            totalAmount: 45000,
            status: 'completed',
            items: [
              OrderItem(
                name: 'Cappuccino',
                quantity: 2,
                price: 18000,
                subtotal: 36000,
              ),
              OrderItem(
                name: 'Croissant',
                quantity: 1,
                price: 9000,
                subtotal: 9000,
              ),
            ],
            paymentMethod: 'Kartu Kredit',
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Kafe',
                        selected: _filterService == 'cafe',
                        onSelected: () =>
                            setState(() => _filterService = 'cafe'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                  }).toList(),
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
      case 'cafe':
        return Icons.coffee;
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(_getServiceIcon(),
                      size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 4),
                  Text(
                    order.service.toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    formatCurrency(order.totalAmount),
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
    showModalBottomSheet(
      context: context,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Detail Pesanan',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'ID Pesanan',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(order.id, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Text(
                'Waktu Pesanan',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formatDateTime(order.orderDate),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Item Pesanan',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ...order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name),
                            Text(
                              '${item.quantity}x @ ${formatCurrency(item.price)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatCurrency(item.subtotal),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total'),
                  Text(
                    formatCurrency(order.totalAmount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                          fontSize: 16,
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
}
