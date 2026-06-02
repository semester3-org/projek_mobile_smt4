import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_theme.dart';
import '../../../core/api_service.dart';
import '../../../core/payment_methods.dart';

enum PaymentStatus { unpaid, paid, overdue }

extension PaymentStatusExt on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'Berhasil';
      case PaymentStatus.unpaid:
        return 'Menunggu';
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

  final int id;
  final String registrationId;
  final String tenantName;
  final String roomNumber;
  final String kosTitle;
  final int amount;
  final String periodMonth;
  final PaymentStatus paymentStatus;
  final String? paymentMethod;
  final String? proofUrl;
  final String? paidAt;

  _PaymentItem copyWith({
    PaymentStatus? paymentStatus,
    String? paymentMethod,
    String? paidAt,
  }) {
    return _PaymentItem(
      id: id,
      registrationId: registrationId,
      tenantName: tenantName,
      roomNumber: roomNumber,
      kosTitle: kosTitle,
      amount: amount,
      periodMonth: periodMonth,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      proofUrl: proofUrl,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}

class _ChartData {
  const _ChartData({
    required this.label,
    required this.value,
    required this.filterValue,
  });

  final String label;
  final double value;
  final String filterValue;
}

class OwnerFinancePage extends StatefulWidget {
  const OwnerFinancePage({super.key});

  @override
  State<OwnerFinancePage> createState() => _OwnerFinancePageState();
}

class _OwnerFinancePageState extends State<OwnerFinancePage> {
  int _tab = 0; // 0 = Harian, 1 = Bulanan, 2 = Tahunan
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _selectedYear = DateTime.now().year;
  PaymentStatus? _filterStatus;
  String _filterKosTitle = 'semua';

  bool _isLoading = true;
  String? _error;

  int _totalPaid = 0;
  int _paidCount = 0;
  int _unpaidCount = 0;
  int _overdueCount = 0;

  Map<String, dynamic> _occupancy = {
    'efficiency': 0,
    'occupied': 0,
    'total': 0,
  };

  Map<String, dynamic> _charts = {};
  List<_PaymentItem> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await ApiService.get(
      'api/owner_finance',
      queryParams: _financeQueryParams,
    );
    if (!mounted) return;

    if (!res.success) {
      setState(() {
        _isLoading = false;
        _error = res.message ?? 'Gagal memuat data keuangan';
      });
      return;
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      final summary = data['summary'] as Map<String, dynamic>;
      final occ = data['occupancy'] as Map<String, dynamic>;
      final ch = data['charts'] as Map<String, dynamic>;

      final list = data['payments'] as List<dynamic>;
      final List<_PaymentItem> mappedPayments = list.map((item) {
        final stVal = item['paymentStatus'] as String;
        PaymentStatus st = PaymentStatus.unpaid;
        if (stVal == 'paid') st = PaymentStatus.paid;
        if (stVal == 'overdue') st = PaymentStatus.overdue;

        return _PaymentItem(
          id: item['id'] as int,
          registrationId: item['registrationId'] as String,
          tenantName: item['tenantName'] as String,
          roomNumber: item['roomNumber'] as String,
          kosTitle: item['kosTitle'] as String,
          amount: item['amount'] as int,
          periodMonth: item['periodMonth'] as String,
          paymentStatus: st,
          paymentMethod: item['paymentMethod'] as String?,
          proofUrl: item['proofUrl'] as String?,
          paidAt: item['paidAt'] as String?,
        );
      }).toList();

      setState(() {
        _totalPaid = data['totalPaid'] as int;
        _paidCount = summary['paid'] as int;
        _unpaidCount = summary['unpaid'] as int;
        _overdueCount = summary['overdue'] as int;
        _occupancy = occ;
        _charts = ch;
        _payments = mappedPayments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Format data keuangan tidak valid';
      });
    }
  }

  List<_ChartData> get _chartData {
    if (_charts.isEmpty) return const [];
    final key = _tab == 1 ? 'monthly' : (_tab == 2 ? 'yearly' : 'daily');
    final list = _charts[key] as List<dynamic>? ?? const [];
    return list
        .map((e) => _ChartData(
              label: e['label'] as String,
              value: (e['proportion'] as num).toDouble(),
              filterValue: e['filterValue'] as String? ?? '',
            ))
        .toList();
  }

  Map<String, String> get _financeQueryParams {
    if (_tab == 1) {
      return {
        'period': 'month',
        'month': DateFormat('yyyy-MM').format(_selectedMonth),
      };
    }
    if (_tab == 2) {
      return {
        'period': 'year',
        'year': _selectedYear.toString(),
      };
    }
    return {
      'period': 'day',
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
    };
  }

  String get _periodLabel {
    if (_tab == 1) return DateFormat('MMMM yyyy').format(_selectedMonth);
    if (_tab == 2) return _selectedYear.toString();
    return DateFormat('d MMMM yyyy').format(_selectedDate);
  }

  String get _periodHelper {
    if (_tab == 1) return 'Keuntungan untuk bulan yang dipilih';
    if (_tab == 2) return 'Keuntungan untuk tahun yang dipilih';
    return 'Keuntungan untuk tanggal yang dipilih';
  }

  String get _periodActionLabel {
    if (_tab == 1) return 'Pilih Bulan';
    if (_tab == 2) return 'Pilih Tahun';
    return 'Pilih Tanggal';
  }

  Future<void> _setTab(int tab) async {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    await _loadFinanceData();
  }

  Future<void> _pickPeriod() async {
    if (_tab == 1) {
      final picked = await _showMonthPicker();
      if (picked == null || !mounted) return;
      setState(() => _selectedMonth = picked);
      await _loadFinanceData();
      return;
    }

    if (_tab == 2) {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime(_selectedYear),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
        initialDatePickerMode: DatePickerMode.year,
      );
      if (picked == null || !mounted) return;
      setState(() => _selectedYear = picked.year);
      await _loadFinanceData();
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
    await _loadFinanceData();
  }

  Future<DateTime?> _showMonthPicker() {
    var visibleYear = _selectedMonth.year;
    const monthNames = [
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

    return showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Bulan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih tahun, lalu pilih nama bulan.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Tahun sebelumnya',
                          onPressed: visibleYear <= 2000
                              ? null
                              : () => setSheetState(() => visibleYear--),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$visibleYear',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Tahun berikutnya',
                          onPressed: visibleYear >= 2100
                              ? null
                              : () => setSheetState(() => visibleYear++),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: monthNames.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.4,
                      ),
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final selected = visibleYear == _selectedMonth.year &&
                            month == _selectedMonth.month;
                        return FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: selected
                                ? AppTheme.primaryGreen.withValues(alpha: 0.16)
                                : Colors.grey.shade100,
                            foregroundColor: selected
                                ? AppTheme.primaryGreen
                                : Colors.grey.shade800,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(
                              DateTime(visibleYear, month),
                            );
                          },
                          child: Text(monthNames[index]),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectChartPeriod(_ChartData item) async {
    if (item.filterValue.isEmpty) return;
    if (_tab == 1) {
      final parts = item.filterValue.split('-');
      if (parts.length == 2) {
        setState(() {
          _selectedMonth = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        });
      }
    } else if (_tab == 2) {
      setState(() => _selectedYear = int.parse(item.filterValue));
    } else {
      setState(() => _selectedDate = DateTime.parse(item.filterValue));
    }
    await _loadFinanceData();
  }

  int get _highlightIndex {
    final data = _chartData;
    double max = 0;
    int idx = 0;
    for (int i = 0; i < data.length; i++) {
      if (data[i].value > max) {
        max = data[i].value;
        idx = i;
      }
    }
    return idx;
  }

  Future<void> _confirmPayment(_PaymentItem item) async {
    Navigator.pop(context); // Close details bottom sheet

    setState(() {
      _isLoading = true;
    });

    final res = await ApiService.put('api/owner_finance', {
      'paymentId': item.id,
    });

    if (!mounted) return;

    if (!res.success) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Gagal mengkonfirmasi pembayaran'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pembayaran ${item.tenantName} berhasil dikonfirmasi'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );

    await _loadFinanceData();
  }

  List<_PaymentItem> get _filtered {
    return _payments.where((p) {
      if (_filterStatus != null && p.paymentStatus != _filterStatus) {
        return false;
      }
      if (_filterKosTitle != 'semua' && p.kosTitle != _filterKosTitle) {
        return false;
      }
      return true;
    }).toList();
  }

  Set<String> get _uniqueKosTitles {
    return _payments.map((e) => e.kosTitle).toSet();
  }

  void _showFilterDialog() {
    final titles = _uniqueKosTitles.toList();
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
                          _filterKosTitle = 'semua';
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
                    ...PaymentStatus.values
                        .map((s) => (s as PaymentStatus?, s.label)),
                  ]
                      .map((e) => ChoiceChip(
                            label: Text(e.$2),
                            selected: _filterStatus == e.$1,
                            onSelected: (_) {
                              setModalState(() => _filterStatus = e.$1);
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text('Properti',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Semua Properti'),
                        selected: _filterKosTitle == 'semua',
                        onSelected: (_) {
                          setModalState(() => _filterKosTitle = 'semua');
                        },
                      ),
                      ...titles.map((t) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text(t),
                              selected: _filterKosTitle == t,
                              onSelected: (_) {
                                setModalState(() => _filterKosTitle = t);
                              },
                            ),
                          )),
                    ],
                  ),
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
                    width: 40,
                    height: 4,
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
                _DetailRow(label: 'ID Registrasi', value: item.registrationId),
                _DetailRow(label: 'Penyewa', value: item.tenantName),
                _DetailRow(
                    label: 'Kamar',
                    value: '${item.roomNumber} • ${item.kosTitle}'),
                _DetailRow(label: 'Periode Bulan', value: item.periodMonth),
                _DetailRow(label: 'Nominal', value: _formatPrice(item.amount)),
                _DetailRow(
                    label: 'Status Pembayaran',
                    value: item.paymentStatus.dbValue),
                _DetailRow(
                    label: 'Metode Pembayaran',
                    value:
                        PaymentMethodHelper.getDisplayName(item.paymentMethod)),
                _DetailRow(label: 'Waktu Bayar', value: item.paidAt ?? '-'),
                const SizedBox(height: 16),
                if (item.paymentStatus == PaymentStatus.unpaid ||
                    item.paymentStatus == PaymentStatus.overdue)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _confirmPayment(item),
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

  @override
  Widget build(BuildContext context) {
    const tabs = ['Harian', 'Bulanan', 'Tahunan'];
    final filtered = _filtered;
    final hasActiveFilter = _filterStatus != null || _filterKosTitle != 'semua';

    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(
        title: const Text('Ringkasan Keuangan'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadFinanceData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadFinanceData,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFinanceData,
                  color: AppTheme.primaryGreen,
                  child: ListView(
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
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: i == _tab
                                          ? AppTheme.primaryGreen
                                              .withValues(alpha: 0.14)
                                          : Colors.transparent,
                                      foregroundColor: i == _tab
                                          ? AppTheme.primaryGreen
                                          : Colors.grey.shade700,
                                    ),
                                    onPressed: () => _setTab(i),
                                    child: Text(tabs[i]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _periodLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _periodHelper,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: _periodActionLabel,
                                onPressed: _pickPeriod,
                                icon: const Icon(Icons.edit_calendar_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _MoneyCard(
                        title: 'Keuntungan Periode Ini',
                        value: _formatPrice(_totalPaid),
                        delta: 'Transaksi lunas pada $_periodLabel',
                        icon: Icons.payments_rounded,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatusSummaryChip(
                            label: 'Lunas',
                            count: _paidCount,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          _StatusSummaryChip(
                            label: 'Tertunda',
                            count: _unpaidCount,
                            color: const Color(0xFFEF6C00),
                          ),
                          const SizedBox(width: 8),
                          _StatusSummaryChip(
                            label: 'Jatuh Tempo',
                            count: _overdueCount,
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          TextButton(
                            onPressed: _pickPeriod,
                            child: Text(_periodActionLabel),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.05, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: _DynamicChart(
                          key: ValueKey(_tab),
                          data: _chartData,
                          highlightIndex: _highlightIndex,
                          onBarTap: _selectChartPeriod,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _EfficiencyCard(
                        efficiency: _occupancy['efficiency'] as int,
                        occupied: _occupancy['occupied'] as int,
                        total: _occupancy['total'] as int,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Riwayat Pembayaran',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _showFilterDialog,
                            icon: const Icon(Icons.filter_list_rounded),
                            label: Text(
                                hasActiveFilter ? 'Filter (Aktif)' : 'Filter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (filtered.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'Tidak ada riwayat transaksi yang cocok.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          ),
                        )
                      else
                        ...filtered.map((p) => _TxTile(
                              payment: p,
                              onTap: () => _showPaymentDetail(context, p),
                            )),
                    ],
                  ),
                ),
    );
  }
}

class _DynamicChart extends StatelessWidget {
  const _DynamicChart({
    super.key,
    required this.data,
    required this.highlightIndex,
    required this.onBarTap,
  });

  final List<_ChartData> data;
  final int highlightIndex;
  final ValueChanged<_ChartData> onBarTap;

  @override
  Widget build(BuildContext context) {
    final isScrollable = data.length > 7;

    final bars = List.generate(data.length, (i) {
      final item = data[i];
      final isHighlight = i == highlightIndex;
      return GestureDetector(
        onTap: () => onBarTap(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: isScrollable ? 40 : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  height: 120 * item.value,
                  decoration: BoxDecoration(
                    color: isHighlight
                        ? AppTheme.primaryGreen
                        : AppTheme.primaryGreen.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isHighlight
                        ? AppTheme.primaryGreen
                        : Colors.grey.shade700,
                    fontSize: isScrollable ? 10 : 12,
                    fontWeight:
                        isHighlight ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });

    return Card(
      child: SizedBox(
        height: 170,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: isScrollable
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: bars,
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: bars.map((b) => Expanded(child: b)).toList(),
                ),
        ),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$count',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: color, fontSize: 16)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
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
        leading: const CircleAvatar(
          backgroundColor: AppTheme.surfaceTint,
          child:
              Icon(Icons.account_balance_rounded, color: AppTheme.primaryGreen),
        ),
        title: Text(payment.tenantName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        subtitle: Text(
          'Kamar ${payment.roomNumber} • ${payment.kosTitle}\nPeriode: ${payment.periodMonth}',
          style: const TextStyle(fontSize: 12),
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
                  color: status.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status.label,
                style: TextStyle(
                    color: status.color,
                    fontSize: 10,
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
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                  fontSize: 12)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(delta,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EfficiencyCard extends StatelessWidget {
  const _EfficiencyCard({
    required this.efficiency,
    required this.occupied,
    required this.total,
  });

  final int efficiency;
  final int occupied;
  final int total;

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
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              '$efficiency%',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16),
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
                Text(
                  efficiency >= 80
                      ? 'Sangat Baik'
                      : (efficiency >= 50 ? 'Cukup Baik' : 'Perlu Promosi'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  '$occupied dari $total kamar terisi',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
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
