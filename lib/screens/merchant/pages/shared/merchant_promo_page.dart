import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/merchant_models.dart';
import '../../merchant_ui.dart';

class MerchantPromoPage extends StatefulWidget {
  const MerchantPromoPage({super.key});

  @override
  State<MerchantPromoPage> createState() => _MerchantPromoPageState();
}

class _MerchantPromoPageState extends State<MerchantPromoPage> {
  List<MerchantPromo> _promos = [];
  List<MerchantProduct> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final promos = await MerchantRepository.getPromos();
    final products = await MerchantRepository.getProducts();
    if (!mounted) return;
    setState(() {
      _promos = promos.data ?? [];
      _products = products.data ?? [];
      _error = promos.error ?? products.error;
      _loading = false;
    });
  }

  Future<void> _openForm([MerchantPromo? promo]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PromoForm(
        promo: promo,
        products: _products,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _disable(MerchantPromo promo) async {
    final result = await MerchantRepository.deletePromo(promo.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isSuccess
            ? 'Promo dinonaktifkan'
            : result.error ?? 'Gagal menonaktifkan promo'),
      ),
    );
    if (result.isSuccess) _load();
  }

  @override
  Widget build(BuildContext context) {
    final active = _promos.where((promo) => promo.status == 'active').length;
    final usage = _promos.fold<int>(0, (sum, promo) => sum + promo.usedCount);

    return MerchantPage(
      topBar: const MerchantTopBar(
        title: 'Promo Merchant',
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _PromoMetric(
                icon: Icons.campaign_outlined,
                title: 'Promo Aktif',
                value: active.toString(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _PromoMetric(
                icon: Icons.analytics_outlined,
                title: 'Penggunaan',
                value: usage.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _CreatePromoCard(onPressed: () => _openForm()),
        const SizedBox(height: 28),
        MerchantSectionHeader(
          title: 'Kelola Promo',
          trailing: MerchantStatusPill(
            label: '$active Aktif',
            color: MerchantPalette.primary,
            background: MerchantPalette.softBlue,
          ),
        ),
        const SizedBox(height: 18),
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
        else if (_promos.isEmpty)
          const MerchantCard(
            child: Text(
              'Belum ada promo. Tambahkan promo dengan batas waktu dan batas diskon yang sehat.',
              style: TextStyle(color: MerchantPalette.muted),
            ),
          )
        else
          ..._promos.map(
            (promo) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _PromoCard(
                promo: promo,
                onEdit: () => _openForm(promo),
                onDisable: () => _disable(promo),
              ),
            ),
          ),
        const MerchantBottomSpacer(),
      ],
    );
  }
}

class _PromoMetric extends StatelessWidget {
  const _PromoMetric({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MerchantPalette.primary, size: 26),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: MerchantPalette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: MerchantPalette.text,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePromoCard extends StatelessWidget {
  const _CreatePromoCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      color: MerchantPalette.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tambah Promo Baru',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Promo dibatasi oleh minimal transaksi, batas diskon, periode aktif, dan limit penggunaan.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Buat Promo'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: MerchantPalette.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.promo,
    required this.onEdit,
    required this.onDisable,
  });

  final MerchantPromo promo;
  final VoidCallback onEdit;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final expired = promo.status == 'expired' || !promo.isActive;
    return MerchantCard(
      color: expired ? const Color(0xFFE3E5EA) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MerchantStatusPill(
                label: _statusLabel(promo.status),
                color: _statusColor(promo.status),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                color: MerchantPalette.muted,
              ),
              IconButton(
                onPressed: onDisable,
                icon: const Icon(Icons.pause_circle_outline_rounded),
                color: MerchantPalette.muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            promo.name,
            style: TextStyle(
              color: expired ? const Color(0xFF757D8A) : MerchantPalette.text,
              fontSize: 20,
              decoration: expired ? TextDecoration.lineThrough : null,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            promo.description,
            style: const TextStyle(color: MerchantPalette.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          _PromoMeta(
            icon: Icons.sell_outlined,
            text:
                '${promo.discountType == 'percentage' ? '${promo.discountValue.toStringAsFixed(0)}%' : formatMerchantCurrency(promo.discountValue)} untuk ${promo.targetLabel}',
          ),
          const SizedBox(height: 8),
          _PromoMeta(
            icon: Icons.price_check_outlined,
            text:
                'Min ${formatMerchantCurrency(promo.minOrderAmount)} - Maks diskon ${formatMerchantCurrency(promo.maxDiscountAmount)}',
          ),
          const SizedBox(height: 8),
          _PromoMeta(
            icon: Icons.calendar_today_outlined,
            text: '${_date(promo.startAt)} - ${_date(promo.endAt)}',
          ),
        ],
      ),
    );
  }

  String _date(DateTime? date) {
    if (date == null) return 'Tidak dibatasi';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}

class _PromoMeta extends StatelessWidget {
  const _PromoMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: MerchantPalette.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: MerchantPalette.muted),
          ),
        ),
      ],
    );
  }
}

class _PromoForm extends StatefulWidget {
  const _PromoForm({
    required this.products,
    this.promo,
  });

  final List<MerchantProduct> products;
  final MerchantPromo? promo;

  @override
  State<_PromoForm> createState() => _PromoFormState();
}

class _PromoFormState extends State<_PromoForm> {
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _minOrderCtrl = TextEditingController();
  final _maxDiscountCtrl = TextEditingController();
  final _usageLimitCtrl = TextEditingController();
  final _perUserLimitCtrl = TextEditingController(text: '1');
  final _sampleSubtotalCtrl = TextEditingController(text: '150000');

  bool _targetAllProducts = true;
  final Set<String> _selectedProductIds = {};
  String _discountType = 'percentage';
  DateTime? _startAt = DateTime.now();
  DateTime? _endAt = DateTime.now().add(const Duration(days: 14));
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);
  bool _isActive = true;
  bool _saving = false;
  Timer? _previewDebounce;
  bool _previewLoading = false;
  String? _previewMessage;
  Map<String, dynamic>? _previewData;

  double get _discountValue => _number(_discountCtrl.text);
  double get _minOrderValue => _number(_minOrderCtrl.text);
  double get _maxDiscountValue => _number(_maxDiscountCtrl.text);
  double get _sampleSubtotalValue => _number(_sampleSubtotalCtrl.text);
  int? get _usageLimitValue =>
      _usageLimitCtrl.text.trim().isEmpty ? null : int.tryParse(_usageLimitCtrl.text.trim());
  int get _perUserLimitValue =>
      int.tryParse(_perUserLimitCtrl.text.trim()) ?? 1;

  @override
  void initState() {
    super.initState();
    final promo = widget.promo;
    _nameCtrl.text = promo?.name ?? '';
    _descriptionCtrl.text = promo?.description ?? '';
    _discountCtrl.text =
        promo == null ? '' : promo.discountValue.toStringAsFixed(0);
    _minOrderCtrl.text =
        promo == null ? '' : promo.minOrderAmount.toStringAsFixed(0);
    _maxDiscountCtrl.text =
        promo == null ? '' : promo.maxDiscountAmount.toStringAsFixed(0);
    _usageLimitCtrl.text = promo?.usageLimit?.toString() ?? '';
    _perUserLimitCtrl.text = (promo?.perUserUsageLimit ?? 1).toString();
    if (promo != null) {
      _targetAllProducts = promo.targetsAllProducts;
      _selectedProductIds
        ..clear()
        ..addAll(promo.productIds);
    }
    _discountType = promo?.discountType ?? 'percentage';
    _startAt = promo?.startAt ?? _startAt;
    _endAt = promo?.endAt ?? _endAt;
    if (_startAt != null) {
      _startTime = TimeOfDay.fromDateTime(_startAt!);
    }
    if (_endAt != null) {
      _endTime = TimeOfDay.fromDateTime(_endAt!);
    }
    if (promo != null && promo.minOrderAmount > 0) {
      _sampleSubtotalCtrl.text = promo.minOrderAmount >= 150000
          ? promo.minOrderAmount.toStringAsFixed(0)
          : '150000';
    }
    _isActive = promo?.isActive ?? true;
    _nameCtrl.addListener(_onPreviewInputChanged);
    _discountCtrl.addListener(_onPreviewInputChanged);
    _minOrderCtrl.addListener(_onPreviewInputChanged);
    _maxDiscountCtrl.addListener(_onPreviewInputChanged);
    _sampleSubtotalCtrl.addListener(_onPreviewInputChanged);
    _schedulePreview(immediate: true);
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _nameCtrl.removeListener(_onPreviewInputChanged);
    _discountCtrl.removeListener(_onPreviewInputChanged);
    _minOrderCtrl.removeListener(_onPreviewInputChanged);
    _maxDiscountCtrl.removeListener(_onPreviewInputChanged);
    _sampleSubtotalCtrl.removeListener(_onPreviewInputChanged);
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _discountCtrl.dispose();
    _minOrderCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _usageLimitCtrl.dispose();
    _perUserLimitCtrl.dispose();
    _sampleSubtotalCtrl.dispose();
    super.dispose();
  }

  void _onPreviewInputChanged() => _schedulePreview();

  void _schedulePreview({bool immediate = false}) {
    _previewDebounce?.cancel();
    if (immediate) {
      _fetchPreview();
      return;
    }
    _previewDebounce = Timer(const Duration(milliseconds: 350), _fetchPreview);
  }

  Future<void> _fetchPreview() async {
    if (!mounted) return;
    final sampleSubtotal = _sampleSubtotalValue > 0
        ? _sampleSubtotalValue
        : (_minOrderValue > 0 ? _minOrderValue : 150000.0);
    if (_discountValue <= 0) {
      setState(() {
        _previewData = null;
        _previewMessage = 'Isi nilai diskon untuk melihat preview.';
        _previewLoading = false;
      });
      return;
    }

    setState(() {
      _previewLoading = true;
      _previewMessage = null;
    });

    final productIds = _targetAllProducts
        ? <String>[]
        : _selectedProductIds.toList();

    final result = await MerchantRepository.previewPromo(
      subtotal: sampleSubtotal,
      productIds: productIds,
      discountType: _discountType,
      discountValue: _discountValue,
      minOrderAmount: _minOrderValue,
      maxDiscountAmount:
          _discountType == 'percentage' ? _maxDiscountValue : 0,
      name: _nameCtrl.text.trim().isEmpty ? 'Draft Promo' : _nameCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _previewLoading = false;
      if (result.isSuccess) {
        _previewData = result.data;
        _previewMessage = (result.data?['message'] as String?)?.trim();
      } else {
        _previewData = null;
        _previewMessage = result.error ?? 'Preview promo belum tersedia.';
      }
    });
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDateTime(bool start) async {
    final initial = start ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (time == null) return;
    setState(() {
      if (start) {
        _startTime = time;
        _startAt = _combineDateTime(date, time);
      } else {
        _endTime = time;
        _endAt = _combineDateTime(date, time);
      }
    });
  }

  Future<void> _pickProducts() async {
    var searchQuery = '';
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final draft = Set<String>.from(_selectedProductIds);
        final searchCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = widget.products.where((product) {
              if (searchQuery.isEmpty) return true;
              return product.name.toLowerCase().contains(searchQuery);
            }).toList();
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Produk Promo',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    decoration: _decoration('Cari produk'),
                    onChanged: (value) {
                      setModalState(() {
                        searchQuery = value.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        final product = filtered[index];
                        final checked = draft.contains(product.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (value) {
                            setModalState(() {
                              if (value == true) {
                                draft.add(product.id);
                              } else {
                                draft.remove(product.id);
                              }
                            });
                          },
                          title: Text(product.name),
                          subtitle: Text(formatMerchantCurrency(product.price)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, draft),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: MerchantPalette.primary,
                    ),
                    child: Text('Gunakan (${draft.length})'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (selected == null) return;
    setState(() {
      _selectedProductIds
        ..clear()
        ..addAll(selected);
    });
    _schedulePreview(immediate: true);
  }

  Future<void> _save() async {
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }
    setState(() => _saving = true);
    final productIds = _targetAllProducts ? <String>[] : _selectedProductIds.toList();
    final result = await MerchantRepository.savePromo(
      id: widget.promo?.id,
      name: _nameCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      productIds: productIds,
      discountType: _discountType,
      discountValue: _discountValue,
      minOrderAmount: _minOrderValue,
      maxDiscountAmount: _discountType == 'percentage' ? _maxDiscountValue : 0,
      startAt: _startAt,
      endAt: _endAt,
      isActive: _isActive,
      usageLimit: _usageLimitValue,
      perUserUsageLimit: _perUserLimitValue,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Gagal menyimpan promo')),
    );
  }

  double _number(String text) {
    return double.tryParse(text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
  }

  String? _validateForm() {
    if (_nameCtrl.text.trim().isEmpty) return 'Nama promo wajib diisi';
    if (!_targetAllProducts && _selectedProductIds.isEmpty) {
      return 'Pilih minimal satu produk untuk promo tertentu';
    }
    if (_discountValue <= 0) return 'Nilai diskon harus lebih dari 0';
    if (_discountType == 'percentage' && _discountValue > 100) {
      return 'Diskon persentase maksimal 100%';
    }
    if (_discountType == 'percentage' && _maxDiscountValue <= 0) {
      return 'Maksimal diskon wajib diisi untuk diskon persentase';
    }
    if (_minOrderValue < 0) return 'Minimal transaksi tidak valid';
    if (_usageLimitValue != null && (_usageLimitValue ?? 0) <= 0) {
      return 'Kuota Promo harus lebih dari 0';
    }
    if (_perUserLimitValue <= 0) {
      return 'Batas penggunaan per user minimal 1';
    }
    if (_startAt != null && _endAt != null && !_endAt!.isAfter(_startAt!)) {
      return 'Tanggal akhir harus lebih besar dari tanggal mulai';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.promo == null ? 'Buat Promo Baru' : 'Edit Promo',
              style: const TextStyle(
                color: MerchantPalette.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            const Text('SECTION 1 — INFORMASI PROMO',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 10),
            _Input(controller: _nameCtrl, label: 'Nama Promo'),
            const SizedBox(height: 14),
            _Input(
              controller: _descriptionCtrl,
              label: 'Deskripsi Promo',
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            const Text('SECTION 2 — TARGET PRODUK',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Semua')),
                ButtonSegment(value: false, label: Text('Produk tertentu')),
              ],
              selected: {_targetAllProducts},
              onSelectionChanged: (value) {
                setState(() => _targetAllProducts = value.first);
                _schedulePreview(immediate: true);
              },
            ),
            if (!_targetAllProducts) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: widget.products.isEmpty ? null : _pickProducts,
                icon: const Icon(Icons.checklist_rounded),
                label: Text(
                  _selectedProductIds.isEmpty
                      ? 'Pilih produk'
                      : '${_selectedProductIds.length} produk dipilih',
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text('SECTION 3 — JENIS DISKON',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _discountType,
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text('Persen')),
                DropdownMenuItem(value: 'fixed', child: Text('Nominal')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _discountType = value);
                  _schedulePreview(immediate: true);
                }
              },
              decoration: _decoration('Tipe Diskon'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Input(
                    controller: _discountCtrl,
                    label: _discountType == 'percentage'
                        ? 'Nilai Diskon (%)'
                        : 'Nominal Potongan',
                    keyboardType: TextInputType.number,
                  ),
                ),
                if (_discountType == 'percentage') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Input(
                      controller: _maxDiscountCtrl,
                      label: 'Maksimal Diskon',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            const Text('SECTION 4 — SYARAT PROMO',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Input(
                    controller: _minOrderCtrl,
                    label: 'Minimal Transaksi',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Input(
                    controller: _usageLimitCtrl,
                    label: 'Kuota Promo (global)',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Input(
                    controller: _perUserLimitCtrl,
                    label: 'Batas per User',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Input(
                    controller: _sampleSubtotalCtrl,
                    label: 'Simulasi Subtotal',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _FieldHelper(
              'Kuota global membatasi total pemakaian promo. Batas per user mencegah penyalahgunaan.',
            ),
            const SizedBox(height: 14),
            const Text('SECTION 5 — PERIODE PROMO',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(true),
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text('Mulai ${_dateTime(_startAt)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(false),
                    icon: const Icon(Icons.event_busy_rounded),
                    label: Text('Akhir ${_dateTime(_endAt)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _isActive,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) => setState(() => _isActive = value),
              title: const Text('Aktifkan promo'),
            ),
            const SizedBox(height: 8),
            _PromoRealtimePreview(
              discountType: _discountType,
              discountValue: _discountValue,
              minOrderAmount: _minOrderValue,
              maxDiscountAmount:
                  _discountType == 'percentage' ? _maxDiscountValue : 0,
              loading: _previewLoading,
              previewData: _previewData,
              previewMessage: _previewMessage,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: MerchantPalette.primary,
              ),
              child: Text(_saving ? 'Menyimpan...' : 'Simpan Promo'),
            ),
          ],
        ),
      ),
    );
  }

  String _dateTime(DateTime? date) {
    if (date == null) return '-';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} $hour:$minute';
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _decoration(label),
    );
  }
}

class _FieldHelper extends StatelessWidget {
  const _FieldHelper(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: MerchantPalette.muted,
        fontSize: 12,
        height: 1.3,
      ),
    );
  }
}

class _PromoRealtimePreview extends StatelessWidget {
  const _PromoRealtimePreview({
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    required this.maxDiscountAmount,
    required this.loading,
    required this.previewData,
    required this.previewMessage,
  });

  final String discountType;
  final double discountValue;
  final double minOrderAmount;
  final double maxDiscountAmount;
  final bool loading;
  final Map<String, dynamic>? previewData;
  final String? previewMessage;

  @override
  Widget build(BuildContext context) {
    final subtotal = (previewData?['subtotal'] as num?)?.toDouble() ?? 150000.0;
    double discount = 0;
    if (previewData != null) {
      discount = (previewData?['discountAmount'] as num?)?.toDouble() ?? 0;
    } else if (discountType == 'percentage') {
      discount = subtotal * discountValue / 100;
      if (maxDiscountAmount > 0) discount = discount > maxDiscountAmount ? maxDiscountAmount : discount;
    } else {
      discount = discountValue;
    }
    if (discount > subtotal) discount = subtotal;
    final total = (previewData?['total'] as num?)?.toDouble() ?? (subtotal - discount);
    final minMet = subtotal >= minOrderAmount;

    return MerchantCard(
      color: MerchantPalette.softBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SECTION 6 — PREVIEW REALTIME',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (loading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 10),
          ],
          Text('Subtotal: ${formatMerchantCurrency(subtotal)}'),
          Text('Diskon: ${discountType == 'percentage' ? '${discountValue.toStringAsFixed(0)}%' : formatMerchantCurrency(discountValue)}'),
          Text('Potongan: ${formatMerchantCurrency(discount)}'),
          Text(
            'Total Bayar: ${formatMerchantCurrency(total)}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          if (!minMet) ...[
            const SizedBox(height: 8),
            Text(
              'Warning: minimum transaksi belum terpenuhi.',
              style: TextStyle(
                color: MerchantPalette.warning.withValues(alpha: 0.95),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (previewMessage != null && previewMessage!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              previewMessage!,
              style: const TextStyle(
                color: MerchantPalette.muted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

InputDecoration _decoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}

String _statusLabel(String status) {
  switch (status) {
    case 'active':
      return 'AKTIF';
    case 'expired':
      return 'BERAKHIR';
    case 'paused':
      return 'NONAKTIF';
    default:
      return 'TERJADWAL';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'active':
      return MerchantPalette.success;
    case 'expired':
      return MerchantPalette.muted;
    case 'paused':
      return MerchantPalette.warning;
    default:
      return MerchantPalette.primary;
  }
}
