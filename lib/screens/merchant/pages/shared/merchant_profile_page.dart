import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../auth/auth_scope.dart';
import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/merchant_models.dart';
import '../../../../widgets/location_picker_page.dart';
import '../../merchant_ui.dart';

class MerchantProfilePage extends StatefulWidget {
  const MerchantProfilePage({super.key});

  @override
  State<MerchantProfilePage> createState() => _MerchantProfilePageState();
}

class _MerchantProfilePageState extends State<MerchantProfilePage> {
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _openCtrl = TextEditingController();
  final _closeCtrl = TextEditingController();
  final _picker = ImagePicker();

  MerchantProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _photoUrl = '';
  double? _latitude;
  double? _longitude;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await MerchantRepository.getProfile();
    if (!mounted) return;
    final profile = result.data;
    if (profile != null) {
      _nameCtrl.text = profile.businessName;
      _descriptionCtrl.text = profile.description;
      _phoneCtrl.text = profile.phone;
      _addressCtrl.text = profile.address;
      _openCtrl.text = profile.openTime;
      _closeCtrl.text = profile.closeTime;
      _photoUrl = profile.photoUrl;
      _latitude = profile.latitude;
      _longitude = profile.longitude;
      _categories = [...profile.categories];
    }
    setState(() {
      _profile = profile;
      _error = result.error;
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1000,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    setState(() {
      _photoUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _useCurrentLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin lokasi belum diberikan')),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      if (_addressCtrl.text.trim().isEmpty) {
        _addressCtrl.text =
            'Lokasi merchant (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
      }
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute<PickedLocation>(
        builder: (_) => LocationPickerPage(
          title: 'Pilih Lokasi Merchant',
          initialAddress: _addressCtrl.text,
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          primaryColor: MerchantPalette.primary,
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _addressCtrl.text = result.address;
      _latitude = result.latitude;
      _longitude = result.longitude;
    });
  }

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah kategori'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Contoh: Express'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || value.isEmpty) return;
    setState(() {
      if (!_categories.contains(value)) _categories.add(value);
    });
  }

  Future<void> _save() async {
    final auth = AuthScope.of(context);
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama merchant wajib diisi')),
      );
      return;
    }

    setState(() => _saving = true);
    final result = await MerchantRepository.updateProfile(
      businessName: _nameCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      photoUrl: _photoUrl,
      openTime: _openCtrl.text.trim().isEmpty ? '08:00' : _openCtrl.text.trim(),
      closeTime:
          _closeCtrl.text.trim().isEmpty ? '21:00' : _closeCtrl.text.trim(),
      categories: _categories,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isSuccess && result.data != null) {
      await auth.updateDisplayName(result.data!.businessName);
      if (!mounted) return;
      setState(() => _profile = result.data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil merchant berhasil disimpan')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Gagal menyimpan profil')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final profile = _profile;

    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'Edit Profil Merchant',
        showAvatar: false,
        actionLabel: _saving ? 'Menyimpan...' : 'Simpan',
        onAction: _saving || _loading ? null : _save,
      ),
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 120),
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
        else if (profile != null) ...[
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipOval(
                        child: MerchantImage(
                          url: _photoUrl,
                          icon: profile.merchantType == 'laundry'
                              ? Icons.local_laundry_service_outlined
                              : Icons.restaurant_rounded,
                          width: 126,
                          height: 126,
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: 8,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: MerchantPalette.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _nameCtrl.text.trim().isEmpty
                      ? profile.businessName
                      : _nameCtrl.text.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MerchantPalette.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'ID Merchant: ${profile.merchantCode}',
                  style: const TextStyle(
                    color: MerchantPalette.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          MerchantCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_outlined,
                        color: MerchantPalette.primary, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Performa Merchant',
                      style: TextStyle(
                        color: MerchantPalette.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _PerformanceBox(
                        value: profile.rating.toStringAsFixed(1),
                        label: 'RATING TOKO',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _PerformanceBox(
                        value: profile.reviewCount.toString(),
                        label: 'TOTAL ULASAN',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rating dihitung otomatis dari seluruh ulasan user.',
                  style: TextStyle(
                    color: MerchantPalette.muted,
                    fontSize: 12,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _ProfileInput(
            icon: Icons.store_mall_directory_outlined,
            label: 'Nama Merchant',
            controller: _nameCtrl,
          ),
          const SizedBox(height: 22),
          _ProfileInput(
            icon: Icons.description_outlined,
            label: 'Deskripsi Merchant',
            controller: _descriptionCtrl,
            maxLines: 4,
          ),
          const SizedBox(height: 22),
          _ProfileInput(
            icon: Icons.phone_outlined,
            label: 'Nomor Kontak',
            controller: _phoneCtrl,
          ),
          const SizedBox(height: 22),
          _ProfileInput(
            icon: Icons.location_on_outlined,
            label: 'Lokasi Merchant',
            controller: _addressCtrl,
            suffix: Icons.my_location_rounded,
            onSuffixTap: _useCurrentLocation,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                _latitude == null || _longitude == null
                    ? 'Pilih Titik Map'
                    : 'Ubah Titik Map',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: MerchantPalette.primary,
                side: const BorderSide(color: MerchantPalette.primary),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (_latitude != null && _longitude != null) ...[
            const SizedBox(height: 8),
            Text(
              'Koordinat: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
              style: const TextStyle(
                color: MerchantPalette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _ProfileInput(
                  icon: Icons.schedule_rounded,
                  label: 'Jam Buka',
                  controller: _openCtrl,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ProfileInput(
                  icon: Icons.schedule_outlined,
                  label: 'Jam Tutup',
                  controller: _closeCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _CategorySection(
            categories: _categories,
            onAdd: _addCategory,
            onRemove: (category) {
              setState(() => _categories.remove(category));
            },
          ),
          const SizedBox(height: 34),
          const Divider(height: 1),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => auth.logout(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Keluar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MerchantPalette.primary,
                side: const BorderSide(color: MerchantPalette.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const MerchantBottomSpacer(),
        ],
      ],
    );
  }
}

class _PerformanceBox extends StatelessWidget {
  const _PerformanceBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MerchantPalette.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: MerchantPalette.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: MerchantPalette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInput extends StatelessWidget {
  const _ProfileInput({
    required this.icon,
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.suffix,
    this.onSuffixTap,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final IconData? suffix;
  final VoidCallback? onSuffixTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: MerchantPalette.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: MerchantPalette.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
            color: MerchantPalette.text,
            fontSize: 16,
            height: 1.38,
          ),
          decoration: InputDecoration(
            suffixIcon: suffix == null
                ? null
                : IconButton(
                    icon: Icon(suffix, color: MerchantPalette.primary),
                    onPressed: onSuffixTap,
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
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categories,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> categories;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.category_outlined,
                color: MerchantPalette.primary, size: 18),
            SizedBox(width: 8),
            Text(
              'Kategori Layanan',
              style: TextStyle(
                color: MerchantPalette.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...categories.map(
              (category) => InkWell(
                onTap: () => onRemove(category),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: MerchantPalette.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$category x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFC9D3E1)),
                ),
                child: const Text(
                  '+ Tambah Kategori',
                  style: TextStyle(
                    color: MerchantPalette.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
