import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/payment_methods.dart';
import '../../../../core/realtime_service.dart';
import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/merchant_models.dart';
import '../../merchant_ui.dart';
import 'merchant_notifications_page.dart';
import 'merchant_order_detail_page.dart';

class MerchantOrdersView extends StatefulWidget {
  const MerchantOrdersView({
    super.key,
    required this.isLaundry,
    this.showBack = false,
  });

  final bool isLaundry;
  final bool showBack;

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

  List<String> get _filters => widget.isLaundry
      ? const ['Semua', 'Pending', 'Diproses', 'Selesai']
      : const [
          'Semua',
          'Pending',
          'Menunggu Bayar',
          'Pengantaran Hari Ini',
          'Selesai'
        ];

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeService().startMerchantOrdersPolling();
    RealtimeService()
        .addEventListener('merchant_order_updated', _silentRefresh);
    RealtimeService().addEventListener('dashboard_updated', _silentRefresh);
  }

  @override
  void dispose() {
    RealtimeService()
        .removeEventListener('merchant_order_updated', _silentRefresh);
    RealtimeService().removeEventListener('dashboard_updated', _silentRefresh);
    RealtimeService().stopMerchantOrdersPolling();
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final result = await MerchantRepository.getOrders(
      status: _statusParam,
      search: _searchCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _orders = result.data ?? [];
      if (!silent) _error = result.error;
      _loading = false;
    });
  }

  void _silentRefresh() => _load(silent: true);

  String? get _statusParam {
    switch (_selectedFilter) {
      case 1:
        return 'pending';
      case 2:
        return widget.isLaundry ? 'processing' : 'waiting_payment';
      case 3:
        return widget.isLaundry ? 'done' : 'today_delivery';
      case 4:
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
    if (result.isSuccess && result.data != null) {
      setState(() {
        final idx = _orders.indexWhere((o) => o.id == order.id);
        if (idx >= 0) _orders[idx] = result.data!;
      });
    } else if (result.isSuccess) {
      _load(silent: true);
    }
  }

  Future<void> _completeDelivery(
    MerchantOrder order,
    MerchantDeliveryMilestone milestone,
  ) async {
    final result = await MerchantRepository.completeCateringDelivery(
      orderId: order.id,
      deliveryLogId: milestone.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isSuccess
            ? 'Pengantaran ${milestone.scheduledTime} selesai'
            : result.error ?? 'Gagal menyelesaikan pengantaran'),
      ),
    );
    if (result.isSuccess && result.data != null) {
      setState(() {
        final idx = _orders.indexWhere((o) => o.id == order.id);
        if (idx >= 0) _orders[idx] = result.data!;
      });
      await _load(silent: true);
    }
  }

  Future<void> _rejectOrder(MerchantOrder order) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectOrderDialog(),
    );
    if (reason == null || reason.trim().isEmpty) return;
    final result = await MerchantRepository.rejectOrder(
      orderId: order.id,
      reason: reason.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isSuccess
            ? 'Pesanan ${order.code} ditolak'
            : result.error ?? 'Gagal menolak pesanan'),
      ),
    );
    if (result.isSuccess && result.data != null) {
      setState(() {
        final idx = _orders.indexWhere((o) => o.id == order.id);
        if (idx >= 0) _orders[idx] = result.data!;
      });
    }
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
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'Daftar Pesanan',
        showBack: widget.showBack,
        showAvatar: !widget.showBack,
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MerchantNotificationsPage()),
        ),
      ),
      children: [
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
                onProcess: order.statusGroup == 'done' ||
                        order.statusGroup == 'cancelled' ||
                        (!widget.isLaundry &&
                            order.statusGroup == 'waiting_payment') ||
                        (!widget.isLaundry &&
                            order.statusGroup == 'today_delivery') ||
                        !order.canApprove
                    ? null
                    : () => _process(order),
                onCompleteDelivery: (milestone) =>
                    _completeDelivery(order, milestone),
                onReject: order.serviceType == 'catering' &&
                        order.status == 'pending' &&
                        order.statusGroup != 'cancelled'
                    ? () => _rejectOrder(order)
                    : null,
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
    required this.onCompleteDelivery,
    this.onReject,
    this.onProcess,
  });

  final MerchantOrder order;
  final VoidCallback onDetail;
  final ValueChanged<MerchantDeliveryMilestone> onCompleteDelivery;
  final VoidCallback? onReject;
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
            text: _serviceEstimateText(order),
          ),
          if (order.isCateringSubscription) ...[
            const SizedBox(height: 10),
            _InfoLine(
              icon: Icons.calendar_month_outlined,
              text:
                  'Langganan ${order.subscriptionDays ?? 0} hari - ${_subscriptionStatusLabel(order.subscriptionStatus ?? '')}',
            ),
          ],
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.payments_outlined,
            text: [
              order.paymentMethodLabel.isNotEmpty
                  ? order.paymentMethodLabel
                  : PaymentMethodHelper.getDisplayName(order.paymentMethod),
              if (order.paymentStatusLabel.isNotEmpty) order.paymentStatusLabel,
            ].join(' · '),
          ),
          if (order.serviceType == 'catering' &&
              order.deliveryMilestones.isNotEmpty) ...[
            const SizedBox(height: 14),
            _DeliveryMilestones(
              milestones: order.deliveryMilestones,
              onComplete: onCompleteDelivery,
            ),
          ],
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
              if (onReject != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MerchantPalette.danger,
                    side: BorderSide(
                      color: MerchantPalette.danger.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Tolak'),
                ),
              ],
              if (onProcess != null &&
                  (order.serviceType != 'catering' ||
                      order.statusGroup != 'today_delivery')) ...[
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
            ],
          ),
        ],
      ),
    );
  }
}

String _serviceEstimateText(MerchantOrder order) {
  if (order.serviceType == 'laundry') {
    final label = order.serviceEstimateLabel.isNotEmpty
        ? order.serviceEstimateLabel
        : order.estimatedTime;
    if (label.isEmpty) {
      return order.paymentStatus.toLowerCase() == 'awaiting_weighing'
          ? 'Sedang ditimbang merchant'
          : 'Estimasi layanan belum diatur';
    }
    if (RegExp(r'^\d+(-\d+)?\s*mnt', caseSensitive: false).hasMatch(label)) {
      return 'Estimasi layanan: $label';
    }
    return 'Estimasi layanan: $label';
  }
  return order.estimatedTime.isEmpty
      ? 'Estimasi belum diatur'
      : order.estimatedTime;
}

String _actionLabel(MerchantOrder order, VoidCallback? onProcess) {
  if (order.statusGroup == 'done') return 'Selesai';
  if (!order.canApprove) return 'Menunggu Bayar';
  if (order.serviceType == 'catering' && order.status == 'pending') {
    return 'Setujui';
  }
  if (order.status == 'pending') return 'Approve';
  return 'Proses';
}

class _DeliveryMilestones extends StatelessWidget {
  const _DeliveryMilestones({
    required this.milestones,
    required this.onComplete,
  });

  final List<MerchantDeliveryMilestone> milestones;
  final ValueChanged<MerchantDeliveryMilestone> onComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: milestones
          .map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    item.isDelivered
                        ? Icons.check_circle_rounded
                        : Icons.delivery_dining_rounded,
                    color: item.isDelivered
                        ? MerchantPalette.success
                        : MerchantPalette.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pengantaran ${item.scheduledTime}',
                      style: const TextStyle(
                        color: MerchantPalette.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: item.isDelivered ? null : () => onComplete(item),
                    child: Text(item.isDelivered ? 'Selesai' : 'Selesaikan'),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RejectOrderDialog extends StatefulWidget {
  const _RejectOrderDialog();

  @override
  State<_RejectOrderDialog> createState() => _RejectOrderDialogState();
}

class _RejectOrderDialogState extends State<_RejectOrderDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tolak Pesanan'),
      content: TextField(
        controller: _ctrl,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Alasan penolakan',
          hintText: 'Contoh: Kuota catering hari ini sudah penuh',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final reason = _ctrl.text.trim();
            if (reason.isEmpty) return;
            Navigator.pop(context, reason);
          },
          child: const Text('Tolak'),
        ),
      ],
    );
  }
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
    case 'cancelled':
      return MerchantPalette.danger;
    case 'done':
      return MerchantPalette.success;
    default:
      return const Color(0xFF1D4ED8);
  }
}

String _subscriptionStatusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Aktif';
    case 'cancel_requested':
      return 'Dibatalkan, tetap jalan';
    case 'ended':
      return 'Selesai';
    case 'pending_payment':
      return 'Menunggu pembayaran';
    default:
      return status.isEmpty ? '-' : status;
  }
}
