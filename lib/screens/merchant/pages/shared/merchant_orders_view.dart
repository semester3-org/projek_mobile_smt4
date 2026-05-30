import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _loadingRequest = false;
  String? _error;
  int _selectedFilter = 0;

  List<String> get _filters => widget.isLaundry
      ? const ['Semua', 'Konfirmasi', 'Berjalan', 'Selesai']
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
    if (_loadingRequest) return;
    _loadingRequest = true;
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
      _loadingRequest = false;
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

  void _showTimedSnackBar(String message, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: const Duration(seconds: 3),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
    });
  }

  Future<void> _process(MerchantOrder order) async {
    final result = await MerchantRepository.updateOrder(
      id: order.id,
      nextStatus: true,
    );
    if (!mounted) return;
    final updated = result.data ?? order;
    _showTimedSnackBar(
      result.isSuccess
          ? 'Pesanan ${order.code} diperbarui. Detail menampilkan alur lengkap.'
          : result.error ?? 'Gagal memproses pesanan',
      action: result.isSuccess
          ? SnackBarAction(
              label: 'Lihat Detail',
              onPressed: () => _openDetail(updated),
            )
          : null,
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
    final hasPendingEarlier = order.deliveryMilestones.any(
      (item) => item.slotNumber < milestone.slotNumber && !item.isDelivered,
    );
    if (hasPendingEarlier) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selesaikan pengantaran sebelumnya dulu agar urutan pengiriman tetap valid.',
          ),
        ),
      );
      return;
    }
    if (_isMilestoneTooEarly(milestone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pengantaran belum masuk waktunya. Selesaikan maksimal 15 menit sebelum jadwal.',
          ),
        ),
      );
      return;
    }
    final proof = await showDialog<_DeliveryProof>(
      context: context,
      builder: (context) => _CompleteDeliveryDialog(
        order: order,
        milestone: milestone,
      ),
    );
    if (proof == null || !mounted) return;
    final result = await MerchantRepository.completeCateringDelivery(
      orderId: order.id,
      deliveryLogId: milestone.id,
      deliveryNote: proof.note,
      deliveryPhotoUrl: proof.photoUrl,
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

  Future<void> _handleLaundryCardAction(MerchantOrder order) async {
    if (_isLaundryWeighingStep(order)) {
      await _openDetail(order, focus: MerchantOrderDetailFocus.weighing);
      return;
    }

    if (_isLaundryWaitingPayment(order)) {
      _showDetailSuggestion(
        order,
        'Pesanan masih menunggu pembayaran user. Buka detail untuk melihat milestone dan status pembayaran.',
      );
      return;
    }

    if (!_canAdvanceLaundryFromCard(order)) {
      await _openDetail(order);
      return;
    }

    final result = await MerchantRepository.updateOrder(
      id: order.id,
      nextStatus: true,
    );
    if (!mounted) return;
    final updated = result.data ?? order;
    if (result.isSuccess && result.data != null) {
      setState(() {
        final idx = _orders.indexWhere((o) => o.id == order.id);
        if (idx >= 0) _orders[idx] = result.data!;
      });
    } else if (result.isSuccess) {
      _load(silent: true);
    }

    _showTimedSnackBar(
      result.isSuccess
          ? 'Pesanan ${order.code} diperbarui. Detail menampilkan milestone lengkap.'
          : result.error ?? 'Gagal memperbarui pesanan',
      action: result.isSuccess
          ? SnackBarAction(
              label: 'Lihat Detail',
              onPressed: () => _openDetail(
                updated,
                focus: _detailFocusFor(updated),
              ),
            )
          : null,
    );
  }

  void _showDetailSuggestion(MerchantOrder order, String message) {
    _showTimedSnackBar(
      message,
      action: SnackBarAction(
        label: 'Buka Detail',
        onPressed: () => _openDetail(order, focus: _detailFocusFor(order)),
      ),
    );
  }

  Future<void> _openDetail(
    MerchantOrder order, {
    MerchantOrderDetailFocus? focus,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MerchantOrderDetailPage(
          isLaundry: widget.isLaundry,
          orderId: order.id,
          initialFocus: focus,
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
                onProcess: widget.isLaundry
                    ? (order.statusGroup == 'done' ||
                            order.statusGroup == 'cancelled'
                        ? null
                        : () => _handleLaundryCardAction(order))
                    : (order.statusGroup == 'done' ||
                            order.statusGroup == 'cancelled' ||
                            order.statusGroup == 'waiting_payment' ||
                            order.statusGroup == 'today_delivery' ||
                            !order.canApprove
                        ? null
                        : () => _process(order)),
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
            ].join(' - '),
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
          if (onProcess != null &&
              (order.serviceType != 'catering' ||
                  order.statusGroup != 'today_delivery')) ...[
            _CardActionHint(
              text: _laundryCardActionAdvice(order),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _orderTotalText(order),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MerchantPalette.primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: onDetail,
                  child: const Text('Detail'),
                ),
                if (onReject != null)
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
                if (onProcess != null &&
                    (order.serviceType != 'catering' ||
                        order.statusGroup != 'today_delivery'))
                  FilledButton(
                    onPressed: onProcess,
                    style: FilledButton.styleFrom(
                      backgroundColor: MerchantPalette.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _actionLabel(order),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardActionHint extends StatelessWidget {
  const _CardActionHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MerchantPalette.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: MerchantPalette.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: MerchantPalette.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$text Detail pesanan tetap bisa dibuka untuk melihat milestone lengkap.',
                style: const TextStyle(
                  color: MerchantPalette.primary,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _serviceEstimateText(MerchantOrder order) {
  if (order.serviceType == 'laundry') {
    if (order.estimatedFinishAt != null) {
      return 'Estimasi selesai: ${_formatDateTime(order.estimatedFinishAt!)}';
    }
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

String _orderTotalText(MerchantOrder order) {
  if (order.serviceType == 'laundry' &&
      (order.totalAmount <= 0 ||
          order.paymentStatus.toLowerCase() == 'awaiting_weighing')) {
    return 'Total belum ditentukan';
  }
  return formatMerchantCurrency(order.totalAmount);
}

String _formatDateTime(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

String _actionLabel(MerchantOrder order) {
  if (order.statusGroup == 'done') return 'Selesai';
  if (order.statusGroup == 'cancelled') return 'Dibatalkan';
  if (order.serviceType == 'laundry') {
    final payment = order.paymentStatus.toLowerCase();
    if (order.status == 'pending') return 'Terima Pesanan';
    if (payment == 'awaiting_weighing' || order.totalAmount <= 0) {
      return 'Timbang & Total Bayar';
    }
    if (order.status == 'accepted' &&
        (payment == 'waiting_payment' || payment == 'unpaid')) {
      return 'Lihat Pembayaran';
    }
    if (order.status == 'accepted' &&
        ['paid', 'payment_submitted', 'cod'].contains(payment)) {
      return 'Mulai Proses Laundry';
    }
    if (order.status == 'processing') return 'Tandai Siap Diantar';
    if (order.status == 'delivered') return 'Tandai Selesai';
    return 'Kelola Pesanan';
  }
  if (!order.canApprove) return 'Menunggu Bayar';
  if (order.serviceType == 'catering' && order.status == 'pending') {
    return 'Setujui';
  }
  if (order.status == 'pending') return 'Approve';
  return 'Kelola Pesanan';
}

bool _isLaundryWeighingStep(MerchantOrder order) {
  final payment = order.paymentStatus.toLowerCase();
  return order.serviceType == 'laundry' &&
      order.status != 'pending' &&
      (payment == 'awaiting_weighing' || order.totalAmount <= 0);
}

bool _isLaundryWaitingPayment(MerchantOrder order) {
  final payment = order.paymentStatus.toLowerCase();
  return order.serviceType == 'laundry' &&
      order.status == 'accepted' &&
      (payment == 'waiting_payment' || payment == 'unpaid');
}

bool _canAdvanceLaundryFromCard(MerchantOrder order) {
  if (order.serviceType != 'laundry') return false;
  if (order.statusGroup == 'done' || order.statusGroup == 'cancelled') {
    return false;
  }
  final payment = order.paymentStatus.toLowerCase();
  if (order.status == 'pending') return true;
  if (order.status == 'accepted') {
    return ['paid', 'payment_submitted', 'cod'].contains(payment);
  }
  return order.status == 'processing' || order.status == 'delivered';
}

MerchantOrderDetailFocus? _detailFocusFor(MerchantOrder order) {
  return _isLaundryWeighingStep(order)
      ? MerchantOrderDetailFocus.weighing
      : null;
}

String _laundryCardActionAdvice(MerchantOrder order) {
  if (order.serviceType != 'laundry') {
    if (order.status == 'pending') {
      return 'Pesanan bisa disetujui langsung dari kartu ini.';
    }
    return 'Aksi cepat ini melanjutkan pesanan ke tahap berikutnya.';
  }
  if (order.status == 'pending') {
    return 'Pesanan akan diterima dan masuk ke tahap penimbangan.';
  }
  if (order.status == 'accepted') {
    return 'Pembayaran sudah siap. Pesanan akan masuk ke tahap proses laundry.';
  }
  if (order.status == 'processing') {
    return 'Gunakan aksi ini jika laundry sudah selesai diproses dan siap dikirim.';
  }
  if (order.status == 'delivered') {
    return 'Gunakan aksi ini setelah pesanan sudah diterima pelanggan.';
  }
  return 'Aksi ini akan melanjutkan status pesanan ke tahap berikutnya.';
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (milestones.length > 1) ...[
          const Text(
            'Pengantaran harus diselesaikan berurutan. Pengantaran berikutnya terkunci sampai jadwal sebelumnya selesai.',
            style: TextStyle(
              color: MerchantPalette.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ...milestones.map((item) {
          final hasPendingEarlier = milestones.any(
            (other) => other.slotNumber < item.slotNumber && !other.isDelivered,
          );
          final canComplete = !item.isDelivered && !hasPendingEarlier;
          final isOverdue = _isMilestoneOverdue(item);
          final iconColor = item.isDelivered
              ? MerchantPalette.success
              : isOverdue
                  ? MerchantPalette.danger
                  : MerchantPalette.primary;
          return Container(
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
                  color: iconColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengantaran ${item.scheduledTime}',
                        style: const TextStyle(
                          color: MerchantPalette.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (isOverdue || hasPendingEarlier) ...[
                        const SizedBox(height: 3),
                        Text(
                          isOverdue
                              ? 'Terlambat dari jadwal'
                              : 'Menunggu pengantaran sebelumnya',
                          style: TextStyle(
                            color: isOverdue
                                ? MerchantPalette.danger
                                : MerchantPalette.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (item.isDelivered &&
                          (item.deliveryNote.isNotEmpty ||
                              item.deliveryPhotoUrl.isNotEmpty)) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (item.deliveryPhotoUrl.isNotEmpty) 'Foto bukti',
                            if (item.deliveryNote.isNotEmpty) 'Catatan',
                          ].join(' + '),
                          style: const TextStyle(
                            color: MerchantPalette.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: canComplete ? () => onComplete(item) : null,
                  child: Text(
                    item.isDelivered
                        ? 'Selesai'
                        : hasPendingEarlier
                            ? 'Terkunci'
                            : 'Selesaikan',
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

bool _isMilestoneOverdue(MerchantDeliveryMilestone milestone) {
  if (milestone.isDelivered) return false;
  final scheduledAt = _milestoneScheduledAt(milestone);
  if (scheduledAt == null) return false;
  return DateTime.now().isAfter(scheduledAt.add(const Duration(hours: 1)));
}

bool _isMilestoneTooEarly(MerchantDeliveryMilestone milestone) {
  if (milestone.isDelivered) return false;
  final scheduledAt = _milestoneScheduledAt(milestone);
  if (scheduledAt == null) return false;
  return DateTime.now().isBefore(
    scheduledAt.subtract(const Duration(minutes: 15)),
  );
}

DateTime? _milestoneScheduledAt(MerchantDeliveryMilestone milestone) {
  final dateParts = milestone.date.split('-');
  final timeParts = milestone.scheduledTime.split(':');
  if (dateParts.length != 3 || timeParts.length < 2) return null;
  final year = int.tryParse(dateParts[0]);
  final month = int.tryParse(dateParts[1]);
  final day = int.tryParse(dateParts[2]);
  final hour = int.tryParse(timeParts[0]);
  final minute = int.tryParse(timeParts[1]);
  if ([year, month, day, hour, minute].any((value) => value == null)) {
    return null;
  }
  return DateTime(year!, month!, day!, hour!, minute!);
}

class _DeliveryProof {
  const _DeliveryProof({
    required this.note,
    required this.photoUrl,
  });

  final String note;
  final String photoUrl;
}

class _CompleteDeliveryDialog extends StatefulWidget {
  const _CompleteDeliveryDialog({
    required this.order,
    required this.milestone,
  });

  final MerchantOrder order;
  final MerchantDeliveryMilestone milestone;

  @override
  State<_CompleteDeliveryDialog> createState() =>
      _CompleteDeliveryDialogState();
}

class _CompleteDeliveryDialogState extends State<_CompleteDeliveryDialog> {
  final _noteCtrl = TextEditingController();
  final _picker = ImagePicker();
  String _photoUrl = '';
  bool _picking = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final ext = file.name.toLowerCase().endsWith('.png')
          ? 'png'
          : file.name.toLowerCase().endsWith('.webp')
              ? 'webp'
              : 'jpeg';
      if (!mounted) return;
      setState(() {
        _photoUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
      });
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selesaikan Pengantaran?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pastikan makanan untuk ${widget.order.customerName} pada jadwal ${widget.milestone.scheduledTime} sudah benar-benar dikirim. Aksi ini akan dicatat sebagai bukti pengantaran.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Catatan opsional',
                hintText: 'Contoh: diterima penjaga kos',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _picking ? null : _pickPhoto,
              icon: Icon(
                _photoUrl.isEmpty
                    ? Icons.camera_alt_outlined
                    : Icons.check_circle_outline_rounded,
              ),
              label: Text(
                _photoUrl.isEmpty
                    ? 'Tambah foto bukti opsional'
                    : 'Foto bukti ditambahkan',
              ),
            ),
            if (_photoUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  base64Decode(_photoUrl.split(',').last),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _photoUrl = ''),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Hapus foto'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _DeliveryProof(
              note: _noteCtrl.text.trim(),
              photoUrl: _photoUrl,
            ),
          ),
          child: const Text('Ya, sudah dikirim'),
        ),
      ],
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
