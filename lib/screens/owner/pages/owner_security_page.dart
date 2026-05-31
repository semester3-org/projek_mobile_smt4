import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../auth/auth_scope.dart';
import '../../../data/repositories/user_repository.dart';

class OwnerSecurityPage extends StatefulWidget {
  const OwnerSecurityPage({super.key});

  @override
  State<OwnerSecurityPage> createState() => _OwnerSecurityPageState();
}

class _OwnerSecurityPageState extends State<OwnerSecurityPage> {
  bool _isTwoFactor = true;

  Future<void> _changePassword(
      BuildContext context, String currentPass, String newPass) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Tampilkan loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await UserRepository.changePassword(
      currentPassword: currentPass,
      newPassword: newPass,
    );

    if (!mounted) return;
    navigator.pop(); // Close loading indicator

    if (!res.isSuccess) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Gagal mengubah kata sandi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Kata sandi berhasil diubah!'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Kata Sandi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kata Sandi Saat Ini',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kata Sandi Baru',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi Kata Sandi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final current = currentPassController.text.trim();
              final newPass = newPassController.text.trim();
              final confirm = confirmPassController.text.trim();

              if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Semua field wajib diisi!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (newPass != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kata sandi baru tidak cocok!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (newPass.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kata sandi minimal 4 karakter!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context); // Close dialog
              _changePassword(context, current, newPass);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final email = auth.session?.email ?? 'update@email.com';

    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(title: const Text('Keamanan Akun')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Kelola Keamanan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Perbarui kata sandi, verifikasi dua langkah, dan kontrol akses akun Owner Anda.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline_rounded,
                  color: AppTheme.primaryGreen),
              title: const Text('Ubah Kata Sandi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showChangePasswordDialog(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phonelink_lock_rounded,
                  color: AppTheme.primaryGreen),
              title: const Text('Verifikasi Dua Langkah'),
              subtitle: const Text('Aktifkan OTP untuk login lebih aman'),
              trailing: Switch(
                value: _isTwoFactor,
                activeThumbColor: AppTheme.primaryGreen,
                onChanged: (val) {
                  setState(() {
                    _isTwoFactor = val;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(val ? '2FA diaktifkan.' : '2FA dinonaktifkan.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined,
                  color: AppTheme.primaryGreen),
              title: const Text('Email Akun Utama'),
              subtitle: Text(email),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Email utama terhubung dengan profil session Anda.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
