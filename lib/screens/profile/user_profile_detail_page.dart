import 'dart:convert';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/auth_scope.dart';
import '../../auth/roles.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/user_profile.dart';
import '../user/user_theme.dart';

class UserProfileDetailPage extends StatefulWidget {
  const UserProfileDetailPage({super.key});

  @override
  State<UserProfileDetailPage> createState() => _UserProfileDetailPageState();
}

class _UserProfileDetailPageState extends State<UserProfileDetailPage> {
  final _scrollCtrl = ScrollController();
  UserProfile? _profile;
  bool _loading = true;
  bool _didLoad = false;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final session = AuthScope.of(context).session;
    final result = await UserRepository.getProfile(
      displayName: session?.displayName ?? 'User',
      email: session?.email ?? '',
      role: session?.role.label ?? 'User',
    );

    if (!mounted) return;
    setState(() {
      _profile = result.data ??
          UserProfile(
            id: '',
            email: session?.email ?? '',
            displayName: session?.displayName ?? 'User',
            role: session?.role.label ?? 'User',
          );
      _loading = false;
    });
  }

  Future<void> _openEditProfile(UserProfile profile) async {
    final updatedProfile = await showDialog<UserProfile>(
      context: context,
      builder: (_) => _EditProfileDialog(profile: profile),
    );

    if (updatedProfile == null || !mounted) return;
    setState(() => _profile = updatedProfile);
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _openChangePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );

    if (changed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kata sandi berhasil diubah')),
    );
  }

  String _roomLabel(UserProfile? profile) {
    final rooms = [
      if ((profile?.roomNumber ?? '').isNotEmpty) 'No ${profile!.roomNumber}',
      if ((profile?.roomType ?? '').isNotEmpty) profile!.roomType!,
    ];
    final label = rooms.join(' - ');
    return label.isEmpty ? 'Belum diisi' : label;
  }

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed[0].toUpperCase();
  }

  ImageProvider? _profileImage(String? photoUrl) {
    final value = photoUrl?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('data:image')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex == -1) return null;
      try {
        return MemoryImage(base64Decode(value.substring(commaIndex + 1)));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(value);
  }

  String _optionalValue(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? 'Belum diisi' : trimmed;
  }

  Widget _buildBody() {
    final profile = _profile;
    if (profile == null) {
      return const Center(child: Text('Profil belum tersedia'));
    }

    return RefreshIndicator(
      onRefresh: _loadUserProfile,
      color: UserTheme.primary,
      child: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [UserTheme.softShadow(opacity: 0.05)],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: UserTheme.softBlue,
                  backgroundImage: _profileImage(profile.photoUrl),
                  child: _profileImage(profile.photoUrl) == null
                      ? Text(
                          _initial(profile.displayName),
                          style: const TextStyle(
                            color: UserTheme.primary,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    color: UserTheme.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  profile.email,
                  style: const TextStyle(color: UserTheme.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: UserTheme.softBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    profile.role,
                    style: const TextStyle(
                      color: UserTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Informasi Pribadi'),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: profile.email.isEmpty ? '-' : profile.email,
          ),
          _InfoTile(
            icon: Icons.home_work_outlined,
            label: 'Nama Kos',
            value: profile.kosName ?? 'Belum tersambung',
          ),
          _InfoTile(
            icon: Icons.key_outlined,
            label: 'Kode Unik Kos',
            value: profile.kosAccessCode ?? 'Belum tersedia',
          ),
          _InfoTile(
            icon: Icons.bed_outlined,
            label: 'Kamar',
            value: _roomLabel(profile),
          ),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Nomor Telepon',
            value: _optionalValue(profile.phone),
          ),
          _InfoTile(
            icon: Icons.location_on_outlined,
            label: 'Alamat',
            value: _optionalValue(profile.address),
          ),
          _InfoTile(
            icon: Icons.map_outlined,
            label: 'Koordinat',
            value: profile.latitude == null || profile.longitude == null
                ? 'Belum dipilih'
                : '${profile.latitude!.toStringAsFixed(6)}, ${profile.longitude!.toStringAsFixed(6)}',
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Pengaturan'),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.edit_outlined,
            label: 'Edit Profil',
            onTap: () => _openEditProfile(profile),
          ),
          _ActionTile(
            icon: Icons.lock_outline,
            label: 'Ubah Kata Sandi',
            onTap: _openChangePassword,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Profil Saya',
          style: TextStyle(
            color: UserTheme.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.profile});

  final UserProfile profile;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  String _photoValue = '';
  double? _latitude;
  double? _longitude;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameCtrl = TextEditingController(text: profile.displayName);
    _phoneCtrl = TextEditingController(text: profile.phone ?? '');
    _addressCtrl = TextEditingController(text: profile.address ?? '');
    _photoValue = profile.photoUrl ?? '';
    _latitude = profile.latitude;
    _longitude = profile.longitude;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  ImageProvider? _selectedImage() {
    final value = _photoValue.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('data:image')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex == -1) return null;
      try {
        return MemoryImage(base64Decode(value.substring(commaIndex + 1)));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(value);
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 78,
        maxWidth: 800,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoValue = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memilih foto')),
      );
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<_PickedLocation>(
      MaterialPageRoute<_PickedLocation>(
        builder: (_) => _LocationPickerPage(
          initialAddress: _addressCtrl.text,
          initialLatitude: _latitude,
          initialLongitude: _longitude,
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = AuthScope.of(context);
    setState(() => _saving = true);
    final result = await UserRepository.updateProfile(
      displayName: _nameCtrl.text,
      phone: _phoneCtrl.text,
      address: _addressCtrl.text,
      latitude: _latitude,
      longitude: _longitude,
      photoUrl: _photoValue,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isSuccess && result.data != null) {
      await auth.updateDisplayName(result.data!.displayName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );
      Navigator.of(context).pop(result.data);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Gagal memperbarui profil')),
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
                'Edit Profil',
                style: TextStyle(
                  color: UserTheme.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: UserTheme.softBlue,
                      backgroundImage: _selectedImage(),
                      child: _selectedImage() == null
                          ? Text(
                              _nameCtrl.text.trim().isEmpty
                                  ? 'U'
                                  : _nameCtrl.text.trim()[0].toUpperCase(),
                              style: const TextStyle(
                                color: UserTheme.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _pickPhoto,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Pilih Foto'),
                        ),
                        if (_photoValue.trim().isNotEmpty)
                          TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _photoValue = ''),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Hapus'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _ProfileTextField(
                controller: _nameCtrl,
                label: 'Nama Lengkap',
                icon: Icons.person_outline_rounded,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Nama wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _ProfileTextField(
                controller: _phoneCtrl,
                label: 'Nomor Telepon',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _ProfileTextField(
                controller: _addressCtrl,
                label: 'Alamat',
                icon: Icons.location_on_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _pickLocation,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    _latitude == null || _longitude == null
                        ? 'Pilih Lokasi dari Peta'
                        : 'Ubah Lokasi dari Peta',
                  ),
                ),
              ),
              if (_latitude != null && _longitude != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: UserTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
                      style: FilledButton.styleFrom(
                        backgroundColor: UserTheme.primary,
                      ),
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
                  color: UserTheme.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _ProfileTextField(
                controller: _currentCtrl,
                label: 'Kata Sandi Saat Ini',
                icon: Icons.lock_outline,
                obscureText: _obscureCurrent,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscureCurrent = !_obscureCurrent);
                  },
                  icon: Icon(
                    _obscureCurrent
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) {
                    return 'Kata sandi saat ini wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _ProfileTextField(
                controller: _newCtrl,
                label: 'Kata Sandi Baru',
                icon: Icons.lock_reset_outlined,
                obscureText: _obscureNew,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscureNew = !_obscureNew);
                  },
                  icon: Icon(
                    _obscureNew
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').length < 4) {
                    return 'Minimal 4 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _ProfileTextField(
                controller: _confirmCtrl,
                label: 'Konfirmasi Kata Sandi Baru',
                icon: Icons.verified_user_outlined,
                obscureText: _obscureConfirm,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) {
                  if (value != _newCtrl.text) {
                    return 'Konfirmasi tidak sama';
                  }
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
                      style: FilledButton.styleFrom(
                        backgroundColor: UserTheme.primary,
                      ),
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

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
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

class _PickedLocation {
  const _PickedLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;
}

class _LocationPickerPage extends StatefulWidget {
  const _LocationPickerPage({
    required this.initialAddress,
    required this.initialLatitude,
    required this.initialLongitude,
  });

  final String initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<_LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<_LocationPickerPage> {
  static const LatLng _defaultCenter = LatLng(-6.200000, 106.816666);

  final MapController _mapController = MapController();
  late LatLng _selectedPoint;
  late String _address;
  bool _loadingAddress = false;
  bool _loadingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint = LatLng(
      widget.initialLatitude ?? _defaultCenter.latitude,
      widget.initialLongitude ?? _defaultCenter.longitude,
    );
    _address = widget.initialAddress.trim();
    if (widget.initialLatitude == null || widget.initialLongitude == null) {
      _moveToCurrentLocation();
    } else if (_address.isEmpty) {
      _reverseGeocode(_selectedPoint);
    }
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _loadingCurrentLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _reverseGeocode(_selectedPoint);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _reverseGeocode(_selectedPoint);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedPoint = point;
        _address = 'Mencari alamat...';
        _loadingAddress = true;
      });
      _mapController.move(point, 16);
      await _reverseGeocode(point);
    } catch (_) {
      if (mounted) await _reverseGeocode(_selectedPoint);
    } finally {
      if (mounted) setState(() => _loadingCurrentLocation = false);
    }
  }

  Future<void> _selectPoint(LatLng point) async {
    setState(() {
      _selectedPoint = point;
      _loadingAddress = true;
      _address = 'Mencari alamat...';
    });
    await _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
      });
      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Accept-Language': 'id',
          'User-Agent': 'KosFinder/1.0 (com.example.projek_mobile)',
        },
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        setState(() {
          _address = displayName?.trim().isNotEmpty == true
              ? displayName!.trim()
              : _coordinateLabel(point);
          _loadingAddress = false;
        });
        return;
      }
    } catch (_) {
      if (!mounted) return;
    }

    setState(() {
      _address = _coordinateLabel(point);
      _loadingAddress = false;
    });
  }

  String _coordinateLabel(LatLng point) {
    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  void _saveLocation() {
    Navigator.of(context).pop(
      _PickedLocation(
        address: _address.trim().isEmpty ? _coordinateLabel(_selectedPoint) : _address,
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Pilih Lokasi',
          style: TextStyle(
            color: UserTheme.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPoint,
              initialZoom: widget.initialLatitude == null ? 12 : 16,
              onTap: (_, point) => _selectPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.projek_mobile',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPoint,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_pin,
                      color: UserTheme.danger,
                      size: 46,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 16,
            top: 16,
            child: FloatingActionButton.small(
              heroTag: 'current-location',
              onPressed:
                  _loadingCurrentLocation ? null : _moveToCurrentLocation,
              backgroundColor: Colors.white,
              foregroundColor: UserTheme.primary,
              child: _loadingCurrentLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [UserTheme.softShadow(opacity: 0.12)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _loadingAddress
                            ? Icons.hourglass_top_rounded
                            : Icons.place_outlined,
                        color: UserTheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _address.trim().isEmpty
                              ? _coordinateLabel(_selectedPoint)
                              : _address,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: UserTheme.text,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loadingAddress ? null : _saveLocation,
                      style: FilledButton.styleFrom(
                        backgroundColor: UserTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Gunakan Lokasi Ini'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: UserTheme.text,
        fontWeight: FontWeight.w900,
        fontSize: 18,
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
          Icon(icon, color: UserTheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: UserTheme.muted)),
                const SizedBox(height: 4),
                Text(
                  value,
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
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          leading: Icon(icon, color: UserTheme.primaryDark),
          title: Text(
            label,
            style: const TextStyle(color: UserTheme.text),
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
