import 'package:flutter/material.dart';

import '../../data/repositories/user_repository.dart';
import '../../models/billing_record.dart';
import '../user/user_theme.dart';
import '../user/user_widgets.dart';

class BillingDetailPage extends StatefulWidget {
  const BillingDetailPage({super.key, required this.billing});

  final BillingRecord billing;

  @override
  State<BillingDetailPage> createState() => _BillingDetailPageState();
}

class _BillingDetailPageState extends State<BillingDetailPage> {
  String _method = 'Transfer Bank BCA';
  late BillingRecord _billing;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _billing = widget.billing;
  }

  Future<void> _submitPayment() async {
    setState(() => _submitting = true);
    final result = await UserRepository.submitBillingPayment(
      billing: _billing,
      paymentMethod: _method,
    );
    if (!mounted) return;

    setState(() {
      _billing = result.data ?? _billing.copyWith(status: 'pending');
      _submitting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pembayaran dikirim. Menunggu persetujuan owner.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billing = _billing;
    final isPaid = billing.isPaid;
    final isPending = billing.isPending;

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
                        'Jatuh tempo: ${formatShortDate(billing.dueDate)}',
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
            'Metode Pembayaran',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: UserTheme.text,
                ),
          ),
          const SizedBox(height: 14),
          _PaymentMethodTile(
            label: 'Transfer Bank BCA',
            icon: Icons.account_balance_rounded,
            selected: _method == 'Transfer Bank BCA',
            onTap: () => setState(() => _method = 'Transfer Bank BCA'),
          ),
          _PaymentMethodTile(
            label: 'QRIS (GoPay, OVO, Dana)',
            icon: Icons.qr_code_rounded,
            selected: _method == 'QRIS',
            onTap: () => setState(() => _method = 'QRIS'),
          ),
          _PaymentMethodTile(
            label: 'Mandiri Virtual Account',
            icon: Icons.credit_card_rounded,
            selected: _method == 'Mandiri Virtual Account',
            onTap: () => setState(() => _method = 'Mandiri Virtual Account'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed:
                isPaid || isPending || _submitting ? null : _submitPayment,
            style: FilledButton.styleFrom(
              backgroundColor: UserTheme.primaryDark,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              isPaid
                  ? 'Pembayaran Berhasil'
                  : isPending
                      ? 'Menunggu Persetujuan Owner'
                      : _submitting
                          ? 'Mengirim Pembayaran...'
                          : 'Bayar Sekarang',
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Dengan menekan tombol, Anda menyetujui syarat & ketentuan layanan Sentra Ruang.',
            textAlign: TextAlign.center,
            style: TextStyle(color: UserTheme.muted, fontSize: 12),
          ),
        ],
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

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? UserTheme.primaryDark : Colors.transparent,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(icon, color: UserTheme.primaryDark, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: UserTheme.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? UserTheme.primaryDark : UserTheme.muted,
                ),
              ],
            ),
          ),
        ),
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
    final pending = status == 'pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: paid
            ? const Color(0xFFDDF8E8)
            : pending
                ? const Color(0xFFDCEBFF)
                : const Color(0xFFFFD7D4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        paid
            ? 'Berhasil'
            : pending
                ? 'Pending'
                : 'Belum Bayar',
        style: TextStyle(
          color: paid
              ? UserTheme.success
              : pending
                  ? UserTheme.primary
                  : UserTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
