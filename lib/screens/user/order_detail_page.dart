import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/midtrans_launcher.dart';
import '../../core/payment_methods.dart';
import '../../core/realtime_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/order.dart';
import '../../widgets/location_view_page.dart';
import '../shared/transaction_receipt_page.dart';
import 'user_theme.dart';
import 'user_widgets.dart';

class UserOrderDetailPage extends StatefulWidget {
  const UserOrderDetailPage({super.key, required this.order});

  final Order order;

  @override
  State<UserOrderDetailPage> createState() => _UserOrderDetailPageState();
}

class _UserOrderDetailPageState extends State<UserOrderDetailPage>
    with WidgetsBindingObserver {
  late Order _order;
  bool _confirmingPayment = false;
  bool _openingPayment = false;
  bool _autoSyncingPayment = false;
  bool _paymentSuccessShown = false;
  bool _cancellingSubscription = false;
  bool _extendingSubscription = false;
  bool _cancellingOrder = false;
  bool _loadingReceipt = false;
  Timer? _paymentAutoRefreshTimer;
  int _paymentAutoRefreshAttempts = 0;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    WidgetsBinding.instance.addObserver(this);

    // Use RealtimeService untuk real-time order updates
    RealtimeService().startUserOrderPolling();
    RealtimeService().addEventListener('order_status_updated', _refreshOrder);
    _maybeStartPaymentAutoRefresh();
  }

  @override
  void dispose() {
    _paymentAutoRefreshTimer?.cancel();
    // Stop real-time polling dan remove listeners
    RealtimeService()
        .removeEventListener('order_status_updated', _refreshOrder);
    RealtimeService().stopUserOrderPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshOrder());
      unawaited(_syncPaymentStatusSilently());
    }
  }

  Future<void> _refreshOrder() async {
    final id = _order.databaseId ?? _order.id;
    final result = await UserRepository.getOrderDetail(id);
    if (!mounted || result.data == null) return;
    setState(() => _order = result.data!);
    _maybeStartPaymentAutoRefresh();
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

  Future<void> _payWithMidtrans() async {
    final id = _order.databaseId ?? _order.id;
    final paymentMethod =
        _preferredMidtransPaymentMethod() ?? await _pickPaymentMethod();
    if (paymentMethod == null) return;
    if (!mounted) return;
    setState(() => _openingPayment = true);
    final result = await UserRepository.createOrderMidtransPayment(
      orderId: id,
      paymentMethod: paymentMethod,
    );
    if (!mounted) return;
    setState(() => _openingPayment = false);

    if (!result.isSuccess || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Gagal membuka Midtrans')),
      );
      return;
    }

    final midtransOrderId = result.data!['midtrans_order_id'] as String? ?? '';
    final url = result.data!['payment_url'] as String? ?? '';
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL pembayaran tidak valid')),
      );
      return;
    }

    final launched = await launchMidtransPaymentUrl(url);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka halaman pembayaran')),
      );
      return;
    }
    if (midtransOrderId.isNotEmpty) {
      _maybeStartPaymentAutoRefresh();
      await _pollOrderPaymentStatus(midtransOrderId);
    } else {
      await _refreshOrder();
    }
  }

  Future<void> _pollOrderPaymentStatus(String midtransOrderId) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      await Future.delayed(Duration(seconds: attempt == 0 ? 1 : 2));
      if (!mounted) return;

      await UserRepository.syncOrderMidtransStatus(
        midtransOrderId: midtransOrderId,
      );
      await _refreshOrder();
      if (!mounted) return;
      if (_order.isPaid) {
        _paymentSuccessShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil. Status pesanan diperbarui.'),
          ),
        );
        return;
      }
    }
  }

  Future<String?> _pickPaymentMethod() {
    final methods = PaymentMethodHelper.checkoutOptionKeys(isLaundry: false);
    var selected = (_order.paymentMethod ?? '').toLowerCase();
    if (!methods.contains(selected)) {
      selected = '';
    }
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Metode Pembayaran',
                      style: TextStyle(
                        color: UserTheme.primaryDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...methods.map(
                      (method) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          method == selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: method == selected
                              ? UserTheme.primary
                              : UserTheme.muted,
                        ),
                        title: Text(
                          PaymentMethodHelper.getDisplayName(method),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(PaymentMethodHelper.getCategory(method)),
                        onTap: () => Navigator.of(context).pop(method),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.of(context).pop(selected),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Lanjut ke Pembayaran'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String? _preferredMidtransPaymentMethod() {
    final raw = (_order.paymentMethod ?? '').trim().toLowerCase();
    if (raw.isEmpty || PaymentMethodHelper.isCashOnDelivery(raw)) {
      return null;
    }
    final known = PaymentMethodHelper.checkoutOptionKeys(isLaundry: false);
    if (known.contains(raw)) return raw;
    if (raw.contains('bca')) return 'bca';
    if (raw.contains('mandiri') || raw.contains('echannel')) return 'mandiri';
    if (raw.contains('bni')) return 'bni';
    if (raw.contains('gopay')) return 'gopay';
    if (raw.contains('shopee')) return 'shopeepay';
    return null;
  }

  String get _midtransActionLabel {
    final method = _preferredMidtransPaymentMethod();
    if (method == null) return 'Pilih Pembayaran Midtrans';
    return 'Bayar ${PaymentMethodHelper.getDisplayName(method)}';
  }

  bool get _shouldAutoSyncPayment {
    final payment = (_order.paymentStatus ?? '').toLowerCase();
    final merchant = (_order.merchantStatus ?? '').toLowerCase();
    final completed = _order.status == 'completed' ||
        merchant == 'done' ||
        merchant == 'completed';
    return (_order.midtransOrderId ?? '').isNotEmpty &&
        !_order.isCashOnDelivery &&
        !_order.isPaid &&
        _order.totalAmount > 0 &&
        !completed &&
        payment != 'cancelled';
  }

  void _maybeStartPaymentAutoRefresh() {
    if (!_shouldAutoSyncPayment) {
      _paymentAutoRefreshTimer?.cancel();
      _paymentAutoRefreshTimer = null;
      return;
    }
    if (_paymentAutoRefreshTimer != null) return;
    _paymentAutoRefreshAttempts = 0;
    _paymentAutoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_paymentAutoRefreshAttempts >= 24) {
        _paymentAutoRefreshTimer?.cancel();
        _paymentAutoRefreshTimer = null;
        return;
      }
      _paymentAutoRefreshAttempts++;
      unawaited(_syncPaymentStatusSilently());
    });
    unawaited(_syncPaymentStatusSilently());
  }

  Future<void> _syncPaymentStatusSilently() async {
    if (!_shouldAutoSyncPayment || _autoSyncingPayment) return;
    final midtransOrderId = _order.midtransOrderId ?? '';
    if (midtransOrderId.isEmpty) return;
    _autoSyncingPayment = true;
    try {
      await UserRepository.syncOrderMidtransStatus(
        midtransOrderId: midtransOrderId,
      );
      await _refreshOrder();
      if (!mounted) return;
      if (_order.isPaid && !_paymentSuccessShown) {
        _paymentSuccessShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil. Status pesanan diperbarui.'),
          ),
        );
      }
    } finally {
      _autoSyncingPayment = false;
    }
  }

  Future<void> _cancelOrder() async {
    final id = _order.databaseId ?? _order.id;
    setState(() => _cancellingOrder = true);
    final result = await UserRepository.cancelOrder(id);
    if (!mounted) return;
    setState(() {
      _cancellingOrder = false;
      if (result.data != null) _order = result.data!;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Pesanan dibatalkan'
              : result.error ?? 'Gagal membatalkan pesanan',
        ),
      ),
    );
  }

  Future<void> _openDeliveryLocation() async {
    final lat = _order.deliveryLatitude;
    final lng = _order.deliveryLongitude;
    final address = (_order.deliveryAddress ?? '').trim();
    if (lat == null || lng == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocationViewPage(
          title: 'Lokasi Pengiriman',
          address: address,
          latitude: lat,
          longitude: lng,
          primaryColor: UserTheme.primary,
        ),
      ),
    );
  }

  Future<void> _openReceipt() async {
    if (!_order.canDownloadReceipt) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Struk tersedia setelah pembayaran selesai'),
        ),
      );
      return;
    }
    final id = _order.databaseId ?? _order.id;
    setState(() => _loadingReceipt = true);
    final result = await UserRepository.getTransactionReceipt(id);
    if (!mounted) return;
    setState(() => _loadingReceipt = false);
    if (!result.isSuccess || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Gagal memuat struk')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionReceiptPage(receipt: result.data!),
      ),
    );
  }

  Future<void> _cancelSubscription() async {
    final id = _order.databaseId ?? _order.id;
    setState(() => _cancellingSubscription = true);
    final result = await UserRepository.cancelCateringSubscription(id);
    if (!mounted) return;
    setState(() {
      _cancellingSubscription = false;
      if (result.data != null) _order = result.data!;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Langganan akan berhenti saat periode selesai'
              : result.error ?? 'Gagal membatalkan langganan',
        ),
      ),
    );
  }

  Future<void> _extendSubscription() async {
    final id = _order.databaseId ?? _order.id;
    final days = _extensionDaysFor(_order);
    setState(() => _extendingSubscription = true);
    final result = await UserRepository.extendCateringSubscription(
      id,
      days: days,
    );
    if (!mounted) return;
    setState(() {
      _extendingSubscription = false;
      if (result.data != null) _order = result.data!;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Pengajuan perpanjangan dikirim. Tunggu persetujuan merchant sebelum membayar.'
              : result.error ?? 'Gagal memperpanjang langganan',
        ),
      ),
    );
  }

  int _extensionDaysFor(Order order) {
    return 30;
  }

  bool get _canConfirmManualPayment {
    return false;
  }

  bool get _canPayViaMidtrans {
    final payment = (_order.paymentStatus ?? '').toLowerCase();
    final merchant = (_order.merchantStatus ?? '').toLowerCase();
    final completed = _order.status == 'completed' ||
        merchant == 'done' ||
        merchant == 'completed';
    if (_order.isCashOnDelivery ||
        _order.awaitingWeighing ||
        _order.totalAmount <= 0 ||
        _order.isPaid ||
        completed ||
        payment == 'cancelled') {
      return false;
    }
    if (_order.isCateringSubscription && merchant != 'accepted') {
      return false;
    }
    return _order.readyToPay ||
        _order.needsOnlinePayment ||
        payment == 'payment_submitted';
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final serviceIcon = _serviceIcon(order.service);
    final paymentStatus = (order.paymentStatus ?? '').toLowerCase();
    final paymentCancelled =
        order.status == 'cancelled' || paymentStatus == 'cancelled';
    final paymentMethodRaw = (order.paymentMethod ?? '').trim();
    final paymentMethodLabel =
        order.paymentMethodLabel?.trim().isNotEmpty == true
            ? order.paymentMethodLabel!.trim()
            : PaymentMethodHelper.getDisplayName(order.paymentMethod);
    final hasPaymentMethod = paymentMethodRaw.isNotEmpty &&
        paymentMethodLabel.toLowerCase() != 'metode pembayaran';
    final merchantStatus = (order.merchantStatus ?? '').toLowerCase();
    final codCompleted = order.isCashOnDelivery &&
        (order.status == 'completed' ||
            merchantStatus == 'done' ||
            merchantStatus == 'completed');
    final paymentStatusDisplayLabel = codCompleted
        ? 'Sudah dibayar'
        : order.paymentStatusLabel?.isNotEmpty == true
            ? order.paymentStatusLabel!
            : order.isCashOnDelivery
                ? 'Belum Dibayar'
                : 'Menunggu pembayaran';
    final paymentHelperText = paymentCancelled
        ? ''
        : _canConfirmManualPayment
            ? 'Lakukan pembayaran sesuai metode di atas, lalu konfirmasi agar merchant dapat memproses pesanan.'
            : _canPayViaMidtrans
                ? 'Lanjutkan ke Midtrans sesuai metode yang dipilih. Status pembayaran akan diperbarui otomatis setelah transaksi berhasil.'
                : '';

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
          if (order.readyToPay) _ReadyToPayBanner(order: order),
          if (order.readyToPay) const SizedBox(height: 14),
          if (order.isCateringSubscription)
            _CateringActiveCard(order: order)
          else if (order.isLaundry)
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
          if (order.isLaundry) _LaundryServiceInfoCard(order: order),
          const SizedBox(height: 18),
          _InfoCard(
            icon: Icons.local_shipping_outlined,
            title: 'Informasi Pengiriman',
            children: [
              const Text(
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
              if (order.deliveryLatitude != null &&
                  order.deliveryLongitude != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openDeliveryLocation,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Lihat Lokasi'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _InfoCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Pembayaran',
            children: [
              if (!paymentCancelled || hasPaymentMethod) ...[
                _SubscriptionLine(
                  label: 'Metode Pembayaran',
                  value: hasPaymentMethod ? paymentMethodLabel : '-',
                ),
                const SizedBox(height: 10),
              ],
              _SubscriptionLine(
                label: 'Status Pembayaran',
                value: paymentStatusDisplayLabel,
                strong: true,
              ),
              if (paymentHelperText.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  paymentHelperText,
                  style: const TextStyle(color: UserTheme.muted, height: 1.4),
                ),
              ],
              if (_canConfirmManualPayment) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _confirmingPayment ? null : _confirmPayment,
                    style: FilledButton.styleFrom(
                      backgroundColor: UserTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      _confirmingPayment
                          ? 'Mengirim...'
                          : 'Konfirmasi Setelah Bayar',
                    ),
                  ),
                ),
              ],
              if (_canPayViaMidtrans) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openingPayment ? null : _payWithMidtrans,
                    style: FilledButton.styleFrom(
                      backgroundColor: UserTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: Text(
                      _openingPayment
                          ? 'Membuka Midtrans...'
                          : _midtransActionLabel,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (order.isCateringSubscription) ...[
            const SizedBox(height: 18),
            _SubscriptionInfoCard(order: order),
          ],
          const SizedBox(height: 28),
          if ((order.midtransOrderId ?? '').isNotEmpty &&
              !order.isPaid &&
              !order.isCashOnDelivery &&
              !paymentCancelled) ...[
            const _PaymentAutoRefreshNotice(),
          ] else if (!_canPayViaMidtrans &&
              !_canConfirmManualPayment &&
              !paymentCancelled)
            _PaymentStatusNotice(order: order),
          const SizedBox(height: 12),
          if (order.canDownloadReceipt)
            OutlinedButton.icon(
              onPressed: _loadingReceipt ? null : _openReceipt,
              style: OutlinedButton.styleFrom(
                foregroundColor: UserTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: _loadingReceipt
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.receipt_long_outlined),
              label: Text(_loadingReceipt ? 'Menyiapkan...' : 'Unduh Struk'),
            )
          else if (!paymentCancelled)
            _ReceiptUnavailableNotice(order: order),
          const SizedBox(height: 12),
          if (order.canExtendCateringSubscription) ...[
            OutlinedButton.icon(
              onPressed: _extendingSubscription ? null : _extendSubscription,
              style: OutlinedButton.styleFrom(
                foregroundColor: UserTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(Icons.update_rounded),
              label: Text(
                _extendingSubscription
                    ? 'Mengirim pengajuan...'
                    : 'Ajukan Perpanjangan ${_extensionDaysFor(order)} Hari',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (order.canCancel)
            TextButton(
              onPressed: order.shouldCancelAsSubscription
                  ? (_cancellingSubscription ? null : _cancelSubscription)
                  : (_cancellingOrder ? null : _cancelOrder),
              child: Text(
                order.shouldCancelAsSubscription
                    ? (_cancellingSubscription
                        ? 'Membatalkan...'
                        : 'Batalkan Langganan')
                    : (_cancellingOrder
                        ? 'Membatalkan...'
                        : order.isCateringSubscription
                            ? 'Batalkan Pesanan'
                            : 'Batalkan Pesanan (5 detik)'),
                style: const TextStyle(
                  color: UserTheme.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else if (order.isCateringSubscription && !paymentCancelled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                order.isSubscriptionCancellationRequested
                    ? 'Langganan sudah dibatalkan dan tetap aktif sampai periode selesai.'
                    : 'Paket catering aktif akan berakhir sesuai periode berjalan.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: UserTheme.muted, fontSize: 12),
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

class _ReadyToPayBanner extends StatelessWidget {
  const _ReadyToPayBanner({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1475C8), Color(0xFF00508F)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.isCateringSubscription
                ? 'Pesanan disetujui merchant'
                : 'Total pembayaran telah ditentukan',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.isCateringSubscription
                ? 'Total bayar ${formatUserCurrency(order.totalAmount)}. Silakan lakukan pembayaran untuk mengaktifkan jadwal catering.'
                : 'Merchant telah menetapkan total pembayaran laundry Anda sebesar ${formatUserCurrency(order.totalAmount)}. Silakan lakukan pembayaran sekarang.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CateringActiveCard extends StatelessWidget {
  const _CateringActiveCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final active = order.isCateringSubscription &&
        !order.isSubscriptionCancellationRequested &&
        order.status != 'cancelled';
    final hasPeriod = order.subscriptionStartDate != null &&
        order.subscriptionEndDate != null;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1475C8), Color(0xFF00508F)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [UserTheme.softShadow(opacity: 0.12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  active ? 'Paket Catering Aktif' : 'Paket Catering',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.items.isNotEmpty
                ? order.items.first.name
                : 'Langganan catering',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            order.merchantName,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          if (hasPeriod) ...[
            const SizedBox(height: 14),
            Text(
              'Periode: ${order.subscriptionStartDate != null ? formatShortDate(order.subscriptionStartDate!) : '-'} — ${order.subscriptionEndDate != null ? formatShortDate(order.subscriptionEndDate!) : '-'}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            formatUserCurrency(order.totalAmount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pengantaran dimulai sehari setelah pembayaran disetujui merchant.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusCard extends StatelessWidget {
  const _OrderStatusCard({required this.order});

  final Order order;

  String get _statusBadge {
    if (order.awaitingWeighing) return 'Menunggu Penimbangan';
    if (order.needsPaymentConfirmation) return 'Menunggu Pembayaran';
    switch ((order.merchantStatus ?? order.status).toLowerCase()) {
      case 'accepted':
      case 'confirmed':
        return 'Diterima';
      case 'processing':
      case 'in_progress':
        return 'Diproses';
      case 'delivered':
        return 'Siap Diantar';
      case 'done':
      case 'completed':
        return 'Selesai';
      default:
        return order.statusLabel;
    }
  }

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
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD2EAFF)),
                ),
                child: Text(
                  _statusBadge.toUpperCase(),
                  style: const TextStyle(
                    color: UserTheme.primaryDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (order.awaitingWeighing) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Menunggu merchant menentukan total pembayaran laundry.',
                style: TextStyle(
                  color: UserTheme.primaryDark,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          _OrderProgressBar(
            status: order.status,
            merchantStatus: order.merchantStatus,
          ),
        ],
      ),
    );
  }
}

class _OrderProgressBar extends StatelessWidget {
  const _OrderProgressBar({
    required this.status,
    this.merchantStatus,
  });

  final String status;
  final String? merchantStatus;

  static const _steps = [
    ('pending', 'Konfirmasi'),
    ('accepted', 'Diterima'),
    ('processing', 'Proses'),
    ('delivered', 'Diantar'),
    ('done', 'Selesai'),
  ];

  int get _currentIndex {
    if (status == 'cancelled') return -1;
    switch ((merchantStatus ?? status).toLowerCase()) {
      case 'accepted':
      case 'confirmed':
        return 1;
      case 'processing':
      case 'in_progress':
        return 2;
      case 'delivered':
        return 3;
      case 'done':
      case 'completed':
        return 4;
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
                margin:
                    EdgeInsets.only(right: index == _steps.length - 1 ? 0 : 6),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    step.$2,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: active ? UserTheme.primaryDark : UserTheme.muted,
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _LaundryServiceInfoCard extends StatelessWidget {
  const _LaundryServiceInfoCard({required this.order});

  final Order order;

  String get _durationLabel {
    if (order.serviceEstimateLabel?.trim().isNotEmpty == true) {
      return order.serviceEstimateLabel!.trim();
    }
    if (order.estimatedTime?.trim().isNotEmpty == true) {
      return order.estimatedTime!.trim();
    }
    return '';
  }

  String get _estimatedLabel {
    final finishAt = order.estimatedFinishAt;
    final duration = finishAt != null ? '' : _durationLabel;
    if (finishAt != null) {
      final dateLabel = _formatLongIndonesianDate(finishAt);
      return duration.isEmpty ? dateLabel : '$dateLabel (± $duration)';
    }
    if (duration.isNotEmpty) return duration;
    return 'Akan diinformasikan merchant';
  }

  @override
  Widget build(BuildContext context) {
    final serviceLabel =
        order.items.isNotEmpty ? order.items.first.name : 'Layanan Laundry';

    return _InfoCard(
      icon: Icons.local_laundry_service_outlined,
      title: 'Detail Laundry',
      children: [
        _SubscriptionLine(label: 'Jenis Layanan', value: serviceLabel),
        const SizedBox(height: 10),
        _SubscriptionLine(
          label: 'Estimasi Selesai',
          value: _estimatedLabel,
          strong: true,
        ),
        if (order.actualWeight != null) ...[
          const SizedBox(height: 10),
          _SubscriptionLine(
            label: 'Berat Aktual',
            value: '${order.actualWeight!.toStringAsFixed(1)}kg',
          ),
        ],
      ],
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final itemsSubtotal =
        order.items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final subtotal =
        order.subtotalAmount > 0 ? order.subtotalAmount : itemsSubtotal;
    final promoDiscount = order.promoDiscountAmount;
    final isLaundry = order.isLaundry;
    final mainItems = isLaundry && order.items.isNotEmpty
        ? <OrderItem>[order.items.first]
        : order.items;
    final additionalItems = isLaundry && order.items.length > 1
        ? order.items.sublist(1)
        : const <OrderItem>[];
    final waitingLaundryTotal =
        isLaundry && (order.awaitingWeighing || order.totalAmount <= 0);
    final showSingleItemPromo = !isLaundry &&
        order.hasPromo &&
        promoDiscount > 0 &&
        order.items.length == 1;
    final isWaitingFinalPrice = waitingLaundryTotal;
    final hasPromoDiscount = order.hasPromo && promoDiscount > 0;
    final showSubtotal =
        isLaundry ? isWaitingFinalPrice || hasPromoDiscount : true;

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
            padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Text(
              'Rincian Item',
              style: TextStyle(
                color: UserTheme.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Divider(color: Colors.blueGrey.shade50, height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ...mainItems.asMap().entries.map(
                  (entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final displaySubtotal = showSingleItemPromo
                        ? (item.subtotal - promoDiscount)
                            .clamp(0, double.infinity)
                            .toDouble()
                        : item.subtotal;
                    final displayUnit = item.quantity > 0
                        ? displaySubtotal / item.quantity
                        : displaySubtotal;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: UserTheme.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isLaundry
                                      ? _laundryItemDetailLabel(
                                          order,
                                          item,
                                          waitingLaundryTotal,
                                        )
                                      : showSingleItemPromo
                                          ? '${item.quantity} pcs x ${formatUserCurrency(displayUnit)} (promo)'
                                          : '${item.quantity} pcs x ${formatUserCurrency(item.price)}',
                                  style: const TextStyle(
                                    color: UserTheme.muted,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                                if (showSingleItemPromo) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Normal ${formatUserCurrency(item.price)}',
                                    style: const TextStyle(
                                      color: UserTheme.muted,
                                      fontSize: 12,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                                if (!isLaundry &&
                                    (item.description ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: UserTheme.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (index == 0 &&
                                    additionalItems.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  ...additionalItems.map(
                                    _AddonItemLine.new,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!waitingLaundryTotal) ...[
                            const SizedBox(width: 12),
                            Text(
                              formatUserCurrency(displaySubtotal),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: UserTheme.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                if (isWaitingFinalPrice) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F3E6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Merchant akan menentukan total pembayaran laundry setelah proses penimbangan.',
                      style: TextStyle(
                        color: UserTheme.primaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                if (showSubtotal) ...[
                  const SizedBox(height: 10),
                  _TotalRow(
                    label: 'Subtotal',
                    value: subtotal,
                    valueText: waitingLaundryTotal ? 'Belum tersedia' : null,
                  ),
                ],
                if (hasPromoDiscount) ...[
                  const SizedBox(height: 10),
                  _TotalRow(
                    label: order.promoName?.isNotEmpty == true
                        ? 'Promo (${order.promoName})'
                        : 'Diskon Promo',
                    value: -promoDiscount,
                    valueColor: UserTheme.success,
                  ),
                ],
                const SizedBox(height: 14),
                _TotalRow(
                  label: 'Total Pembayaran',
                  value: order.totalAmount,
                  valueText:
                      isWaitingFinalPrice ? 'Menunggu penimbangan' : null,
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

String _laundryTariffLabel(OrderItem item) {
  if (item.price <= 0) {
    return 'Harga akan dihitung setelah penimbangan';
  }
  final unit = _orderPricingUnit(item);
  return 'Tarif ${formatUserCurrency(item.price)}$unit';
}

String _laundryItemDetailLabel(
  Order order,
  OrderItem item,
  bool waitingFinalPrice,
) {
  if (waitingFinalPrice) return _laundryTariffLabel(item);
  if (item.price <= 0) return 'Harga layanan';

  final unit = _orderPricingUnit(item);
  final priceLabel = '${formatUserCurrency(item.price)}$unit';
  if (unit == '/kg') {
    final weight = order.actualWeight ?? item.quantityValue;
    if (weight > 0) {
      return '${_formatLaundryQuantity(weight)} kg × $priceLabel';
    }
  }

  if (unit == '/item') {
    final quantity =
        item.quantityValue > 0 ? item.quantityValue : item.quantity.toDouble();
    if (quantity > 0) {
      return '${_formatLaundryQuantity(quantity)} item × $priceLabel';
    }
  }

  if (unit.isEmpty) {
    return 'Harga tetap ${formatUserCurrency(item.price)}';
  }
  return _laundryTariffLabel(item);
}

String _orderPricingUnit(OrderItem item) {
  final rawUnit = item.unit.trim();
  if (rawUnit.isNotEmpty && rawUnit != 'fixed') {
    return rawUnit.startsWith('/') ? rawUnit : '/$rawUnit';
  }
  switch (item.pricingType) {
    case 'per_item':
      return '/item';
    case 'flat':
      return '';
    default:
      return '/kg';
  }
}

String _formatLaundryQuantity(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.001) {
    return rounded.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

String _formatLongIndonesianDate(DateTime date) {
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _AddonItemLine extends StatelessWidget {
  const _AddonItemLine(this.item);

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final amount = item.subtotal > 0 ? item.subtotal : item.price;
    final title = amount > 0
        ? '${item.name} (+${formatUserCurrency(amount)})'
        : item.name;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              color: UserTheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: UserTheme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.valueText,
    this.strong = false,
    this.valueColor,
  });

  final String label;
  final double value;
  final String? valueText;
  final bool strong;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final resolvedValue = valueText ?? formatUserCurrency(value);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < 330 || resolvedValue.length > 18;
        if (tight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: strong ? UserTheme.text : UserTheme.muted,
                  fontSize: strong ? 15 : 13,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  resolvedValue,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: valueColor ??
                        (strong ? UserTheme.primaryDark : UserTheme.text),
                    fontSize: strong ? 17 : 13,
                    fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: strong ? UserTheme.text : UserTheme.muted,
                  fontSize: strong ? 15 : 13,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              resolvedValue,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ??
                    (strong ? UserTheme.primaryDark : UserTheme.text),
                fontSize: strong ? 17 : 13,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PaymentStatusNotice extends StatelessWidget {
  const _PaymentStatusNotice({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == 'cancelled' ||
        (order.paymentStatus ?? '').toLowerCase() == 'cancelled';
    final label = order.paymentStatusLabel?.trim().isNotEmpty == true
        ? order.paymentStatusLabel!
        : 'Pembayaran tercatat';
    final merchant = (order.merchantStatus ?? '').toLowerCase();
    final codCompleted = order.isCashOnDelivery &&
        (order.status == 'completed' ||
            merchant == 'done' ||
            merchant == 'completed');
    final effectiveLabel = cancelled
        ? 'Pesanan dibatalkan.'
        : codCompleted
            ? 'Sudah dibayar'
            : order.isCateringSubscription &&
                    (order.merchantStatus ?? '').toLowerCase() != 'accepted' &&
                    !order.isPaid
                ? 'Menunggu persetujuan merchant. Tombol pembayaran akan muncul setelah pesanan disetujui.'
                : label;
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
              effectiveLabel,
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

class _PaymentAutoRefreshNotice extends StatelessWidget {
  const _PaymentAutoRefreshNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFD2EAFF)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Status pembayaran dicek otomatis. Setelah transaksi berhasil, pesanan langsung diperbarui.',
              style: TextStyle(
                color: UserTheme.primaryDark,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptUnavailableNotice extends StatelessWidget {
  const _ReceiptUnavailableNotice({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final message = order.awaitingWeighing || order.totalAmount <= 0
        ? 'Struk tersedia setelah merchant menentukan total dan pembayaran selesai.'
        : 'Struk tersedia setelah pembayaran selesai.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFC8E3FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: UserTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: UserTheme.primaryDark,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionInfoCard extends StatelessWidget {
  const _SubscriptionInfoCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final status = order.subscriptionStatus ?? 'pending_payment';
    final hasPeriod = order.subscriptionStartDate != null &&
        order.subscriptionEndDate != null;
    return _InfoCard(
      icon: Icons.calendar_month_outlined,
      title: 'Status Langganan',
      children: [
        _SubscriptionLine(
          label: 'Paket',
          value: '${order.subscriptionDays ?? 0} hari',
        ),
        if (hasPeriod) ...[
          const SizedBox(height: 10),
          _SubscriptionLine(
            label: 'Mulai',
            value: formatShortDate(order.subscriptionStartDate!),
          ),
          const SizedBox(height: 10),
          _SubscriptionLine(
            label: 'Berakhir',
            value: formatShortDate(order.subscriptionEndDate!),
          ),
        ],
        const SizedBox(height: 10),
        _SubscriptionLine(
          label: 'Status',
          value: _subscriptionStatusLabel(status),
          strong: true,
        ),
      ],
    );
  }
}

class _SubscriptionLine extends StatelessWidget {
  const _SubscriptionLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: UserTheme.muted),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: strong ? UserTheme.primaryDark : UserTheme.text,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
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

String _subscriptionStatusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Aktif';
    case 'cancel_requested':
      return 'Dibatalkan, aktif sampai selesai';
    case 'ended':
      return 'Selesai';
    case 'pending_payment':
      return 'Menunggu pembayaran';
    case 'cancelled':
      return 'Dibatalkan';
    default:
      return status.isEmpty ? '-' : status;
  }
}
