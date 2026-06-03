import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../app/app_theme.dart';
import '../../../auth/auth_scope.dart';
import '../../../core/api_service.dart';
import '../../../core/runtime_permission_service.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../models/kos_listing.dart';
import '../../../models/user_profile.dart';
import '../../../widgets/location_picker_page.dart';
import '../../../widgets/logout_confirm_dialog.dart';
import 'owner_help_page.dart';
import 'owner_notifications_page.dart';
import 'owner_security_page.dart';

class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key});

  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  static const String _ktpWatermark = 'HANYA UNTUK VERIFIKASI APLIKASI KOS';

  bool _loading = true;
  bool _savingProfile = false;
  String? _error;
  UserProfile? _profile;
  List<KosListing> _kosListings = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = AuthScope.of(context).session;
    setState(() {
      _loading = true;
      _error = null;
    });

    final profileResult = await UserRepository.getProfile(
      displayName: session?.displayName ?? 'Owner',
      email: session?.email ?? '',
      role: 'owner',
      forceRefresh: true,
    );
    final listingResult = await KosListingRepository.getMyListings();
    if (!mounted) return;

    setState(() {
      _profile = profileResult.data;
      _kosListings = listingResult.data ?? [];
      _error = listingResult.error ?? profileResult.error;
      _loading = false;
    });
  }

  String get _kosCountLabel {
    final count = _kosListings.length;
    if (count == 0) return 'Belum ada kos terdaftar';
    return '$count kos terdaftar';
  }

  String get _accessCodeSummary {
    final codes = _kosListings
        .map((kos) => kos.accessCode.trim())
        .where((code) => code.isNotEmpty)
        .toList();
    if (codes.isEmpty) return 'Belum tersedia';
    if (codes.length == 1) return codes.first;
    return '${codes.length} kode akses tersedia';
  }

  String get _ownerContact {
    final profilePhone = _profile?.phone?.trim() ?? '';
    if (profilePhone.isNotEmpty) return profilePhone;
    if (_kosListings.isEmpty) return '-';
    final contact = _kosListings.first.ownerContact.trim();
    return contact.isEmpty ? '-' : contact;
  }

  String get _verificationStatus {
    final status = (_profile?.ownerVerificationStatus ?? 'draft').trim();
    return status.isEmpty ? 'draft' : status;
  }

  String get _verificationStatusLabel {
    return switch (_verificationStatus) {
      'pending' => 'Pending',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Draft',
    };
  }

  String get _verificationMessage {
    final reason = (_profile?.ownerVerificationRejectionReason ?? '').trim();
    return switch (_verificationStatus) {
      'pending' => 'Profil sedang menunggu verifikasi admin.',
      'approved' =>
        'Profil owner sudah terverifikasi. Anda bisa menambahkan kos dan kamar.',
      'rejected' => reason.isEmpty
          ? 'Profil owner ditolak. Perbaiki profil dan upload ulang KTP.'
          : 'Profil owner ditolak: $reason',
      _ =>
        'Profil owner belum lengkap. Lengkapi profil dan upload foto KTP untuk dapat menambahkan kamar.',
    };
  }

  String _formatCoordinate(double? value) {
    if (value == null) return 'Belum diatur';
    return value.toStringAsFixed(6);
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

  bool _isCoordinateAddress(String value) {
    return RegExp(r'^\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*$')
        .hasMatch(value.trim());
  }

  Future<String?> _reverseGeocodeAddress(
      double latitude, double longitude) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
      });
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'projek-mobile-owner-profile/1.0',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final displayName = data['display_name'] as String?;
      final address = displayName?.trim() ?? '';
      return address.isEmpty || _isCoordinateAddress(address) ? null : address;
    } catch (_) {
      return null;
    }
  }

  Future<String> _initialOwnerAddress() async {
    final address = (_profile?.address ?? '').trim();
    final latitude = _profile?.latitude;
    final longitude = _profile?.longitude;
    if (address.isNotEmpty && !_isCoordinateAddress(address)) {
      return address;
    }
    if (latitude == null || longitude == null) return '';
    return await _reverseGeocodeAddress(latitude, longitude) ?? '';
  }

  Future<String?> _pickProfilePhoto() async {
    try {
      final hasPermission =
          await RuntimePermissionService.ensureGalleryPermission(context);
      if (!hasPermission) return null;
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 78,
        maxWidth: 800,
      );
      if (file == null) return null;

      final bytes = await file.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memilih foto')),
      );
      return null;
    }
  }

  Future<String?> _captureKtpPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 1200,
      );
      if (file == null) return null;

      final bytes = await file.readAsBytes();
      final watermarkedBytes = await _applyKtpWatermark(bytes);
      return 'data:image/png;base64,${base64Encode(watermarkedBytes)}';
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil foto KTP')),
      );
      return null;
    }
  }

  Future<Uint8List> _applyKtpWatermark(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(image, Offset.zero, Paint());

    final fontSize = (width * 0.045).clamp(22.0, 48.0);
    final painter = TextPainter(
      text: TextSpan(
        text: _ktpWatermark,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
      maxLines: 2,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width * 0.82);

    final center = Offset(width / 2, height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.35);

    final boxPadding = fontSize * 0.45;
    final boxRect = Rect.fromCenter(
      center: Offset.zero,
      width: painter.width + (boxPadding * 2),
      height: painter.height + (boxPadding * 1.6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boxRect, Radius.circular(fontSize * 0.35)),
      Paint()..color = Colors.black.withValues(alpha: 0.34),
    );
    painter.paint(
      canvas,
      Offset(-painter.width / 2, -painter.height / 2),
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final watermarkedImage = await picture.toImage(image.width, image.height);
    final data = await watermarkedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return data?.buffer.asUint8List() ?? bytes;
  }

  Future<void> _openEditProfile() async {
    final auth = AuthScope.of(context);
    final session = auth.session;
    final nameCtrl = TextEditingController(text: session?.displayName ?? '');
    final contactCtrl = TextEditingController(
      text: _ownerContact == '-' ? '' : _ownerContact,
    );
    final addressCtrl =
        TextEditingController(text: await _initialOwnerAddress());
    if (!mounted) return;
    final latitudeCtrl = TextEditingController(
      text: _profile?.latitude == null ? '' : '${_profile!.latitude}',
    );
    final longitudeCtrl = TextEditingController(
      text: _profile?.longitude == null ? '' : '${_profile!.longitude}',
    );
    var photoValue = _profile?.photoUrl ?? '';
    var ktpPhotoValue = _profile?.ktpPhoto ?? '';
    var locating = false;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Profil Owner'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: _OwnerProfileColors.softBlue,
                  backgroundImage: _profileImage(photoValue),
                  child: _profileImage(photoValue) == null
                      ? Text(
                          nameCtrl.text.trim().isEmpty
                              ? 'O'
                              : nameCtrl.text.trim()[0].toUpperCase(),
                          style: const TextStyle(
                            color: _OwnerProfileColors.primary,
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
                      onPressed: () async {
                        final picked = await _pickProfilePhoto();
                        if (picked == null || !dialogContext.mounted) return;
                        setDialogState(() => photoValue = picked);
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Pilih Foto'),
                    ),
                    if (photoValue.trim().isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() => photoValue = '');
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Hapus Foto'),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _KtpUploadPreview(
                  image: _profileImage(ktpPhotoValue),
                  hasImage: ktpPhotoValue.trim().isNotEmpty,
                  onCapture: () async {
                    final captured = await _captureKtpPhoto();
                    if (captured == null || !dialogContext.mounted) return;
                    setDialogState(() => ktpPhotoValue = captured);
                  },
                  onRemove: ktpPhotoValue.trim().isEmpty
                      ? null
                      : () => setDialogState(() => ktpPhotoValue = ''),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama Owner',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: contactCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Kontak Owner',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'Kontak ini disinkronkan ke semua kos.',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alamat',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: locating
                        ? null
                        : () async {
                            setDialogState(() => locating = true);
                            final position = await _getCurrentPosition();
                            if (!dialogContext.mounted) return;
                            setDialogState(() => locating = false);
                            if (position == null) return;
                            latitudeCtrl.text =
                                position.latitude.toStringAsFixed(8);
                            longitudeCtrl.text =
                                position.longitude.toStringAsFixed(8);
                            final address = await _reverseGeocodeAddress(
                              position.latitude,
                              position.longitude,
                            );
                            if (!dialogContext.mounted) return;
                            if (address != null) {
                              setDialogState(() {
                                addressCtrl.text = address;
                              });
                            } else {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Alamat belum ditemukan. Pilih lokasi dari peta atau isi alamat manual.',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_outlined),
                    label: Text(
                      locating
                          ? 'Mengambil lokasi...'
                          : 'Gunakan Lokasi Saat Ini',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(dialogContext)
                          .push<PickedLocation>(
                        MaterialPageRoute<PickedLocation>(
                          builder: (_) => LocationPickerPage(
                            title: 'Pilih Alamat Owner',
                            initialAddress: addressCtrl.text,
                            initialLatitude: double.tryParse(
                              latitudeCtrl.text.trim(),
                            ),
                            initialLongitude: double.tryParse(
                              longitudeCtrl.text.trim(),
                            ),
                            primaryColor: AppTheme.primaryGreen,
                          ),
                        ),
                      );
                      if (result == null || !dialogContext.mounted) return;
                      setDialogState(() {
                        addressCtrl.text = _isCoordinateAddress(result.address)
                            ? addressCtrl.text
                            : result.address;
                        latitudeCtrl.text = result.latitude.toStringAsFixed(8);
                        longitudeCtrl.text =
                            result.longitude.toStringAsFixed(8);
                      });
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Pilih dari Peta'),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: latitudeCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    prefixIcon: Icon(Icons.my_location_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: longitudeCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    prefixIcon: Icon(Icons.explore_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) return;
    await _saveProfile(
      displayName: nameCtrl.text.trim(),
      ownerContact: contactCtrl.text.trim(),
      address: addressCtrl.text.trim(),
      latitude: latitudeCtrl.text.trim(),
      longitude: longitudeCtrl.text.trim(),
      photoUrl: photoValue.trim(),
      ktpPhoto: ktpPhotoValue.trim(),
    );
  }

  Future<Position?> _getCurrentPosition() async {
    final messenger = ScaffoldMessenger.of(context);
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Layanan lokasi belum aktif')),
      );
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Izin lokasi belum diberikan')),
      );
      return null;
    }

    try {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal mengambil lokasi saat ini')),
      );
      return null;
    }
  }

  Future<void> _saveProfile({
    required String displayName,
    required String ownerContact,
    required String address,
    required String latitude,
    required String longitude,
    required String photoUrl,
    required String ktpPhoto,
  }) async {
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama owner wajib diisi')),
      );
      return;
    }
    if (_savingProfile) return;

    final auth = AuthScope.of(context);
    final parsedLatitude = latitude.isEmpty ? null : double.tryParse(latitude);
    final parsedLongitude =
        longitude.isEmpty ? null : double.tryParse(longitude);

    if (latitude.isNotEmpty && parsedLatitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitude harus berupa angka')),
      );
      return;
    }
    if (longitude.isNotEmpty && parsedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Longitude harus berupa angka')),
      );
      return;
    }

    setState(() => _savingProfile = true);

    final profileResult = await UserRepository.updateProfile(
      displayName: displayName,
      phone: ownerContact,
      address: address,
      latitude: parsedLatitude,
      longitude: parsedLongitude,
      photoUrl: photoUrl,
      ktpPhoto: ktpPhoto,
    );

    if (!mounted) return;

    if (!profileResult.isSuccess) {
      setState(() => _savingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(profileResult.error ?? 'Gagal menyimpan profil')),
      );
      return;
    }

    for (final kos in _kosListings) {
      final kosResult = await ApiService.put(
        'api/kos_listings',
        {'owner_contact': ownerContact},
        queryParams: {'id': kos.id},
      );

      if (!mounted) return;

      if (!kosResult.success) {
        setState(() => _savingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kosResult.message ?? 'Gagal menyimpan kontak owner'),
          ),
        );
        return;
      }
    }

    await auth.updateDisplayName(displayName);
    await _load();

    if (!mounted) return;
    setState(() => _savingProfile = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil owner berhasil diperbarui')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final session = auth.session;

    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(
        title: const Text(
          'Profil',
          style: TextStyle(
            color: _OwnerProfileColors.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit profil',
            icon: _savingProfile
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit_outlined),
            onPressed: _savingProfile ? null : _openEditProfile,
          ),
          IconButton(
            tooltip: 'Notifikasi',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OwnerNotificationsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primaryGreen,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  _OwnerProfileHeader(
                    name: session?.displayName ?? 'Owner',
                    subtitle: _kosCountLabel,
                    photoUrl: _profile?.photoUrl,
                    onTap: _savingProfile ? null : _openEditProfile,
                  ),
                  const SizedBox(height: 18),
                  _OwnerSummaryRow(
                    kosCount: _kosListings.length,
                    accessCode: _accessCodeSummary,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ProfileNotice(message: _error!),
                  ],
                  const SizedBox(height: 14),
                  _ProfileNotice(message: _verificationMessage),
                  const SizedBox(height: 24),
                  _OwnerInfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: session?.email ?? '-',
                  ),
                  const _OwnerInfoTile(
                    icon: Icons.verified_user_outlined,
                    label: 'Role',
                    value: 'Owner',
                  ),
                  _OwnerInfoTile(
                    icon: Icons.fact_check_outlined,
                    label: 'Status Verifikasi',
                    value: _verificationStatusLabel,
                  ),
                  _OwnerInfoTile(
                    icon: Icons.home_work_outlined,
                    label: 'Total Kos',
                    value: _kosCountLabel,
                  ),
                  _OwnerInfoTile(
                    icon: Icons.vpn_key_outlined,
                    label: 'Kode Akses',
                    value: _accessCodeSummary,
                  ),
                  _OwnerInfoTile(
                    icon: Icons.phone_outlined,
                    label: 'Kontak Owner',
                    value: _ownerContact,
                  ),
                  _OwnerInfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Foto KTP',
                    value: (_profile?.ktpPhoto ?? '').trim().isEmpty
                        ? 'Belum diupload'
                        : 'Sudah diupload',
                  ),
                  _OwnerInfoTile(
                    icon: Icons.location_on_outlined,
                    label: 'Alamat',
                    value: (_profile?.address ?? '').trim().isEmpty
                        ? 'Belum diatur'
                        : _profile!.address!,
                  ),
                  _OwnerInfoTile(
                    icon: Icons.my_location_outlined,
                    label: 'Latitude',
                    value: _formatCoordinate(_profile?.latitude),
                  ),
                  _OwnerInfoTile(
                    icon: Icons.explore_outlined,
                    label: 'Longitude',
                    value: _formatCoordinate(_profile?.longitude),
                  ),
                  const SizedBox(height: 18),
                  _OwnerActionTile(
                    icon: Icons.edit_outlined,
                    label: 'Edit Profil',
                    onTap: _savingProfile ? () {} : _openEditProfile,
                  ),
                  _OwnerActionTile(
                    icon: Icons.security_rounded,
                    label: 'Keamanan Akun',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const OwnerSecurityPage(),
                        ),
                      );
                    },
                  ),
                  _OwnerActionTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Pusat Bantuan',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const OwnerHelpPage(),
                        ),
                      );
                    },
                  ),
                  _OwnerActionTile(
                    icon: Icons.logout_rounded,
                    label: 'Keluar',
                    danger: true,
                    onTap: () async {
                      if (!await confirmLogout(context)) return;
                      await auth.logout();
                      if (!context.mounted) return;
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _OwnerProfileColors {
  const _OwnerProfileColors._();

  static const Color primary = AppTheme.primaryGreen;
  static const Color primaryDark = Color(0xFF00508F);
  static const Color softBlue = Color(0xFFEAF3FF);
  static const Color text = Color(0xFF20242A);
  static const Color muted = Color(0xFF737B8C);
  static const Color danger = Color(0xFFD82121);

  static BoxShadow softShadow({double opacity = 0.05}) {
    return BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: opacity),
      blurRadius: 24,
      offset: const Offset(0, 12),
    );
  }
}

class _OwnerProfileHeader extends StatelessWidget {
  const _OwnerProfileHeader({
    required this.name,
    required this.subtitle,
    required this.photoUrl,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final String? photoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'O' : name.trim()[0].toUpperCase();
    final image = _profileImage(photoUrl);

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
            boxShadow: [_OwnerProfileColors.softShadow()],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: _OwnerProfileColors.softBlue,
                backgroundImage: image,
                child: image == null
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: _OwnerProfileColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: _OwnerProfileColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _OwnerProfileColors.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Owner',
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: _OwnerProfileColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
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
}

class _OwnerSummaryRow extends StatelessWidget {
  const _OwnerSummaryRow({
    required this.kosCount,
    required this.accessCode,
  });

  final int kosCount;
  final String accessCode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: Icons.apartment_rounded,
            label: 'Total Kos',
            value: '$kosCount',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.vpn_key_rounded,
            label: 'Kode Utama',
            value: accessCode,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _OwnerProfileColors.primary),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(color: _OwnerProfileColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _OwnerProfileColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileNotice extends StatelessWidget {
  const _ProfileNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KtpUploadPreview extends StatelessWidget {
  const _KtpUploadPreview({
    required this.image,
    required this.hasImage,
    required this.onCapture,
    required this.onRemove,
  });

  final ImageProvider? image;
  final bool hasImage;
  final VoidCallback onCapture;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _OwnerProfileColors.softBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _OwnerProfileColors.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.badge_outlined,
                color: _OwnerProfileColors.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Foto KTP',
                  style: TextStyle(
                    color: _OwnerProfileColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Ambil foto KTP',
                onPressed: onCapture,
                icon: const Icon(Icons.camera_alt_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                image: image == null
                    ? null
                    : DecorationImage(
                        image: image!,
                        fit: BoxFit.cover,
                      ),
              ),
              child: image == null
                  ? const Center(
                      child: Text(
                        'Belum ada foto KTP',
                        style: TextStyle(
                          color: _OwnerProfileColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasImage
                      ? 'Watermark aplikasi sudah ditambahkan otomatis.'
                      : 'Tekan ikon kamera untuk mengambil foto KTP.',
                  style: const TextStyle(
                    color: _OwnerProfileColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onRemove != null)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerInfoTile extends StatelessWidget {
  const _OwnerInfoTile({
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
          Icon(icon, color: _OwnerProfileColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: _OwnerProfileColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _OwnerProfileColors.text,
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

class _OwnerActionTile extends StatelessWidget {
  const _OwnerActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color =
        danger ? _OwnerProfileColors.danger : _OwnerProfileColors.primaryDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(
            label,
            style: TextStyle(
              color: danger ? color : _OwnerProfileColors.text,
            ),
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
