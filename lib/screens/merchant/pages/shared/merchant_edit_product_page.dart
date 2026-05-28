import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/catering_package_category.dart';
import '../../../../models/laundry_service_estimate.dart';
import '../../../../models/merchant_models.dart';
import '../../merchant_ui.dart';

class MerchantEditProductPage extends StatefulWidget {
  const MerchantEditProductPage({
    super.key,
    required this.isLaundry,
    this.product,
  });

  final bool isLaundry;
  final MerchantProduct? product;

  @override
  State<MerchantEditProductPage> createState() =>
      _MerchantEditProductPageState();
}

class _MerchantEditProductPageState extends State<MerchantEditProductPage> {
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _price20Ctrl = TextEditingController();
  final _deliveryTime1Ctrl = TextEditingController();
  final _deliveryTime2Ctrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _picker = ImagePicker();

  String _imageUrl = '';
  bool _saving = false;
  bool _showWeekdayPrice = false;
  int _mealDeliveryCount = 1;
  List<LaundryServiceEstimate> _estimates = [];
  List<CateringPackageCategory> _packageCategories = [];
  String? _selectedEstimate;
  String? _selectedPackageCategory;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameCtrl.text = product?.name ?? '';
    _categoryCtrl.text = product?.category ?? '';
    _selectedEstimate =
        product?.category.isNotEmpty == true ? product!.category : null;
    if (widget.isLaundry) {
      _loadEstimates();
    } else if (_categoryCtrl.text.isEmpty) {
      _loadPackageCategories();
    } else {
      _selectedPackageCategory = _categoryCtrl.text;
      _loadPackageCategories();
    }
    _priceCtrl.text = product == null
        ? ''
        : _formatThousands(product.price.toStringAsFixed(0));
    _price20Ctrl.text = product?.price20Days == null
        ? ''
        : _formatThousands(product!.price20Days!.toStringAsFixed(0));
    _showWeekdayPrice = !widget.isLaundry &&
        product?.price20Days != null &&
        product!.price20Days! > 0;
    _mealDeliveryCount =
        widget.isLaundry ? 1 : (product?.mealDeliveryCount ?? 1);
    if (_mealDeliveryCount < 1 || _mealDeliveryCount > 2) {
      _mealDeliveryCount = 1;
    }
    _deliveryTime1Ctrl.text = product?.deliveryTime1 ?? '07:00';
    _deliveryTime2Ctrl.text = product?.deliveryTime2 ?? '15:00';
    _unitCtrl.text = product?.unit ?? (widget.isLaundry ? '/kg' : '');
    if (!widget.isLaundry) {
      _unitCtrl.text = 'Paket bulanan';
    }
    _descriptionCtrl.text = product?.description ?? '';
    _imageUrl = product?.imageUrl ?? '';
  }

  Future<void> _loadEstimates() async {
    final result = await MerchantRepository.getLaundryEstimates();
    if (!mounted) return;
    final items = (result.data ?? []).where((e) => e.isActive).toList();
    setState(() {
      _estimates = items;
      if (_selectedEstimate == null && items.isNotEmpty) {
        _selectedEstimate = items.first.serviceName;
        _categoryCtrl.text = _selectedEstimate!;
      }
    });
  }

  Future<void> _loadPackageCategories() async {
    final result = await MerchantRepository.getPackageCategories();
    if (!mounted) return;
    final items = (result.data ?? []).where((e) => e.isActive).toList();
    setState(() {
      _packageCategories = items;
      if (_selectedPackageCategory == null && items.isNotEmpty) {
        _selectedPackageCategory = items.first.categoryName;
        _categoryCtrl.text = _selectedPackageCategory!;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _price20Ctrl.dispose();
    _deliveryTime1Ctrl.dispose();
    _deliveryTime2Ctrl.dispose();
    _unitCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 78,
      maxWidth: 1200,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    setState(() {
      _imageUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final price = double.tryParse(
          _priceCtrl.text.replaceAll('.', '').replaceAll(',', '.').trim(),
        ) ??
        0;
    final price20Days = double.tryParse(
          _price20Ctrl.text.replaceAll('.', '').replaceAll(',', '.').trim(),
        ) ??
        0;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan harga wajib diisi')),
      );
      return;
    }
    if (!widget.isLaundry && _showWeekdayPrice && price20Days <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harga weekday wajib diisi lebih dari 0'),
        ),
      );
      return;
    }
    if (widget.isLaundry &&
        (_selectedEstimate == null || _selectedEstimate!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih estimasi waktu layanan terlebih dahulu'),
        ),
      );
      return;
    }
    if (!widget.isLaundry &&
        (_selectedPackageCategory == null ||
            _selectedPackageCategory!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori paket terlebih dahulu'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final result = await MerchantRepository.saveProduct(
      id: widget.product?.id,
      name: name,
      description: description,
      price: price,
      price20Days: widget.isLaundry || !_showWeekdayPrice ? null : price20Days,
      mealDeliveryCount: widget.isLaundry ? 1 : _mealDeliveryCount,
      deliveryTime1: _deliveryTime1Ctrl.text.trim().isEmpty
          ? '07:00'
          : _deliveryTime1Ctrl.text.trim(),
      deliveryTime2: widget.isLaundry || _mealDeliveryCount < 2
          ? null
          : (_deliveryTime2Ctrl.text.trim().isEmpty
              ? '15:00'
              : _deliveryTime2Ctrl.text.trim()),
      category: widget.isLaundry
          ? (_selectedEstimate ?? _categoryCtrl.text.trim())
          : (_selectedPackageCategory ?? _categoryCtrl.text.trim()),
      unit: widget.isLaundry ? _unitCtrl.text.trim() : 'Paket bulanan',
      imageUrl: _imageUrl,
      isActive: true,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk berhasil disimpan')),
      );
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Gagal menyimpan produk')),
    );
  }

  Future<void> _delete() async {
    if (widget.product == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isLaundry ? 'Hapus layanan?' : 'Hapus paket?'),
        content: const Text(
          'Item akan disembunyikan dari katalog aktif user. Riwayat pesanan lama tetap aman.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    final result = await MerchantRepository.deleteProduct(widget.product!.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Gagal menghapus produk')),
    );
  }

  Future<void> _pickDeliveryTime(TextEditingController controller) async {
    final parts = controller.text.trim().split(':');
    final initialHour = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final initialMinute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialHour != null && initialHour >= 0 && initialHour <= 23
            ? initialHour
            : 7,
        minute:
            initialMinute != null && initialMinute >= 0 && initialMinute <= 59
                ? initialMinute
                : 0,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit
        ? (widget.isLaundry ? 'Edit Layanan' : 'Edit Paket')
        : (widget.isLaundry ? 'Tambah Layanan' : 'Tambah Paket');

    return MerchantPage(
      topBar: MerchantTopBar(
        title: title,
        showAvatar: false,
        showBack: true,
        actionLabel: _saving ? 'Menyimpan...' : 'Simpan',
        onAction: _saving ? null : _save,
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            children: [
              MerchantImage(
                url: _imageUrl,
                icon: widget.isLaundry
                    ? Icons.local_laundry_service_outlined
                    : Icons.restaurant_rounded,
                width: double.infinity,
                height: 190,
                borderRadius: BorderRadius.circular(12),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: MerchantPalette.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [MerchantPalette.shadow(opacity: 0.16)],
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _FieldLabel(widget.isLaundry ? 'Nama Layanan' : 'Nama Paket/Menu'),
        const SizedBox(height: 8),
        _Input(controller: _nameCtrl),
        const SizedBox(height: 22),
        if (widget.isLaundry) ...[
          const _FieldLabel('Estimasi Waktu Layanan'),
          const SizedBox(height: 8),
          if (_estimates.isEmpty)
            const Text(
              'Tambahkan estimasi di halaman Kelola Layanan terlebih dahulu.',
              style: TextStyle(color: MerchantPalette.muted, fontSize: 13),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedEstimate != null &&
                      _estimates.any((e) => e.serviceName == _selectedEstimate)
                  ? _selectedEstimate
                  : _estimates.first.serviceName,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF7F9FC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _estimates
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.serviceName,
                      child: Text(
                        '${e.serviceName} (${e.estimateLabel.isNotEmpty ? e.estimateLabel : '${e.minHours}-${e.maxHours} jam'})',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedEstimate = value;
                  _categoryCtrl.text = value;
                });
              },
            ),
        ] else ...[
          const _FieldLabel('Kategori Paket'),
          const SizedBox(height: 8),
          if (_packageCategories.isEmpty)
            const Text(
              'Belum ada kategori paket. Kategori akan disiapkan admin.',
              style: TextStyle(color: MerchantPalette.muted, fontSize: 13),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedPackageCategory != null &&
                      _packageCategories.any(
                        (e) => e.categoryName == _selectedPackageCategory,
                      )
                  ? _selectedPackageCategory
                  : _packageCategories.first.categoryName,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF7F9FC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _packageCategories
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.categoryName,
                      child: Text(e.categoryName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedPackageCategory = value;
                  _categoryCtrl.text = value;
                });
              },
            ),
        ],
        const SizedBox(height: 22),
        if (widget.isLaundry) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Harga (IDR)'),
                    const SizedBox(height: 8),
                    _Input(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      prefix: 'Rp',
                      inputFormatters: const [_ThousandsInputFormatter()],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Satuan'),
                    const SizedBox(height: 8),
                    _Input(controller: _unitCtrl),
                  ],
                ),
              ),
            ],
          ),
        ] else ...[
          const _FieldLabel(
            'Harga Full Day 30 hari(dikirim setiap hari, termasuk Sabtu-Minggu)',
          ),
          const SizedBox(height: 8),
          _Input(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            prefix: 'Rp',
            inputFormatters: const [_ThousandsInputFormatter()],
          ),
          const SizedBox(height: 18),
          if (_showWeekdayPrice) ...[
            Row(
              children: [
                const Expanded(
                  child: _FieldLabel(
                    'Harga Weekday 30 hari (Sabtu-Minggu tidak dikirim)',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showWeekdayPrice = false;
                      _price20Ctrl.clear();
                    });
                  },
                  child: const Text('Hapus'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Input(
              controller: _price20Ctrl,
              keyboardType: TextInputType.number,
              prefix: 'Rp',
              inputFormatters: const [_ThousandsInputFormatter()],
            ),
          ] else
            _AddWeekdayPriceCard(
              onTap: () => setState(() => _showWeekdayPrice = true),
            ),
        ],
        const SizedBox(height: 22),
        if (!widget.isLaundry) ...[
          const _FieldLabel('Jadwal Pengantaran Harian'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1x sehari')),
              ButtonSegment(value: 2, label: Text('2x sehari')),
            ],
            selected: {_mealDeliveryCount},
            onSelectionChanged: (value) {
              setState(() => _mealDeliveryCount = value.first);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimePickField(
                  label: _mealDeliveryCount == 1
                      ? 'Jam Pengantaran'
                      : 'Jam Pengantaran 1',
                  controller: _deliveryTime1Ctrl,
                  onTap: () => _pickDeliveryTime(_deliveryTime1Ctrl),
                ),
              ),
              if (_mealDeliveryCount == 2) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickField(
                    label: 'Jam Pengantaran 2',
                    controller: _deliveryTime2Ctrl,
                    onTap: () => _pickDeliveryTime(_deliveryTime2Ctrl),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
        ],
        _FieldLabel(widget.isLaundry
            ? 'Deskripsi Layanan'
            : 'Menu, Lauk Pauk & Jadwal Antar'),
        const SizedBox(height: 8),
        _Input(controller: _descriptionCtrl, maxLines: 5),
        if (_isEdit) ...[
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _saving ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(widget.isLaundry ? 'Hapus Layanan' : 'Hapus Paket'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: MerchantPalette.danger,
              side: BorderSide(
                color: MerchantPalette.danger.withValues(alpha: 0.3),
              ),
              backgroundColor: MerchantPalette.danger.withValues(alpha: 0.08),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
        const MerchantBottomSpacer(),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: MerchantPalette.muted,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AddWeekdayPriceCard extends StatelessWidget {
  const _AddWeekdayPriceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC9D3E1)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFE3E6EC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: MerchantPalette.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Ingin menambahkan paket Weekday 30 hari? Makanan dikirim Senin-Jumat, Sabtu dan Minggu libur.',
                style: TextStyle(
                  color: MerchantPalette.text,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickField extends StatelessWidget {
  const _TimePickField({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: IgnorePointer(
            child: _Input(
              controller: controller,
              suffixIcon: Icons.schedule_rounded,
            ),
          ),
        ),
      ],
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    this.maxLines = 1,
    this.prefix,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final int maxLines;
  final String? prefix;
  final IconData? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        color: MerchantPalette.text,
        fontSize: 16,
        height: 1.35,
      ),
      decoration: InputDecoration(
        prefixText: prefix == null ? null : '$prefix   ',
        prefixStyle: const TextStyle(
          color: MerchantPalette.muted,
          fontSize: 16,
        ),
        suffixIcon: suffixIcon == null ? null : Icon(suffixIcon),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC9D3E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC9D3E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: MerchantPalette.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _ThousandsInputFormatter extends TextInputFormatter {
  const _ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = _formatThousands(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatThousands(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}
