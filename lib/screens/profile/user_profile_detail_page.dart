import 'package:flutter/material.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _photoCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  UserProfile? _profile;
  bool _loading = true;
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profile == null) _loadUserProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _photoCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final session = AuthScope.of(context).session;
    final result = await UserRepository.getProfile(
      displayName: session?.displayName ?? 'User',
      email: session?.email ?? '',
      role: session?.role.label ?? 'User',
    );
    if (!mounted) return;

    final profile = result.data ??
        UserProfile(
          id: '',
          email: session?.email ?? '',
          displayName: session?.displayName ?? 'User',
          role: session?.role.label ?? 'User',
        );
    setState(() {
      _profile = profile;
      _nameCtrl.text = profile.displayName;
      _phoneCtrl.text = profile.phone ?? '';
      _addressCtrl.text = profile.address ?? '';
      _photoCtrl.text = profile.photoUrl ?? '';
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false) || _profile == null) {
      return;
    }

    setState(() => _savingProfile = true);
    final updated = _profile!.copyWith(
      displayName: _nameCtrl.text.trim(),
      phone: _emptyToNull(_phoneCtrl.text),
      address: _emptyToNull(_addressCtrl.text),
      photoUrl: _emptyToNull(_photoCtrl.text),
    );
    final result = await UserRepository.updateProfile(updated);
    if (!mounted) return;

    final profile = result.data ?? updated;
    setState(() {
      _profile = profile;
      _savingProfile = false;
    });
    await AuthScope.of(context).updateDisplayName(profile.displayName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil berhasil diperbarui')),
    );
  }

  Future<void> _changePassword() async {
    if (_newPasswordCtrl.text.length < 4) {
      _showSnack('Password baru minimal 4 karakter');
      return;
    }
    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      _showSnack('Konfirmasi password tidak cocok');
      return;
    }
    if (_currentPasswordCtrl.text.isEmpty) {
      _showSnack('Masukkan password saat ini');
      return;
    }

    setState(() => _savingPassword = true);
    final result = await UserRepository.changePassword(
      currentPassword: _currentPasswordCtrl.text,
      newPassword: _newPasswordCtrl.text,
    );
    if (!mounted) return;

    setState(() => _savingPassword = false);
    if (result.isSuccess) {
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _showSnack('Kata sandi berhasil diubah');
    } else {
      _showSnack(result.error ?? 'Gagal mengubah kata sandi');
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

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
      body: _loading || profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                _ProfilePreview(profile: profile),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: _SectionCard(
                    title: 'Informasi Profil',
                    children: [
                      _InputField(
                        controller: _nameCtrl,
                        label: 'Nama',
                        icon: Icons.person_outline_rounded,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Nama wajib diisi';
                          }
                          return null;
                        },
                      ),
                      _InputField(
                        controller: _phoneCtrl,
                        label: 'Nomor Telepon',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      _InputField(
                        controller: _addressCtrl,
                        label: 'Alamat',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                      ),
                      _InputField(
                        controller: _photoCtrl,
                        label: 'URL Foto Profil',
                        icon: Icons.image_outlined,
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 6),
                      FilledButton.icon(
                        onPressed: _savingProfile ? null : _saveProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                            _savingProfile ? 'Menyimpan...' : 'Simpan Profil'),
                        style: FilledButton.styleFrom(
                          backgroundColor: UserTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Ubah Kata Sandi',
                  children: [
                    _PasswordField(
                      controller: _currentPasswordCtrl,
                      label: 'Password Saat Ini',
                      obscure: _obscureCurrent,
                      onToggle: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                    _PasswordField(
                      controller: _newPasswordCtrl,
                      label: 'Password Baru',
                      obscure: _obscureNew,
                      onToggle: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                    _PasswordField(
                      controller: _confirmPasswordCtrl,
                      label: 'Konfirmasi Password',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 6),
                    FilledButton.icon(
                      onPressed: _savingPassword ? null : _changePassword,
                      icon: const Icon(Icons.lock_reset_rounded),
                      label: Text(
                        _savingPassword ? 'Menyimpan...' : 'Simpan Password',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: UserTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ProfilePreview extends StatelessWidget {
  const _ProfilePreview({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile.photoUrl;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [UserTheme.softShadow(opacity: 0.05)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: UserTheme.softBlue,
            backgroundImage: photoUrl == null || photoUrl.isEmpty
                ? null
                : NetworkImage(photoUrl),
            child: photoUrl == null || photoUrl.isEmpty
                ? Text(
                    profile.displayName.isEmpty
                        ? 'U'
                        : profile.displayName[0].toUpperCase(),
                    style: const TextStyle(
                      color: UserTheme.primary,
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
                  profile.displayName,
                  style: const TextStyle(
                    color: UserTheme.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(profile.email,
                    style: const TextStyle(color: UserTheme.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: UserTheme.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
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
    required this.obscure,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            onPressed: onToggle,
            icon: Icon(obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
          ),
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
