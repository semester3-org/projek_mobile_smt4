import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../auth/roles.dart';
import '../owner/owner_shell.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final session = auth.session;

    if (session == null) {
      return const LoginPage();
    }

    // Saat ini hanya fokus pada halaman Owner.
    if (session.role == UserRole.owner) {
      return const OwnerShell();
    }

    return RolePendingPage(role: session.role);
  }
}

class RolePendingPage extends StatelessWidget {
  const RolePendingPage({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fitur Belum Tersedia')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.construction_rounded, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              'Halaman untuk role ${role.label} belum tersedia.',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Saat ini hanya halaman untuk role Owner yang sudah dibuat. Silakan login kembali dengan role Owner atau tunggu fitur role lain selesai.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: () {
                AuthScope.of(context).logout();
              },
              child: const Text('Kembali ke login'),
            ),
          ],
        ),
      ),
    );
  }
}

