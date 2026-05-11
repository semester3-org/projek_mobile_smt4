import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../auth/roles.dart';
import '../../data/repositories/user_repository.dart';
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
    try {
      // Ambil session dari auth
      final auth = AuthScope.of(context);
      final session = auth.session;

      if (session != null) {
        final result = await UserRepository.getProfile(
          displayName: session.displayName,
          email: session.email,
          role: session.role.label,
        );
        setState(() {
          _userProfile = result.data ??
              UserProfile(
                id: '',
                email: session.email,
                displayName: session.displayName,
                role: session.role.label,
              );
          _isLoading = false;
        });
      } else {
        setState(() {
          _userProfile = UserProfile(
            id: '',
            email: '',
            displayName: 'User',
            role: 'User',
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() => _isLoading = false);
    }
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card profil utama
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primaryGreen,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userProfile?.displayName ?? 'User',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userProfile?.email ?? '',
                    style: TextStyle(color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _userProfile?.role ?? 'User',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Section: Informasi Pribadi
          Text(
            'Informasi Pribadi',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _userProfile?.email ?? '',
          ),
          _InfoTile(
            icon: Icons.key_outlined,
            label: 'Kode Unik Kos',
            value: _userProfile?.kosAccessCode ?? 'Belum tersedia',
          ),
          _InfoTile(
            icon: Icons.bed_outlined,
            label: 'Kamar',
            value: (() {
              final rooms = [
                if ((_userProfile?.roomNumber ?? '').isNotEmpty)
                  'No ${_userProfile!.roomNumber}',
                if ((_userProfile?.roomType ?? '').isNotEmpty)
                  _userProfile!.roomType!,
              ];
              final label = rooms.join(' - ');
              return label.isEmpty ? 'Belum diisi' : label;
            })(),
          ),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Nomor Telepon',
            value: _userProfile?.phone ?? 'Belum diisi',
          ),
          _InfoTile(
            icon: Icons.location_on_outlined,
            label: 'Alamat',
            value: _userProfile?.address ?? 'Belum diisi',
          ),
          const SizedBox(height: 24),
          // Section: Aksi
          Text(
            'Pengaturan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.edit,
            label: 'Edit Profil',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Edit profil akan segera tersedia')),
              );
            },
          ),
          _ActionTile(
            icon: Icons.lock_outline,
            label: 'Ubah Kata Sandi',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Ubah kata sandi akan segera tersedia')),
              );
            },
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
