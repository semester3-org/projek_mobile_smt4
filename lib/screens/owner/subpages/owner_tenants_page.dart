import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class OwnerTenantsPage extends StatelessWidget {
  const OwnerTenantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(title: const Text('Penghuni')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _TenantTile(
            name: 'Andi Saputra',
            room: 'A-12',
            status: 'Aktif',
          ),
          _TenantTile(
            name: 'Siti Aminah',
            room: 'B-05',
            status: 'Aktif',
          ),
          _TenantTile(
            name: 'Rizky Pratama',
            room: 'C-01',
            status: 'Menunggu Check-in',
          ),
        ],
      ),
    );
  }
}

class _TenantTile extends StatelessWidget {
  const _TenantTile({
    required this.name,
    required this.room,
    required this.status,
  });

  final String name;
  final String room;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.surfaceTint,
          child: Icon(Icons.person, color: AppTheme.primaryGreen),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('Kamar $room • $status'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}

