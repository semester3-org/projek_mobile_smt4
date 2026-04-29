import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../auth/auth_scope.dart';
import '../../auth/roles.dart';
import '../../models/user_profile.dart';

/// Halaman detail profil user - menampilkan info lengkap user yang login
class UserProfileDetailPage extends StatefulWidget {
  const UserProfileDetailPage({super.key});

  @override
  State<UserProfileDetailPage> createState() => _UserProfileDetailPageState();
}

class _UserProfileDetailPageState extends State<UserProfileDetailPage> {
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Ambil session dari auth
      final auth = AuthScope.of(context);
      final session = auth.session;

      if (session != null) {
        // TODO: Untuk integrasi lebih lanjut, bisa fetch data lebih lengkap dari backend
        // Saat ini menggunakan data dari session yang sudah login
        setState(() {
          _userProfile = UserProfile(
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil Saya')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        elevation: 0,
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
                const SnackBar(content: Text('Edit profil akan segera tersedia')),
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
          _ActionTile(
            icon: Icons.logout,
            label: 'Keluar',
            trailing: Icons.chevron_right,
            onTap: () {
              _showLogoutDialog(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
            'Apakah Anda yakin ingin keluar? Anda harus login kembali untuk mengakses akun.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              final auth = AuthScope.of(context);
              auth.logout();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text(
              'Keluar',
              style: TextStyle(color: Colors.red),
            ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryGreen),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge,
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
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryGreen),
        title: Text(label),
        trailing: Icon(trailing ?? Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
