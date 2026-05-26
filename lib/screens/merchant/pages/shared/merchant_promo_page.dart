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
                '${promo.discountType == 'percentage' ? '${promo.discountValue.toStringAsFixed(0)}%' : formatMerchantCurrency(promo.discountValue)} untuk ${promo.productName}',
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

  String _productId = '';
  String _discountType = 'percentage';
  DateTime? _startAt = DateTime.now();
  DateTime? _endAt = DateTime.now().add(const Duration(days: 14));
  bool _isActive = true;
  bool _saving = false;

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
    _productId = promo?.productId ?? '';
    _discountType = promo?.discountType ?? 'percentage';
    _startAt = promo?.startAt ?? _startAt;
    _endAt = promo?.endAt ?? _endAt;
    _isActive = promo?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _discountCtrl.dispose();
    _minOrderCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _usageLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final initial = start ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      if (start) {
        _startAt = date;
      } else {
        _endAt = date.add(const Duration(hours: 23, minutes: 59));
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await MerchantRepository.savePromo(
      id: widget.promo?.id,
      name: _nameCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      productId: _productId,
      discountType: _discountType,
      discountValue: _number(_discountCtrl.text),
      minOrderAmount: _number(_minOrderCtrl.text),
      maxDiscountAmount: _number(_maxDiscountCtrl.text),
      startAt: _startAt,
      endAt: _endAt,
      isActive: _isActive,
      usageLimit: _usageLimitCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_usageLimitCtrl.text.trim()),
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
            _Input(controller: _nameCtrl, label: 'Nama Promo'),
            const SizedBox(height: 14),
            _Input(
              controller: _descriptionCtrl,
              label: 'Deskripsi Promo',
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _productId,
              items: [
                const DropdownMenuItem(value: '', child: Text('Semua produk')),
                ...widget.products.map(
                  (product) => DropdownMenuItem(
                    value: product.id,
                    child: Text(product.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _productId = value ?? ''),
              decoration: _decoration('Produk yang Dipromo'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _discountType,
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text('Persen')),
                DropdownMenuItem(value: 'fixed', child: Text('Nominal')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _discountType = value);
              },
              decoration: _decoration('Tipe Diskon'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Input(
                    controller: _discountCtrl,
                    label: 'Nilai Diskon',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Input(
                    controller: _maxDiscountCtrl,
                    label: 'Maks Diskon',
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
                    controller: _minOrderCtrl,
                    label: 'Minimal Transaksi',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Input(
                    controller: _usageLimitCtrl,
                    label: 'Limit Pakai',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text('Mulai ${_date(_startAt)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.event_busy_rounded),
                    label: Text('Akhir ${_date(_endAt)}'),
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

  String _date(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
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
