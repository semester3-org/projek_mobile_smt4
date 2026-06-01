import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final _picker = ImagePicker();
  UserProfile? _profile;
  bool _loading = true;
  bool _didLoad = false;
  bool _savingPhoto = false;

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

  Future<void> _pickProfilePhoto(UserProfile profile) async {
    if (_savingPhoto) return;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 78,
        maxWidth: 900,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      if (!mounted) return;
      setState(() => _savingPhoto = true);
      final result = await UserRepository.updateProfile(
        displayName: profile.displayName,
        phone: profile.phone ?? '',
        address: profile.address ?? '',
        latitude: profile.latitude,
        longitude: profile.longitude,
        photoUrl: 'data:image/$ext;base64,${base64Encode(bytes)}',
      );
      if (!mounted) return;
      setState(() {
        _savingPhoto = false;
        if (result.data != null) _profile = result.data;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess
                ? 'Foto profil berhasil diperbarui'
                : result.error ?? 'Gagal memperbarui foto profil',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memilih foto')),
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
    return label.isEmpty ? '-' : label;
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
    return trimmed.isEmpty ? '-' : trimmed;
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
                GestureDetector(
                  onTap: () => _pickProfilePhoto(profile),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: UserTheme.softBlue,
                        backgroundImage: _profileImage(profile.photoUrl),
                        child: _savingPhoto
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : _profileImage(profile.photoUrl) == null
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
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: UserTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                TextButton.icon(
                  onPressed: () => _openEditProfile(profile),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit profil'),
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
          const SizedBox(height: 18),
          const _SectionTitle('Pengaturan'),
          const SizedBox(height: 12),
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
  bool _saving = false;
  bool _dirty = false;
  late String _originalFingerprint;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameCtrl = TextEditingController(text: profile.displayName);
    _phoneCtrl = TextEditingController(text: profile.phone ?? '');
    _originalFingerprint = _fingerprint();
    _nameCtrl.addListener(_refreshDirty);
    _phoneCtrl.addListener(_refreshDirty);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_dirty || _saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = AuthScope.of(context);
    setState(() => _saving = true);
    final result = await UserRepository.updateProfile(
      displayName: _nameCtrl.text,
      phone: _phoneCtrl.text,
      address: widget.profile.address ?? '',
      latitude: widget.profile.latitude,
      longitude: widget.profile.longitude,
      photoUrl: widget.profile.photoUrl ?? '',
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isSuccess && result.data != null) {
      await auth.updateDisplayName(result.data!.displayName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );
      setState(() {
        _dirty = false;
        _originalFingerprint = _fingerprint();
      });
      Navigator.of(context).pop(result.data);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Gagal memperbarui profil')),
    );
  }

  String _fingerprint() {
    String norm(String value) => value.trim();
    return [
      norm(_nameCtrl.text),
      norm(_phoneCtrl.text),
    ].join('|');
  }

  void _refreshDirty() {
    if (!mounted) return;
    final next = _fingerprint() != _originalFingerprint;
    if (next != _dirty) setState(() => _dirty = next);
  }

  Future<bool> _confirmClose() async {
    if (!_dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perubahan belum disimpan'),
        content: const Text('Simpan perubahan profil sebelum menutup form?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Buang'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Lanjut Edit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (choice == 'save') {
      await _submit();
      return false;
    }
    return choice == 'discard';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmClose() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
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
                _ProfileTextField(
                  controller: _nameCtrl,
                  label: 'Nama Lengkap',
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return 'Nama wajib diisi';
                    }
                    if (RegExp(r'\d').hasMatch(text)) {
                      return 'Nama tidak boleh berisi angka';
                    }
                    if (text.length < 3) {
                      return 'Nama minimal 3 karakter';
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
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Nomor telepon wajib diisi';
                    if (!RegExp(r'^[0-9+ ]{10,16}$').hasMatch(text)) {
                      return 'Nomor telepon tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                if (await _confirmClose() && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving || !_dirty ? null : _submit,
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
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: 1,
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
