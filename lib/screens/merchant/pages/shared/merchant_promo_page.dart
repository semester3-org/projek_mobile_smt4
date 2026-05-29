import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/merchant_models.dart';
import '../../merchant_ui.dart';
import 'merchant_notifications_page.dart';

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
  String _filterStatus = 'all';

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

  Future<void> _openForm({MerchantPromo? promo, bool isDuplicate = false}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PromoForm(
        promo: promo,
        products: _products,
        isDuplicate: isDuplicate,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _updateStatus(MerchantPromo promo, String newStatus, bool isActive) async {
    final result = await MerchantRepository.savePromo(
      id: promo.id,
      name: promo.name,
      description: promo.description,
      productIds: promo.productIds,
      discountType: promo.discountType,
      discountValue: promo.discountValue,
      minOrderAmount: promo.minOrderAmount,
      maxDiscountAmount: promo.maxDiscountAmount,
      startAt: promo.startAt,
      endAt: promo.endAt,
      isActive: isActive,
      status: newStatus,
      usageLimit: promo.usageLimit,
      perUserUsageLimit: promo.perUserUsageLimit,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status promo diperbarui')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Gagal memperbarui status')),
      );
    }
  }

  Future<void> _delete(MerchantPromo promo) async {
    final result = await MerchantRepository.deletePromo(promo.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isSuccess
            ? 'Promo dihapus'
            : result.error ?? 'Gagal menghapus promo'),
      ),
    );
    if (result.isSuccess) _load();
  }

  String _effectiveStatus(MerchantPromo promo) {
    if (promo.status == 'expired' || (promo.endAt != null && promo.endAt!.isBefore(DateTime.now()))) {
      return 'expired';
    }
    // Jika backend terlambat mengupdate status string, percayakan pada field isActive
    if (promo.isActive) return 'active';
    if (promo.status == 'draft') return 'draft';
    return 'paused';
  }

  int _countStatus(String status) {
    if (status == 'all') return _promos.length;
    return _promos.where((p) => _effectiveStatus(p) == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _countStatus('active');
    final usageCount = _promos.fold<int>(0, (sum, p) => sum + p.usedCount);

    final filteredPromos = _promos.where((p) {
      if (_filterStatus == 'all') return true;
      return _effectiveStatus(p) == _filterStatus;
    }).toList();

    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'Promo Merchant',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MerchantNotificationsPage()),
        ),
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _PromoMetric(
                icon: Icons.campaign_outlined,
                title: 'Promo Aktif',
                subtitle: 'Jumlah promo yang sedang berjalan.',
                value: activeCount.toString(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _PromoMetric(
                icon: Icons.analytics_outlined,
                title: 'Total Penggunaan Promo',
                subtitle: 'Jumlah total penggunaan seluruh promo.',
                value: usageCount.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _CreatePromoCard(onPressed: () => _openForm()),
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(label: 'Semua (${_countStatus('all')})', value: 'all', groupValue: _filterStatus, onChanged: (v) => setState(() => _filterStatus = v)),
              const SizedBox(width: 8),
              _FilterChip(label: 'Aktif (${_countStatus('active')})', value: 'active', groupValue: _filterStatus, onChanged: (v) => setState(() => _filterStatus = v)),
              const SizedBox(width: 8),
              _FilterChip(label: 'Draft (${_countStatus('draft')})', value: 'draft', groupValue: _filterStatus, onChanged: (v) => setState(() => _filterStatus = v)),
              const SizedBox(width: 8),
              _FilterChip(label: 'Nonaktif (${_countStatus('paused')})', value: 'paused', groupValue: _filterStatus, onChanged: (v) => setState(() => _filterStatus = v)),
              const SizedBox(width: 8),
              _FilterChip(label: 'Expired (${_countStatus('expired')})', value: 'expired', groupValue: _filterStatus, onChanged: (v) => setState(() => _filterStatus = v)),
            ],
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
                Text(_error!, style: const TextStyle(color: MerchantPalette.danger)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Muat Ulang')),
              ],
            ),
          )
        else if (filteredPromos.isEmpty)
          MerchantCard(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.campaign_outlined, size: 48, color: MerchantPalette.muted),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum ada promo.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: MerchantPalette.text),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Buat promo pertama untuk meningkatkan penjualan.',
                    style: TextStyle(color: MerchantPalette.muted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Buat Promo'),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredPromos.map(
            (promo) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _PromoCard(
                promo: promo,
                effectiveStatus: _effectiveStatus(promo),
                onEdit: () => _openForm(promo: promo),
                onDuplicate: () => _openForm(promo: promo, isDuplicate: true),
                onActivate: () => _updateStatus(promo, 'active', true),
                onPause: () => _updateStatus(promo, 'inactive', false),
                onDelete: () => _delete(promo),
              ),
            ),
          ),
        const MerchantBottomSpacer(),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        if (v) onChanged(value);
      },
      selectedColor: MerchantPalette.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : MerchantPalette.text,
        fontWeight: selected ? FontWeight.w800 : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
    );
  }
}

class _PromoMetric extends StatelessWidget {
  const _PromoMetric({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: MerchantPalette.muted,
              fontSize: 10,
              height: 1.2,
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
            'Buat promo menarik untuk meningkatkan penjualan Anda.',
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
    required this.effectiveStatus,
    required this.onEdit,
    required this.onDuplicate,
    required this.onActivate,
    required this.onPause,
    required this.onDelete,
  });

  final MerchantPromo promo;
  final String effectiveStatus;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onActivate;
  final VoidCallback onPause;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isExpired = effectiveStatus == 'expired';
    
    return Opacity(
      opacity: isExpired ? 0.6 : 1.0,
      child: MerchantCard(
        color: isExpired ? const Color(0xFFF3F4F6) : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MerchantStatusPill(
                  label: _statusLabel(effectiveStatus),
                  color: _statusColor(effectiveStatus),
                ),
                const Spacer(),
                if (isExpired)
                  const Icon(Icons.lock_outline_rounded, color: MerchantPalette.muted, size: 20)
                else ...[
                  if (effectiveStatus == 'draft' || effectiveStatus == 'paused')
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill_rounded, color: MerchantPalette.success),
                      tooltip: 'Aktifkan Promo',
                      onPressed: onActivate,
                    ),
                  if (effectiveStatus == 'active')
                    IconButton(
                      icon: const Icon(Icons.pause_circle_filled_rounded, color: MerchantPalette.warning),
                      tooltip: 'Nonaktifkan Promo',
                      onPressed: onPause,
                    ),
                  if (effectiveStatus != 'active')
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: MerchantPalette.primary),
                      tooltip: 'Edit Promo',
                      onPressed: onEdit,
                    ),
                  if (effectiveStatus == 'draft')
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: MerchantPalette.danger),
                      tooltip: 'Hapus Promo',
                      onPressed: onDelete,
                    ),
                ],
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: MerchantPalette.primary),
                  tooltip: 'Duplikat Promo',
                  onPressed: onDuplicate,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              promo.name,
              style: TextStyle(
                color: isExpired ? const Color(0xFF757D8A) : MerchantPalette.text,
                fontSize: 20,
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
              text: promo.discountType == 'percentage'
                  ? '${promo.discountValue.toStringAsFixed(0)}% untuk ${promo.targetLabel}\nMaksimal Potongan: ${formatMerchantCurrency(promo.maxDiscountAmount)}'
                  : 'Potongan ${formatMerchantCurrency(promo.discountValue)} untuk ${promo.targetLabel}',
            ),
            const SizedBox(height: 8),
            _PromoMeta(
              icon: Icons.group_outlined,
              text: promo.usageLimit != null
                  ? '${promo.usedCount} / ${promo.usageLimit} penggunaan'
                  : '${promo.usedCount} kali digunakan',
            ),
            const SizedBox(height: 8),
            _PromoMeta(
              icon: Icons.calendar_today_outlined,
              text: '${_date(promo.startAt)} - ${_date(promo.endAt)}',
            ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime? date) {
    if (date == null) return 'Tidak dibatasi';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active': return 'AKTIF';
      case 'expired': return 'EXPIRED';
      case 'paused': return 'NONAKTIF';
      case 'draft': return 'DRAFT';
      default: return 'PROMO';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return MerchantPalette.success;
      case 'expired': return MerchantPalette.muted;
      case 'paused': return MerchantPalette.warning;
      case 'draft': return const Color(0xFF6B7280);
      default: return MerchantPalette.primary;
    }
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
    this.isDuplicate = false,
  });

  final List<MerchantProduct> products;
  final MerchantPromo? promo;
  final bool isDuplicate;

  @override
  State<_PromoForm> createState() => _PromoFormState();
}

class _PromoFormState extends State<_PromoForm> {
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _maxDiscountCtrl = TextEditingController();
  final _usageLimitCtrl = TextEditingController();
  final _perUserLimitCtrl = TextEditingController(text: '1');

  bool _targetAllProducts = true;
  final Set<String> _selectedProductIds = {};
  String _discountType = 'percentage';
  DateTime? _startAt = DateTime.now();
  DateTime? _endAt = DateTime.now().add(const Duration(days: 14));
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);
  String _status = 'draft';
  
  bool _saving = false;
  bool _hasAttemptedSubmit = false;
  
  bool get _isEditActive => widget.promo != null && !widget.isDuplicate && (widget.promo!.status == 'active' || widget.promo!.status == 'scheduled');

  double _parseCurrency(String text) {
    String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return double.parse(digits);
  }

  double get _discountValue => _parseCurrency(_discountCtrl.text);
      
  double get _maxDiscountValue => _parseCurrency(_maxDiscountCtrl.text);
  int? get _usageLimitValue => _usageLimitCtrl.text.trim().isEmpty ? null : int.tryParse(_usageLimitCtrl.text.trim());
  int get _perUserLimitValue => int.tryParse(_perUserLimitCtrl.text.trim()) ?? 1;

  final _currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  
  String _formatCurrencyString(double value) {
    if (value == 0) return '';
    return _currencyFormatter.format(value);
  }

  @override
  void initState() {
    super.initState();
    final promo = widget.promo;
    
    if (promo != null) {
      _nameCtrl.text = widget.isDuplicate ? '${promo.name} (Copy)' : promo.name;
      _descriptionCtrl.text = promo.description;
      
      _discountType = promo.discountType;
      
      if (_discountType == 'percentage') {
        _discountCtrl.text = '${promo.discountValue.toStringAsFixed(0)}%';
      } else {
        _discountCtrl.text = _formatCurrencyString(promo.discountValue);
      }
      
      _maxDiscountCtrl.text = _formatCurrencyString(promo.maxDiscountAmount);
      _usageLimitCtrl.text = promo.usageLimit?.toString() ?? '';
      _perUserLimitCtrl.text = promo.perUserUsageLimit.toString();
      
      _targetAllProducts = promo.targetsAllProducts;
      _selectedProductIds.addAll(promo.productIds);
      
      if (!widget.isDuplicate) {
        _startAt = promo.startAt ?? _startAt;
        _endAt = promo.endAt ?? _endAt;
        _status = promo.status;
        if (_status == 'expired') _status = 'draft';
      }
    }
    
    if (_startAt != null) _startTime = TimeOfDay.fromDateTime(_startAt!);
    if (_endAt != null) _endTime = TimeOfDay.fromDateTime(_endAt!);

    _nameCtrl.addListener(_onPreviewInputChanged);
    _discountCtrl.addListener(_onPreviewInputChanged);
    _maxDiscountCtrl.addListener(_onPreviewInputChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onPreviewInputChanged);
    _discountCtrl.removeListener(_onPreviewInputChanged);
    _maxDiscountCtrl.removeListener(_onPreviewInputChanged);
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _discountCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _usageLimitCtrl.dispose();
    _perUserLimitCtrl.dispose();
    super.dispose();
  }

  void _onPreviewInputChanged() {
    setState(() {}); // trigger realtime validation and preview update
  }

  MerchantProduct? _getSampleProduct() {
    if (_targetAllProducts) {
      return widget.products.isNotEmpty ? widget.products.first : null;
    } else {
      final selected = widget.products.where((p) => _selectedProductIds.contains(p.id)).toList();
      return selected.isNotEmpty ? selected.first : null;
    }
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
      if (_hasAttemptedSubmit) {}
    });
  }

  Future<void> _pickProducts() async {
    if (_isEditActive) return; // Cannot edit targets when active
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
                left: 20, right: 20, top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih Produk Promo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    decoration: _decoration('Cari produk', null),
                    onChanged: (value) => setModalState(() => searchQuery = value.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
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
      _selectedProductIds..clear()..addAll(selected);
      if (_hasAttemptedSubmit) {}
    });
  }

  Future<void> _save(String targetStatus) async {
    setState(() => _hasAttemptedSubmit = true);
    final validationError = _validateForm();
    if (validationError != null) {
      // Error text will now appear under the fields
      return;
    }
    
    setState(() {
      _saving = true;
      _status = targetStatus;
    });
    
    final productIds = _targetAllProducts ? <String>[] : _selectedProductIds.toList();
    final result = await MerchantRepository.savePromo(
      id: widget.isDuplicate ? null : widget.promo?.id,
      name: _nameCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      productIds: productIds,
      discountType: _discountType,
      discountValue: _discountValue,
      minOrderAmount: 0,
      maxDiscountAmount: _discountType == 'percentage' ? _maxDiscountValue : 0,
      startAt: _startAt,
      endAt: _endAt,
      isActive: _status == 'active',
      status: _status,
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

  String? _validateForm() {
    if (_status == 'draft') return null;
    if (_nameCtrl.text.trim().isEmpty) return 'Nama promo wajib diisi';
    if (!_targetAllProducts && _selectedProductIds.isEmpty) return 'Pilih minimal satu produk';
    if (_discountValue <= 0) return 'Nilai diskon harus lebih dari 0';
    if (_discountType == 'percentage' && _discountValue > 100) return 'Diskon maksimal 100%';
    if (_discountType == 'percentage' && _maxDiscountValue <= 0) return 'Maksimal potongan wajib diisi';
    if (_usageLimitValue != null && (_usageLimitValue ?? 0) <= 0) return 'Kuota Promo harus lebih dari 0';
    if (_perUserLimitValue <= 0) return 'Batas penggunaan per user minimal 1';
    if (_startAt != null && _endAt != null && !_endAt!.isAfter(_startAt!)) return 'Tanggal akhir harus setelah tanggal mulai';
    return null;
  }
  
  String? _errorForField(String field) {
    if (!_hasAttemptedSubmit || _status == 'draft') return null;
    if (field == 'name' && _nameCtrl.text.trim().isEmpty) return 'Wajib diisi';
    if (field == 'discount' && _discountValue <= 0) return 'Harus > 0';
    if (field == 'discount_max' && _discountType == 'percentage' && _discountValue > 100) return 'Maks 100%';
    if (field == 'max_amount' && _discountType == 'percentage' && _maxDiscountValue <= 0) return 'Wajib diisi';
    if (field == 'usage' && _usageLimitValue != null && (_usageLimitValue ?? 0) <= 0) return 'Harus > 0';
    if (field == 'peruser' && _perUserLimitValue <= 0) return 'Min 1';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool showWarning = (_discountType == 'percentage' && _discountValue >= 50);
    
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.promo == null || widget.isDuplicate ? 'Buat Promo Baru' : 'Edit Promo',
              style: const TextStyle(
                color: MerchantPalette.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            
            const _SectionTitle('SECTION 1 — INFORMASI PROMO'),
            _Input(
              controller: _nameCtrl, 
              label: 'Nama Promo', 
              errorText: _errorForField('name'),
            ),
            const SizedBox(height: 14),
            _Input(
              controller: _descriptionCtrl,
              label: 'Deskripsi Promo (Opsional)',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            const _SectionTitle('SECTION 2 — TARGET PRODUK'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Semua Produk')),
                ButtonSegment(value: false, label: Text('Produk Tertentu')),
              ],
              selected: {_targetAllProducts},
              onSelectionChanged: _isEditActive ? null : (value) {
                setState(() => _targetAllProducts = value.first);
              },
            ),
            if (!_targetAllProducts) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isEditActive || widget.products.isEmpty ? null : _pickProducts,
                icon: const Icon(Icons.checklist_rounded),
                label: Text(
                  _selectedProductIds.isEmpty
                      ? 'Pilih produk'
                      : '${_selectedProductIds.length} produk dipilih',
                ),
              ),
              if (_hasAttemptedSubmit && !_targetAllProducts && _selectedProductIds.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8, left: 12),
                  child: Text('Pilih minimal satu produk', style: TextStyle(color: MerchantPalette.danger, fontSize: 12)),
                )
            ],
            const SizedBox(height: 24),
            
            const _SectionTitle('SECTION 3 — JENIS DISKON'),
            DropdownButtonFormField<String>(
              initialValue: _discountType,
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text('Persen')),
                DropdownMenuItem(value: 'fixed', child: Text('Nominal')),
              ],
              onChanged: _isEditActive ? null : (value) {
                if (value != null) {
                  setState(() {
                    _discountType = value;
                    _discountCtrl.clear();
                    _maxDiscountCtrl.clear();
                  });
                }
              },
              decoration: _decoration('Tipe Diskon', null),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Input(
                    controller: _discountCtrl,
                    label: _discountType == 'percentage' ? 'Nilai Diskon (%)' : 'Nominal Potongan',
                    keyboardType: TextInputType.number,
                    inputFormatters: _discountType == 'fixed' 
                        ? [_CurrencyInputFormatter()] 
                        : [_PercentageInputFormatter()],
                    errorText: _errorForField('discount') ?? _errorForField('discount_max'),
                    enabled: !_isEditActive,
                  ),
                ),
                if (_discountType == 'percentage') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Input(
                      controller: _maxDiscountCtrl,
                      label: 'Maksimal Potongan',
                      keyboardType: TextInputType.number,
                      inputFormatters: [_CurrencyInputFormatter()],
                      errorText: _errorForField('max_amount'),
                      enabled: !_isEditActive,
                    ),
                  ),
                ],
              ],
            ),
            if (showWarning)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MerchantPalette.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MerchantPalette.warning.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: MerchantPalette.warning, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Diskon besar dapat mengurangi keuntungan penjualan. Gunakan diskon tinggi dengan pertimbangan margin produk.',
                        style: TextStyle(color: MerchantPalette.warning, fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            
            const _SectionTitle('SECTION 4 — USAGE SETTINGS'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Input(
                    controller: _usageLimitCtrl,
                    label: 'Total Kuota Promo (Opsional)',
                    keyboardType: TextInputType.number,
                    errorText: _errorForField('usage'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Input(
                    controller: _perUserLimitCtrl,
                    label: 'Maks Penggunaan per User',
                    keyboardType: TextInputType.number,
                    errorText: _errorForField('peruser'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Promo akan otomatis berhenti setelah mencapai batas penggunaan. Batas per user mencegah penggunaan promo berulang oleh user yang sama.',
              style: TextStyle(color: MerchantPalette.muted, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 24),
            
            const _SectionTitle('SECTION 5 — PERIODE PROMO'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(true),
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text('Mulai\n${_dateTime(_startAt)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(false),
                    icon: const Icon(Icons.event_busy_rounded),
                    label: Text('Akhir\n${_dateTime(_endAt)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            if (_hasAttemptedSubmit && _startAt != null && _endAt != null && !_endAt!.isAfter(_startAt!))
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 12),
                child: Text('Tanggal akhir harus setelah tanggal mulai', style: TextStyle(color: MerchantPalette.danger, fontSize: 12)),
              ),
            const SizedBox(height: 24),
            
            const _SectionTitle('SECTION 6 — PREVIEW OTOMATIS'),
            _PromoRealtimePreview(
              discountType: _discountType,
              discountValue: _discountValue,
              maxDiscountAmount: _discountType == 'percentage' ? _maxDiscountValue : 0,
              sampleProduct: _getSampleProduct(),
              targetAllProducts: _targetAllProducts,
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                if (widget.promo == null || widget.isDuplicate) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => _save('draft'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: MerchantPalette.primary,
                        side: const BorderSide(color: MerchantPalette.primary),
                      ),
                      child: const Text('Simpan Draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : () => _save('active'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: MerchantPalette.primary,
                      ),
                      child: Text(_saving ? 'Menyimpan...' : 'Publish Promo'),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : () => _save(_status),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: MerchantPalette.primary,
                      ),
                      child: Text(_saving ? 'Menyimpan...' : 'Simpan Perubahan'),
                    ),
                  ),
                ],
              ],
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

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: MerchantPalette.primary)),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.errorText,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      enabled: enabled,
      decoration: _decoration(label, errorText),
    );
  }
}

class _PromoRealtimePreview extends StatelessWidget {
  const _PromoRealtimePreview({
    required this.discountType,
    required this.discountValue,
    required this.maxDiscountAmount,
    required this.sampleProduct,
    required this.targetAllProducts,
  });

  final String discountType;
  final double discountValue;
  final double maxDiscountAmount;
  final MerchantProduct? sampleProduct;
  final bool targetAllProducts;

  double _calculateDiscount(double subtotal) {
    double discount = 0;
    if (discountType == 'percentage') {
      discount = subtotal * discountValue / 100;
      if (maxDiscountAmount > 0) discount = discount > maxDiscountAmount ? maxDiscountAmount : discount;
    } else {
      discount = discountValue;
    }
    if (discount > subtotal) discount = subtotal;
    return discount;
  }

  Widget _buildSimulationCard(String title, double subtotal) {
    final discount = _calculateDiscount(subtotal);
    final total = subtotal - discount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: MerchantPalette.primary),
        ),
        const SizedBox(height: 8),
        const Text('Harga Normal', style: TextStyle(color: MerchantPalette.muted, fontSize: 12)),
        Text(formatMerchantCurrency(subtotal)),
        const SizedBox(height: 8),
        const Text('Potongan Promo', style: TextStyle(color: MerchantPalette.muted, fontSize: 12)),
        Text(formatMerchantCurrency(discount)),
        const SizedBox(height: 8),
        const Text('Harga Setelah Promo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        Text(
          formatMerchantCurrency(total),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: MerchantPalette.primary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (discountValue <= 0) {
      return const MerchantCard(
        color: MerchantPalette.softBlue,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Masukkan nilai diskon untuk melihat preview promo.',
              style: TextStyle(color: MerchantPalette.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (sampleProduct == null) {
      return const MerchantCard(
        color: MerchantPalette.softBlue,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Pilih produk untuk melihat preview promo.',
              style: TextStyle(color: MerchantPalette.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final isCatering = sampleProduct!.serviceType == 'catering';

    return MerchantCard(
      color: MerchantPalette.softBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview Harga Setelah Promo',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Target Promo:\n${targetAllProducts ? 'Semua Produk' : 'Produk Tertentu'}',
            style: const TextStyle(color: MerchantPalette.muted, fontSize: 13, height: 1.3),
          ),
          const Divider(height: 24),
          Text(
            sampleProduct!.name,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (isCatering) ...[
            _buildSimulationCard('Fullday', sampleProduct!.price),
            const SizedBox(height: 16),
            _buildSimulationCard('Weekday', sampleProduct!.price20Days ?? sampleProduct!.price),
          ] else ...[
            _buildSimulationCard('Harga Reguler', sampleProduct!.price),
          ],
        ],
      ),
    );
  }
}

InputDecoration _decoration(String label, String? errorText) {
  return InputDecoration(
    labelText: label,
    errorText: errorText,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    
    double value = double.parse(digits);
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    String formatted = formatter.format(value);

    // Mempertahankan kursor di posisi akhir teks (standar untuk currency)
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _PercentageInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    
    double value = double.parse(digits);
    if (value > 100) value = 100; // Limit ke 100%
    
    String formatted = '${value.toInt()}%';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length - 1),
    );
  }
}
