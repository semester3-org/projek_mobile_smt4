import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../data/repositories/user_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/billing_record.dart';
import '../user/user_theme.dart';
import '../user/user_widgets.dart';

class BillingDetailPage extends StatefulWidget {
  const BillingDetailPage({
    super.key,
    required this.billing,
    this.cancellationMeansStopRenewal = false,
    this.activeUntilForStopRenewal,
    this.actionsEnabled = true,
  });

  final BillingRecord billing;
  final bool cancellationMeansStopRenewal;
  final DateTime? activeUntilForStopRenewal;
  final bool actionsEnabled;

  @override
  State<BillingDetailPage> createState() => _BillingDetailPageState();
}

class _BillingDetailPageState extends State<BillingDetailPage> with WidgetsBindingObserver {
  late BillingRecord _billing;
  late String _billingLookupId;
  String _method = 'GoPay QRIS';
  String? _lastMidtransOrderId;
  bool _cancelling = false;
  bool _paying = false;
  bool _paymentCompletionHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _billing = widget.billing;
    _billingLookupId = widget.billing.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadBilling();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPaymentStatusAndReload(midtransOrderId: _lastMidtransOrderId);
    }
  }

  Future<BillingRecord?> _reloadBilling() async {
    final result = await UserRepository.getBillings();
    if (!mounted || !result.isSuccess) return null;

    final matches = result.data!.where((billing) => billing.id == _billingLookupId);
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tagihan sudah tidak aktif.')),
      );
      Navigator.of(context).pop(true);
      return null;
    }

    final updated = matches.first;

    if (updated.id != _billing.id ||
        updated.status != _billing.status ||
        updated.activeUntil != _billing.activeUntil ||
        updated.paymentMethod != _billing.paymentMethod ||
        updated.paymentDate != _billing.paymentDate) {
      setState(() {
        _billing = updated;
        _billingLookupId = updated.id;
      });
    }

    return updated;
  }

  Future<void> _syncPaymentStatusAndReload({String? midtransOrderId}) async {
    if (midtransOrderId != null && midtransOrderId.isNotEmpty) {
      await UserRepository.syncMidtransPaymentStatus(
        midtransOrderId: midtransOrderId,
      );
    }
    final updated = await _reloadBilling();
    if (midtransOrderId != null && updated?.isPaid == true) {
      _finishPaidFlow(updated!);
    }
  }

  Future<void> _pollPaymentStatus(String midtransOrderId) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      await Future.delayed(Duration(seconds: attempt == 0 ? 1 : 2));
      if (!mounted) return;

      await UserRepository.syncMidtransPaymentStatus(
        midtransOrderId: midtransOrderId,
      );
      final updated = await _reloadBilling();
      if (updated == null || updated.isCancelled) return;
      if (updated.isPaid) {
        _finishPaidFlow(updated);
        return;
      }
    }
  }

  void _finishPaidFlow(BillingRecord updated) {
    if (_paymentCompletionHandled || !mounted) return;
    _paymentCompletionHandled = true;
    UserRepository.requestProfileRefresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pembayaran berhasil. Masa aktif sampai ${formatShortDate(updated.activeUntil ?? updated.dueDate)}.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _cancelOrder() async {
    final billing = _billing;
    final isPaid = billing.isPaid;
    final stopRenewal = isPaid || widget.cancellationMeansStopRenewal;
    final activeUntil =
        widget.activeUntilForStopRenewal ?? billing.activeUntil ?? billing.dueDate;
    if (billing.isCancelled) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stopRenewal ? 'Tidak Perpanjang Sewa?' : 'Batalkan Order?'),
        content: Text(
          stopRenewal
              ? 'Masa sewa tetap aktif sampai ${formatShortDate(activeUntil)}. Setelah itu kamar akan dikosongkan dan sewa tidak diperpanjang otomatis.'
              : 'Order akan dibatalkan. Pengajuan kamar Anda akan dilepas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(stopRenewal ? 'Ya, Tidak Perpanjang' : 'Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _cancelling = true);
    final result = await UserRepository.cancelBillingOrder(
      billingId: billing.id,
      keepDueDateIfPaid: isPaid,
      paidUntil: isPaid ? activeUntil : null,
    );
    if (!mounted) return;
    setState(() => _cancelling = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Gagal membatalkan order')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPaid
              ? 'Sewa tidak diperpanjang. Masa aktif tetap sampai ${formatShortDate(activeUntil)}.'
              : widget.cancellationMeansStopRenewal
                  ? 'Sewa tidak diperpanjang. Masa aktif tetap sampai ${formatShortDate(activeUntil)}.'
              : 'Order berhasil dibatalkan.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _payNow() async {
    if (_paying || !_billing.canPay) return;
    setState(() => _paying = true);

    final messenger = ScaffoldMessenger.of(context);
    final billing = _billing;
    final result = await UserRepository.createMidtransPayment(
      orderId: billing.id,
      amount: billing.amount,
      customerName: 'Pelanggan Kos',
      customerEmail: 'customer@example.com',
      paymentMethod: _method,
    );

    if (!mounted) return;
    setState(() => _paying = false);

    if (!result.isSuccess) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.error ?? 'Gagal membuat pembayaran Midtrans')),
      );
      return;
    }

    final paymentData = result.data ?? {};
    final paymentUrl = paymentData['payment_url'] as String?;
    final billingId = paymentData['billing_id'] as String?;
    final midtransOrderId = paymentData['order_id'] as String?;
    final instructions = paymentData['instruction'] as String?;
    if (billingId != null && billingId.isNotEmpty) {
      _billingLookupId = billingId;
    }
    if (midtransOrderId != null && midtransOrderId.isNotEmpty) {
      _lastMidtransOrderId = midtransOrderId;
    }

    if (paymentUrl != null && paymentUrl.isNotEmpty) {
      final launched = await launchUrlString(paymentUrl);
      if (!launched) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Gagal membuka halaman pembayaran')),
        );
      }
      if (midtransOrderId != null && midtransOrderId.isNotEmpty) {
        await _pollPaymentStatus(midtransOrderId);
      } else {
        await _reloadBilling();
      }
      return;
    }

    final message = instructions ?? 'Transaksi Midtrans berhasil dibuat.';
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _isPastPaymentWindow(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastPayDay = DateTime(dueDate.year, dueDate.month, dueDate.day)
        .add(const Duration(days: 1));
    return today.isAfter(lastPayDay);
  }

  @override
  Widget build(BuildContext context) {
    final billing = _billing;
    final isPaid = billing.isPaid;
    final isCancelled = billing.isCancelled;
    final paymentWindowBase =
        widget.activeUntilForStopRenewal ?? billing.activeUntil ?? billing.dueDate;
    final isPastPaymentWindow =
        billing.canPay && _isPastPaymentWindow(paymentWindowBase);
    final paymentLimitDate =
        paymentWindowBase.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detail Tagihan',
              style: TextStyle(
                color: UserTheme.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              billing.itemDescription,
              style: const TextStyle(color: UserTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        children: [
          Container(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Tagihan',
                            style: TextStyle(
                              color: UserTheme.muted,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatUserCurrency(billing.amount),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: UserTheme.primaryDark,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: billing.status),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F1F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPaid
                            ? Icons.event_available_rounded
                            : Icons.event_busy_rounded,
                        color: isPaid ? UserTheme.success : UserTheme.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        billing.canPay
                            ? 'Batas bayar: ${formatShortDate(paymentLimitDate)}'
                            : 'Masa aktif: ${formatShortDate(paymentWindowBase)}',
                        style: const TextStyle(
                          color: UserTheme.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rincian Biaya',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: UserTheme.text,
                      ),
                ),
              ),
              const Icon(Icons.info_outline_rounded, color: UserTheme.muted),
            ],
          ),
          const SizedBox(height: 16),
          _PropertySummary(billing: billing),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [UserTheme.softShadow(opacity: 0.05)],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.bed_rounded,
                    color: UserTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sewa Kamar',
                        style: TextStyle(
                          color: UserTheme.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          billing.kosName ?? 'Nama kos belum terhubung',
                          if ((billing.kosAccessCode ?? '').isNotEmpty)
                            'Kode ${billing.kosAccessCode}',
                          if ((billing.roomNumber ?? '').isNotEmpty)
                            'Kamar ${billing.roomNumber}',
                          if ((billing.roomType ?? '').isNotEmpty)
                            billing.roomType!,
                        ].join(' - '),
                        style: const TextStyle(color: UserTheme.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatUserCurrency(billing.amount),
                  style: const TextStyle(
                    color: UserTheme.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Pilih Metode Pembayaran',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: UserTheme.text,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [UserTheme.softShadow(opacity: 0.05)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Metode pembayaran terakhir',
                  style: TextStyle(
                    color: UserTheme.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                _PaymentMethodCard(
                  title: _method,
                  subtitle: 'Sesuai pilihan terakhir Anda',
                  icon: Icons.history_rounded,
                  selected: true,
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                const Text(
                  'Semua metode pembayaran',
                  style: TextStyle(
                    color: UserTheme.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                _PaymentMethodCard(
                  title: 'GoPay QRIS',
                  subtitle: 'QRIS untuk GoPay, OVO, Dana',
                  icon: Icons.qr_code_2_rounded,
                  selected: _method == 'GoPay QRIS',
                  onTap: () => setState(() => _method = 'GoPay QRIS'),
                ),
                const SizedBox(height: 12),
                _PaymentMethodCard(
                  title: 'Virtual Account',
                  subtitle: 'BCA, Mandiri, BNI, BRI, Danamon',
                  icon: Icons.account_balance_rounded,
                  selected: _method == 'Virtual Account',
                  onTap: () => setState(() => _method = 'Virtual Account'),
                ),
                const SizedBox(height: 12),
                _PaymentMethodCard(
                  title: 'Kartu Kredit / Debit',
                  subtitle: 'Visa, Mastercard, JCB',
                  icon: Icons.credit_card_rounded,
                  selected: _method == 'Kartu Kredit / Debit',
                  onTap: () => setState(() => _method = 'Kartu Kredit / Debit'),
                ),
                const SizedBox(height: 12),
                _PaymentMethodCard(
                  title: 'ShopeePay QRIS',
                  subtitle: 'Bayar cepat lewat ShopeePay',
                  icon: Icons.shopping_bag_rounded,
                  selected: _method == 'ShopeePay QRIS',
                  onTap: () => setState(() => _method = 'ShopeePay QRIS'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (widget.actionsEnabled) ...[
            FilledButton(
              onPressed: !billing.canPay || isPastPaymentWindow || _paying
                  ? null
                  : _payNow,
              style: FilledButton.styleFrom(
                backgroundColor: UserTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _paying
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(isPaid
                      ? 'Sudah Dibayar'
                      : isCancelled
                          ? 'Dibatalkan'
                          : 'Bayar Sekarang'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isCancelled ||
                        (billing.canPay && isPastPaymentWindow) ||
                        _cancelling
                    ? null
                    : _cancelOrder,
                style: OutlinedButton.styleFrom(
                  foregroundColor: UserTheme.danger,
                  side: BorderSide(color: UserTheme.danger.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _cancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isCancelled
                        ? 'Order Dibatalkan'
                        : isPaid || widget.cancellationMeansStopRenewal
                            ? 'Tidak Perpanjang'
                            : 'Batalkan Order'),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Dengan menekan tombol, Anda menyetujui syarat & ketentuan layanan Sentra Ruang.',
              textAlign: TextAlign.center,
              style: TextStyle(color: UserTheme.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE8F5FF) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8F5FF) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? UserTheme.primaryDark : const Color(0xFFE7E8EE),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? UserTheme.primaryDark : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: selected ? Colors.white : UserTheme.primaryDark, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: UserTheme.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: UserTheme.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? UserTheme.primaryDark : UserTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertySummary extends StatelessWidget {
  const _PropertySummary({required this.billing});

  final BillingRecord billing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [UserTheme.softShadow(opacity: 0.05)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.home_work_outlined, color: UserTheme.primaryDark),
              SizedBox(width: 8),
              Text(
                'Data Kos & Kamar',
                style: TextStyle(
                  color: UserTheme.primaryDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailInfoRow(
            label: 'Nama Kos',
            value: billing.kosName ?? 'Belum terhubung',
          ),
          _DetailInfoRow(
            label: 'Kode Kos',
            value: billing.kosAccessCode ?? '-',
          ),
          _DetailInfoRow(
            label: 'No Kamar',
            value: billing.roomNumber ?? '-',
          ),
          _DetailInfoRow(
            label: 'Tipe Kamar',
            value: billing.roomType ?? '-',
          ),
          _DetailInfoRow(label: 'Periode', value: billing.itemDescription),
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              label,
              style: const TextStyle(color: UserTheme.muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: UserTheme.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final paid = status == 'lunas';
    final cancelled = status == 'dibatalkan';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: paid
            ? const Color(0xFFDDF8E8)
            : cancelled
                ? const Color(0xFFE6E8EE)
                : const Color(0xFFFFD7D4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        paid
            ? 'Lunas'
            : cancelled
                ? 'Dibatalkan'
                : 'Belum Bayar',
        style: TextStyle(
          color: paid
              ? UserTheme.success
              : cancelled
                  ? UserTheme.muted
                  : UserTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
