import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../auth/auth_scope.dart';
import '../../../../data/repositories/merchant_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../models/merchant_models.dart';
import '../../../../widgets/location_picker_page.dart';
import '../../merchant_ui.dart';
import 'merchant_product_reviews_page.dart';

class MerchantProfilePage extends StatefulWidget {
  const MerchantProfilePage({super.key});

  @override
  State<MerchantProfilePage> createState() => _MerchantProfilePageState();
}

class _MerchantProfilePageState extends State<MerchantProfilePage> {
  final _scrollCtrl = ScrollController();
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
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
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isSuccess && result.data != null) {
      await auth.updateDisplayName(result.data!.businessName);
      if (!mounted) return;
      setState(() => _profile = result.data);
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil merchant berhasil disimpan')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Gagal menyimpan profil')),
    );
  }

  Future<void> _openChangePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (!mounted || changed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kata sandi berhasil diubah')),
    );
  }

  Future<void> _pickOperationalTime(TextEditingController controller) async {
    final initial = _timeOfDayFromText(controller.text);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: MerchantPalette.primary,
                  ),
            ),
            child: child!,
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      controller.text = _formatTimeOfDay(picked);
    });
  }

  TimeOfDay _timeOfDayFromText(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 8, minute: 0);
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final profile = _profile;
    final email = profile?.email.isNotEmpty == true
        ? profile!.email
        : auth.session?.email ?? '-';

    return MerchantPage(
      scrollController: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      topBar: MerchantTopBar(
        title: 'Profil',
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
          _ErrorCard(error: _error!, onRetry: _load)
        else if (profile != null) ...[
          _MerchantProfileHeader(
            profile: profile,
            photoUrl: _photoUrl,
            displayName: _nameCtrl.text.trim().isEmpty
                ? profile.businessName
                : _nameCtrl.text.trim(),
            onTap: _pickPhoto,
          ),
          const SizedBox(height: 14),
          _PerformanceSection(
            profile: profile,
            onReviewsTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MerchantProductReviewsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: email,
          ),
          _InfoTile(
            icon: profile.merchantType == 'laundry'
                ? Icons.local_laundry_service_outlined
                : Icons.restaurant_outlined,
            label: 'Jenis Merchant',
            value: profile.merchantType == 'laundry' ? 'Laundry' : 'Catering',
          ),
          _InfoTile(
            icon: Icons.badge_outlined,
            label: 'ID Merchant',
            value: profile.merchantCode.isEmpty
                ? profile.id
                : profile.merchantCode,
          ),
          _InfoTile(
            icon: Icons.schedule_rounded,
            label: 'Jam Operasional',
            value: '${_openCtrl.text.trim()} - ${_closeCtrl.text.trim()}',
          ),
          const SizedBox(height: 18),
          _ProfileFormCard(
            nameController: _nameCtrl,
            descriptionController: _descriptionCtrl,
            phoneController: _phoneCtrl,
            addressController: _addressCtrl,
            openController: _openCtrl,
            closeController: _closeCtrl,
            latitude: _latitude,
            longitude: _longitude,
            onUseCurrentLocation: _useCurrentLocation,
            onPickLocation: _pickLocation,
            onPickOpenTime: () => _pickOperationalTime(_openCtrl),
            onPickCloseTime: () => _pickOperationalTime(_closeCtrl),
          ),
          const SizedBox(height: 18),
          _ActionTile(
            icon: Icons.lock_reset_rounded,
            label: 'Ubah Kata Sandi',
            onTap: _openChangePassword,
          ),
          _ActionTile(
            icon: Icons.logout_rounded,
            label: 'Keluar',
            danger: true,
            onTap: () {
              auth.logout();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          const MerchantBottomSpacer(),
        ],
      ],
    );
  }
}

class _MerchantProfileHeader extends StatelessWidget {
  const _MerchantProfileHeader({
    required this.profile,
    required this.photoUrl,
    required this.displayName,
    required this.onTap,
  });

  final MerchantProfile profile;
  final String photoUrl;
  final String displayName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [MerchantPalette.shadow(opacity: 0.05)],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: MerchantImage(
                      url: photoUrl,
                      icon: profile.merchantType == 'laundry'
                          ? Icons.local_laundry_service_outlined
                          : Icons.restaurant_rounded,
                      width: 72,
                      height: 72,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: 2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: MerchantPalette.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPalette.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.address.isEmpty
                          ? 'Alamat merchant belum diisi'
                          : profile.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: MerchantPalette.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_rounded, color: MerchantPalette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerformanceSection extends StatelessWidget {
  const _PerformanceSection({
    required this.profile,
    required this.onReviewsTap,
  });

  final MerchantProfile profile;
  final VoidCallback onReviewsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [MerchantPalette.shadow(opacity: 0.05)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performa Merchant',
            style: TextStyle(
              color: MerchantPalette.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PerformanceBox(
                  value: profile.rating.toStringAsFixed(1),
                  label: 'Rating',
                  icon: Icons.star_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PerformanceBox(
                  value: profile.reviewCount.toString(),
                  label: 'Ulasan',
                  icon: Icons.rate_review_outlined,
                  onTap: onReviewsTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceBox extends StatelessWidget {
  const _PerformanceBox({
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: MerchantPalette.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: MerchantPalette.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: MerchantPalette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: MerchantPalette.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileFormCard extends StatelessWidget {
  const _ProfileFormCard({
    required this.nameController,
    required this.descriptionController,
    required this.phoneController,
    required this.addressController,
    required this.openController,
    required this.closeController,
    required this.latitude,
    required this.longitude,
    required this.onUseCurrentLocation,
    required this.onPickLocation,
    required this.onPickOpenTime,
    required this.onPickCloseTime,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController openController;
  final TextEditingController closeController;
  final double? latitude;
  final double? longitude;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onPickLocation;
  final VoidCallback onPickOpenTime;
  final VoidCallback onPickCloseTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [MerchantPalette.shadow(opacity: 0.05)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail Merchant',
            style: TextStyle(
              color: MerchantPalette.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          _ProfileInput(
            icon: Icons.store_mall_directory_outlined,
            label: 'Nama Merchant',
            controller: nameController,
          ),
          const SizedBox(height: 12),
          _ProfileInput(
            icon: Icons.description_outlined,
            label: 'Deskripsi Merchant',
            controller: descriptionController,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          _ProfileInput(
            icon: Icons.phone_outlined,
            label: 'Nomor Kontak',
            controller: phoneController,
          ),
          const SizedBox(height: 12),
          _ProfileInput(
            icon: Icons.location_on_outlined,
            label: 'Lokasi Merchant',
            controller: addressController,
            suffix: Icons.my_location_rounded,
            onSuffixTap: onUseCurrentLocation,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPickLocation,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                latitude == null || longitude == null
                    ? 'Pilih Titik Map'
                    : 'Ubah Titik Map',
              ),
            ),
          ),
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 8),
            Text(
              'Koordinat: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
              style: const TextStyle(
                color: MerchantPalette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimePickerTile(
                  icon: Icons.schedule_rounded,
                  label: 'Jam Buka',
                  value: openController.text.trim().isEmpty
                      ? '08:00'
                      : openController.text.trim(),
                  onTap: onPickOpenTime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePickerTile(
                  icon: Icons.schedule_outlined,
                  label: 'Jam Tutup',
                  value: closeController.text.trim().isEmpty
                      ? '21:00'
                      : closeController.text.trim(),
                  onTap: onPickCloseTime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: MerchantPalette.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: MerchantPalette.muted)),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    color: MerchantPalette.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: MerchantPalette.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: MerchantPalette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        color: MerchantPalette.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: MerchantPalette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? MerchantPalette.danger : MerchantPalette.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          enabled: onTap != null,
          leading: Icon(icon, color: color),
          title: Text(
            label,
            style: TextStyle(color: danger ? color : MerchantPalette.text),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          onTap: onTap,
        ),
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
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix == null
            ? null
            : IconButton(
                icon: Icon(suffix),
                onPressed: onSuffixTap,
              ),
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error, style: const TextStyle(color: MerchantPalette.danger)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Muat Ulang')),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final result = await UserRepository.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Gagal mengubah kata sandi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ubah Kata Sandi',
                style: TextStyle(
                  color: MerchantPalette.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _PasswordField(
                controller: _currentCtrl,
                label: 'Kata Sandi Saat Ini',
                obscureText: _obscureCurrent,
                onToggle: () {
                  setState(() => _obscureCurrent = !_obscureCurrent);
                },
                validator: (value) {
                  if ((value ?? '').isEmpty) {
                    return 'Kata sandi saat ini wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _newCtrl,
                label: 'Kata Sandi Baru',
                obscureText: _obscureNew,
                onToggle: () {
                  setState(() => _obscureNew = !_obscureNew);
                },
                validator: (value) {
                  if ((value ?? '').length < 4) return 'Minimal 4 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _confirmCtrl,
                label: 'Konfirmasi Kata Sandi Baru',
                obscureText: _obscureConfirm,
                onToggle: () {
                  setState(() => _obscureConfirm = !_obscureConfirm);
                },
                validator: (value) {
                  if (value != _newCtrl.text) return 'Konfirmasi tidak sama';
                  return null;
                },
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
