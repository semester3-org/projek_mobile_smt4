import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/merchant_models.dart';
import '../../merchant_ui.dart';
import 'merchant_notifications_page.dart';
import 'merchant_order_detail_page.dart';

class MerchantOrdersView extends StatefulWidget {
  const MerchantOrdersView({
    super.key,
    required this.isLaundry,
  });

  final bool isLaundry;

  @override
  State<MerchantOrdersView> createState() => _MerchantOrdersViewState();
}

class _MerchantOrdersViewState extends State<MerchantOrdersView> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<MerchantOrder> _orders = [];
  bool _loading = true;
  String? _error;
  int _selectedFilter = 0;

  static const _filters = ['Semua', 'Pending', 'Diproses', 'Selesai'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await MerchantRepository.getOrders(
      status: _statusParam,
      search: _searchCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _orders = result.data ?? [];
      _error = result.error;
      _loading = false;
    });
  }

  String? get _statusParam {
    switch (_selectedFilter) {
      case 1:
        return 'pending';
      case 2:
        return 'processing';
      case 3:
        return 'done';
      default:
        return null;
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _process(MerchantOrder order) async {
    final result = await MerchantRepository.updateOrder(
      id: order.id,
      nextStatus: true,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isSuccess
            ? 'Pesanan ${order.code} diperbarui'
            : result.error ?? 'Gagal memproses pesanan'),
      ),
    );
    if (result.isSuccess) _load();
  }

  Future<void> _openDetail(MerchantOrder order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MerchantOrderDetailPage(
          isLaundry: widget.isLaundry,
          orderId: order.id,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'MerchantHub',
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MerchantNotificationsPage()),
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
        Text(
          widget.isLaundry
              ? 'Kelola pesanan laundry yang masuk dari user.'
              : 'Kelola pesanan catering yang masuk dari user.',
          style: const TextStyle(
            color: MerchantPalette.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        MerchantSearchField(
          hint: 'Cari kode unik atau nama pemesan...',
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 24),
        MerchantFilterChips(
          labels: _filters,
          selectedIndex: _selectedFilter,
          onSelected: (index) {
            setState(() => _selectedFilter = index);
            _load();
          },
        ),
        const SizedBox(height: 24),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          MerchantCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_error!,
                    style: const TextStyle(color: MerchantPalette.danger)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Muat Ulang')),
              ],
            ),
          )
        else if (_orders.isEmpty)
          const MerchantCard(
            child: Text(
              'Belum ada pesanan untuk filter ini.',
              style: TextStyle(color: MerchantPalette.muted),
            ),
          )
        else
          ..._orders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _MerchantOrderCard(
                order: order,
                onProcess: order.statusGroup == 'done' || !order.canApprove
                    ? null
                    : () => _process(order),
                onDetail: () => _openDetail(order),
              ),
            ),
          ),
        const MerchantBottomSpacer(),
      ],
    );
  }
}

class _MerchantOrderCard extends StatelessWidget {
  const _MerchantOrderCard({
    required this.order,
    required this.onDetail,
    this.onProcess,
  });

  final MerchantOrder order;
  final VoidCallback onDetail;
  final VoidCallback? onProcess;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      onTap: onDetail,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.code,
                  style: const TextStyle(
                    color: MerchantPalette.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              MerchantStatusPill(
                label: order.statusLabel,
                color: _statusColor(order.statusGroup),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.customerName,
            style: const TextStyle(
              color: MerchantPalette.text,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _InfoLine(
            icon: Icons.inventory_2_outlined,
            text: order.serviceName,
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.location_on_outlined,
            text: order.deliveryAddress.isEmpty
                ? 'Alamat belum diisi'
                : order.deliveryAddress,
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.schedule_rounded,
            text: order.estimatedTime.isEmpty
                ? 'Estimasi belum diatur'
                : 'Estimasi: ${order.estimatedTime}',
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.payments_outlined,
            text: [
              order.paymentMethod.isEmpty ? 'Metode belum dipilih' : order.paymentMethod,
              if (order.paymentStatusLabel.isNotEmpty) order.paymentStatusLabel,
            ].join(' - '),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatMerchantCurrency(order.totalAmount),
                  style: const TextStyle(
                    color: MerchantPalette.primary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: onDetail,
                child: const Text('Detail'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onProcess,
                style: FilledButton.styleFrom(
                  backgroundColor: MerchantPalette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(_actionLabel(order, onProcess)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _actionLabel(MerchantOrder order, VoidCallback? onProcess) {
  if (order.statusGroup == 'done') return 'Selesai';
  if (!order.canApprove) return 'Menunggu Bayar';
  if (order.status == 'pending') return 'Approve';
  return 'Proses';
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: MerchantPalette.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: MerchantPalette.muted,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

Color _statusColor(String group) {
  switch (group) {
    case 'pending':
      return MerchantPalette.danger;
    case 'done':
      return MerchantPalette.success;
    default:
      return const Color(0xFF1D4ED8);
  }
}
