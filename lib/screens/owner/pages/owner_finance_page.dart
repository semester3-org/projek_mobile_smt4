import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

// Enum sesuai DB: unpaid, paid, overdue
enum PaymentStatus { unpaid, paid, overdue }

extension PaymentStatusExt on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'Berhasil';
      case PaymentStatus.unpaid:
        return 'Tertunda';
      case PaymentStatus.overdue:
        return 'Jatuh Tempo';
    }
  }

  String get dbValue {
    switch (this) {
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.unpaid:
        return 'unpaid';
      case PaymentStatus.overdue:
        return 'overdue';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.paid:
        return AppTheme.primaryGreen;
      case PaymentStatus.unpaid:
        return const Color(0xFFEF6C00);
      case PaymentStatus.overdue:
        return Colors.red;
    }
  }
}

// Model sesuai tabel payment_history JOIN room_registrations JOIN kos_rooms JOIN users
class _PaymentItem {
  const _PaymentItem({
    required this.id,
    required this.registrationId,
    required this.tenantName,
    required this.roomNumber,
    required this.kosTitle,
    required this.amount,
    required this.periodMonth,
    required this.paymentStatus,
    this.paymentMethod,
    this.proofUrl,
    this.paidAt,
  });

  final int id;                      // payment_history.id
  final String registrationId;       // payment_history.registration_id (FK)
  final String tenantName;           // JOIN users.display_name
  final String roomNumber;           // JOIN kos_rooms.room_number
  final String kosTitle;             // JOIN kos_listings.title
  final int amount;                  // payment_history.amount
  final String periodMonth;          // payment_history.period_month (YYYY-MM)
  final PaymentStatus paymentStatus; // payment_history.payment_status
  final String? paymentMethod;       // payment_history.payment_method
  final String? proofUrl;            // payment_history.proof_url
  final String? paidAt;              // payment_history.paid_at
}

class OwnerFinancePage extends StatefulWidget {
  const OwnerFinancePage({super.key});

  @override
  State<OwnerFinancePage> createState() => _OwnerFinancePageState();
}

class _OwnerFinancePageState extends State<OwnerFinancePage> {
  int _tab = 0;
  PaymentStatus? _filterStatus;
  String _filterKosId = 'semua';

  // Data dummy sesuai struktur payment_history
  final _payments = const <_PaymentItem>[
    _PaymentItem(
      id: 1,
      registrationId: 'reg_001',
      tenantName: 'Budi Santoso',
      roomNumber: 'A01',
      kosTitle: 'Kos Hijau Asri',
      amount: 1500000,
      periodMonth: '2026-04',
      paymentStatus: PaymentStatus.paid,
      paymentMethod: 'transfer',
      paidAt: '2026-04-03',
    ),
    _PaymentItem(
      id: 2,
      registrationId: 'reg_002',
      tenantName: 'Dian Permata',
      roomNumber: 'A12',
      kosTitle: 'Kos Hijau Asri',
      amount: 1500000,
      periodMonth: '2026-04',
      paymentStatus: PaymentStatus.paid,
      paymentMethod: 'transfer',
      paidAt: '2026-04-05',
    ),
    _PaymentItem(
      id: 3,
      registrationId: 'reg_003',
      tenantName: 'Randy Panglila',
      roomNumber: 'B01',
      kosTitle: 'Kost Minimalis Putih',
      amount: 950000,
      periodMonth: '2026-04',
      paymentStatus: PaymentStatus.unpaid,
      paymentMethod: null,
      paidAt: null,
    ),
    _PaymentItem(
      id: 4,
      registrationId: 'reg_004',
      tenantName: 'Siti Aminah',
      roomNumber: 'B05',
      kosTitle: 'Green House Residence',
      amount: 2200000,
      periodMonth: '2026-04',
      paymentStatus: PaymentStatus.paid,
      paymentMethod: 'cash',
      paidAt: '2026-04-01',
    ),
    _PaymentItem(
      id: 5,
      registrationId: 'reg_005',
      tenantName: 'Andi Saputra',
      roomNumber: 'C01',
      kosTitle: 'Green House Residence',
      amount: 3500000,
      periodMonth: '2026-03',
      paymentStatus: PaymentStatus.overdue,
      paymentMethod: null,
      paidAt: null,
    ),
  ];

  List<_PaymentItem> get _filtered {
    return _payments.where((p) {
      if (_filterStatus != null && p.paymentStatus != _filterStatus) {
        return false;
      }
      if (_filterKosId != 'semua' && p.kosTitle != _filterKosId) {
        return false;
      }
      return true;
    }).toList();
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filter Transaksi',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _filterStatus = null;
                          _filterKosId = 'semua';
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Status Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    (null, 'Semua'),
                    ...PaymentStatus.values.map((s) => (s as PaymentStatus?, s.label)),
                  ].map((e) => ChoiceChip(
                    label: Text(e.$2),
                    selected: _filterStatus == e.$1,
                    onSelected: (_) {
                      setModalState(() => _filterStatus = e.$1);
                    },
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Properti',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ('semua', 'Semua Properti'),
                    ('Kos Hijau Asri', 'Kos Hijau Asri'),
                    ('Kost Minimalis Putih', 'Kost Minimalis Putih'),
                    ('Green House Residence', 'Green House Residence'),
                  ].map((e) => ChoiceChip(
                    label: Text(e.$2),
                    selected: _filterKosId == e.$1,
                    onSelected: (_) {
                      setModalState(() => _filterKosId = e.$1);
                    },
                  )).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: const Text('Terapkan Filter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentDetail(BuildContext context, _PaymentItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Detail Pembayaran #${item.id}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18)),
                const Divider(height: 24),
                _DetailRow(label: 'registration_id', value: item.registrationId),
                _DetailRow(label: 'Penyewa', value: item.tenantName),
                _DetailRow(label: 'Kamar', value: '${item.roomNumber} • ${item.kosTitle}'),
                _DetailRow(label: 'period_month', value: item.periodMonth),
                _DetailRow(label: 'amount', value: _formatPrice(item.amount)),
                _DetailRow(label: 'payment_status', value: item.paymentStatus.dbValue),
                _DetailRow(label: 'payment_method', value: item.paymentMethod ?? '-'),
                _DetailRow(label: 'paid_at', value: item.paidAt ?? '-'),
                const SizedBox(height: 16),
                if (item.paymentStatus == PaymentStatus.unpaid ||
                    item.paymentStatus == PaymentStatus.overdue)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Fitur konfirmasi pembayaran coming soon!')),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Konfirmasi Pembayaran'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    return 'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  int get _totalPaid => _payments
      .where((p) => p.paymentStatus == PaymentStatus.paid)
      .fold(0, (sum, p) => sum + p.amount);

  @override
  Widget build(BuildContext context) {
    const tabs = ['Harian', 'Bulanan', 'Tahunan'];
    final filtered = _filtered;
    final hasActiveFilter = _filterStatus != null || _filterKosId != 'semua';

    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(title: const Text('Ringkasan Keuangan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          Text(
            'Pantau performa bisnis kos Anda secara real-time.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: List.generate(
                  tabs.length,
                  (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: i == _tab
                              ? AppTheme.primaryGreen.withOpacity(0.14)
                              : Colors.transparent,
                          foregroundColor: i == _tab
                              ? AppTheme.primaryGreen
                              : Colors.grey.shade700,
                        ),
                        onPressed: () => setState(() => _tab = i),
                        child: Text(tabs[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MoneyCard(
            title: 'Total Pemasukan (paid)',
            value: _formatPrice(_totalPaid),
            delta: '+12.5% vs bln lalu',
            icon: Icons.payments_rounded,
          ),
          const SizedBox(height: 12),
          // Ringkasan status pembayaran
          Row(
            children: [
              _StatusSummaryChip(
                label: 'Lunas',
                count: _payments
                    .where((p) => p.paymentStatus == PaymentStatus.paid)
                    .length,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(width: 8),
              _StatusSummaryChip(
                label: 'Tertunda',
                count: _payments
                    .where((p) => p.paymentStatus == PaymentStatus.unpaid)
                    .length,
                color: const Color(0xFFEF6C00),
              ),
              const SizedBox(width: 8),
              _StatusSummaryChip(
                label: 'Jatuh Tempo',
                count: _payments
                    .where((p) => p.paymentStatus == PaymentStatus.overdue)
                    .length,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pendapatan vs Transaksi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              TextButton(onPressed: () {}, child: const Text('Detail Laporan')),
            ],
          ),
          const SizedBox(height: 8),
          const _ChartStub(),
          const SizedBox(height: 12),
          const _EfficiencyCard(),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Riwayat Pembayaran',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              OutlinedButton.icon(
                onPressed: _showFilterDialog,
                icon: const Icon(Icons.filter_list_rounded),
                label: Text(hasActiveFilter ? 'Filter (Aktif)' : 'Filter'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...filtered.map((p) => _TxTile(
                payment: p,
                onTap: () => _showPaymentDetail(context, p),
              )),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () {},
              child: const Text('Muat Lebih Banyak'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSummaryChip extends StatelessWidget {
  const _StatusSummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: color, fontSize: 18)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.payment, required this.onTap});

  final _PaymentItem payment;
  final VoidCallback onTap;

  String _formatPrice(int price) {
    return 'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final status = payment.paymentStatus;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppTheme.surfaceTint,
          child: Icon(Icons.account_balance_rounded,
              color: AppTheme.primaryGreen),
        ),
        title: Text(payment.tenantName,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          'Kamar ${payment.roomNumber} • ${payment.kosTitle}\nPeriode: ${payment.periodMonth}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              status == PaymentStatus.paid
                  ? '+ ${_formatPrice(payment.amount)}'
                  : _formatPrice(payment.amount),
              style: TextStyle(
                  color: status.color, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: status.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status.label,
                style: TextStyle(
                    color: status.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade600, fontFamily: 'monospace')),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.title,
    required this.value,
    required this.delta,
    required this.icon,
  });

  final String title;
  final String value;
  final String delta;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.surfaceTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppTheme.primaryGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                  ),
                  const SizedBox(height: 4),
                  Text(delta,
                      style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartStub extends StatelessWidget {
  const _ChartStub();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 170,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final h = [0.55, 0.35, 0.75, 0.5, 0.22, 0.42, 0.32][i];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: 120 * h,
                        decoration: BoxDecoration(
                          color: i == 2
                              ? AppTheme.primaryGreen
                              : AppTheme.primaryGreen.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][i],
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _EfficiencyCard extends StatelessWidget {
  const _EfficiencyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E5AEF), Color(0xFF2B8BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const Text(
              '85%',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Efisiensi Hunian',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                const Text(
                  'Sangat Baik',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '17 dari 20 kamar terisi',
                  style:
                      TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }
}