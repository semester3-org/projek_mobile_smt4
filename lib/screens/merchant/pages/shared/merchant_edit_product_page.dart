import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../data/repositories/merchant_repository.dart';
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
  final _unitCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _picker = ImagePicker();

  String _imageUrl = '';
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameCtrl.text = product?.name ?? '';
    _categoryCtrl.text = product?.category ??
        (widget.isLaundry ? 'Laundry Kiloan' : 'Paket Bulanan');
    _priceCtrl.text = product == null ? '' : product.price.toStringAsFixed(0);
    _price20Ctrl.text = product?.price20Days != null && product!.price20Days! > 0
        ? product.price20Days!.toStringAsFixed(0)
        : '';
    _unitCtrl.text = product?.unit ?? (widget.isLaundry ? '/kg' : '');
    _descriptionCtrl.text = product?.description ?? '';
    _imageUrl = product?.imageUrl ?? '';
    _isActive = product?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _price20Ctrl.dispose();
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
    final price20 = double.tryParse(
          _price20Ctrl.text.replaceAll('.', '').replaceAll(',', '.').trim(),
        ) ??
        0;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan harga wajib diisi')),
      );
      return;
    }
    if (!widget.isLaundry && price20 <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harga paket 20 hari wajib diisi terpisah dari 30 hari'),
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
      price20Days: widget.isLaundry ? null : price20,
      category: _categoryCtrl.text.trim(),
      unit: widget.isLaundry ? _unitCtrl.text.trim() : '',
      imageUrl: _imageUrl,
      isActive: _isActive,
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
        _FieldLabel(widget.isLaundry ? 'Kategori Layanan' : 'Kategori Paket'),
        const SizedBox(height: 8),
        _Input(controller: _categoryCtrl),
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
          const _FieldLabel('Harga Paket 30 Hari (IDR)'),
          const SizedBox(height: 8),
          _Input(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            prefix: 'Rp',
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Harga Paket 20 Hari (IDR)'),
          const SizedBox(height: 8),
          _Input(
            controller: _price20Ctrl,
            keyboardType: TextInputType.number,
            prefix: 'Rp',
          ),
        ],
        const SizedBox(height: 22),
        _FieldLabel(widget.isLaundry
            ? 'Deskripsi Layanan'
            : 'Menu, Lauk Pauk & Jadwal Antar'),
        const SizedBox(height: 8),
        _Input(controller: _descriptionCtrl, maxLines: 5),
        const SizedBox(height: 26),
        MerchantCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isLaundry ? 'Layanan Aktif' : 'Paket Aktif',
                      style: const TextStyle(
                        color: MerchantPalette.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Aktifkan agar item tampil di aplikasi user.',
                      style: TextStyle(
                        color: MerchantPalette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isActive,
                activeThumbColor: Colors.white,
                activeTrackColor: MerchantPalette.primary,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
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

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    this.maxLines = 1,
    this.prefix,
    this.keyboardType,
  });

  final TextEditingController controller;
  final int maxLines;
  final String? prefix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
