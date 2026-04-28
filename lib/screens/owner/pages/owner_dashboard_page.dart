import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../auth/auth_scope.dart';
import 'owner_finance_page.dart';
import 'owner_notifications_page.dart';
import '../subpages/owner_rating_page.dart';
import '../subpages/owner_tenants_page.dart';

class OwnerDashboardPage extends StatelessWidget {
  const OwnerDashboardPage({super.key, this.onNavigateToFinance});

  final void Function(int)? onNavigateToFinance;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final name = auth.session?.displayName ?? 'Juragan';

    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(
        title: const Text('KosOwner'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Selamat pagi, $name!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pantau performa properti Anda hari ini.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          const _StatRow(
            left: _StatCard(
              title: 'Total Kamar',
              value: '42',
              subtitle: 'Unit Properti',
              icon: Icons.meeting_room_rounded,
            ),
            right: _MiniStatsCard(),
          ),
          const SizedBox(height: 14),
          _RevenueCard(onNavigateToFinance: onNavigateToFinance),
          const SizedBox(height: 16),
          Text(
            'Menu Cepat',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          _QuickMenu(
            onTenants: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OwnerTenantsPage(),
                ),
              );
            },
            onRating: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OwnerRatingPage(),
                ),
              );
            },
            onFinance: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OwnerFinancePage(),
                ),
              );
            },
            onNotifications: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OwnerNotificationsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aktivitas Terkini',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OwnerNotificationsPage(),
                    ),
                  );
                },
                child: const Text('Lihat Semua'),
              ),
            ],
          ),
          const _ActivityTile(
            color: Color(0xFF2E7D32),
            title: 'Pembayaran Berhasil',
            subtitle: 'Kamar A-12 • Rp 1.500.000',
            time: '1 jam lalu',
          ),
          const _ActivityTile(
            color: Color(0xFF1565C0),
            title: 'Komplain Perbaikan',
            subtitle: 'Kamar D-04 • Keran bocor',
            time: '4 jam lalu',
          ),
          const _ActivityTile(
            color: Color(0xFFEF6C00),
            title: 'Penghuni Baru',
            subtitle: 'Kamar C-01 • Verifikasi selesai',
            time: '1 hari lalu',
          ),
          const SizedBox(height: 18),
          Text(
            'Jatuh Tempo Mendatang',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          const _DueSoonCard(),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primaryGreen),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

class _MiniStatsCard extends StatelessWidget {
  const _MiniStatsCard();

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String value, Color bg, Color fg) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: fg.withOpacity(0.9))),
            Text(
              value,
              style: TextStyle(color: fg, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            chip('Terisi', '38', const Color(0xFFE8F5E9), AppTheme.primaryGreen),
            const SizedBox(height: 10),
            chip('Kosong', '3', const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
            const SizedBox(height: 10),
            chip('Maintenance', '1', const Color(0xFFFFF3E0),
                const Color(0xFFEF6C00)),
          ],
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({this.onNavigateToFinance});

  final void Function(int)? onNavigateToFinance;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E5AEF), Color(0xFF2B8BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E5AEF).withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pendapatan Bulan Ini',
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Rp 54.2M',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+12.5% dari bulan lalu',
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.18),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                onNavigateToFinance?.call(2);
              },
              child: const Text('Detail'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickMenu extends StatelessWidget {
  const _QuickMenu({
    required this.onTenants,
    required this.onRating,
    required this.onFinance,
    required this.onNotifications,
  });

  final VoidCallback onTenants;
  final VoidCallback onRating;
  final VoidCallback onFinance;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    // Sesuai permintaan: hilangkan menu "Laporan".
    final items = <_QuickMenuItem>[
      _QuickMenuItem(
        icon: Icons.apartment_rounded,
        label: 'Kelola Kos',
        onTap: () {},
      ),
      _QuickMenuItem(
        icon: Icons.people_alt_rounded,
        label: 'Penghuni',
        onTap: onTenants,
      ),
      _QuickMenuItem(
        icon: Icons.account_balance_rounded,
        label: 'Keuangan',
        onTap: onFinance,
      ),
      _QuickMenuItem(
        icon: Icons.star_rounded,
        label: 'Rating',
        onTap: onRating,
      ),
      _QuickMenuItem(
        icon: Icons.notifications_rounded,
        label: 'Notifikasi',
        onTap: onNotifications,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 10 * 2) / 3;
            return Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: items
                  .map(
                    (e) => SizedBox(
                      width: itemWidth,
                      child: _QuickMenuTile(item: e),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _QuickMenuItem {
  const _QuickMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickMenuTile extends StatelessWidget {
  const _QuickMenuTile({required this.item});

  final _QuickMenuItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.surfaceTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final Color color;
  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 10,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: Text(time, style: TextStyle(color: Colors.grey.shade600)),
      ),
    );
  }
}

class _DueSoonCard extends StatelessWidget {
  const _DueSoonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F2A),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          const _DueSoonRow(
            name: 'Dian Sastro',
            room: 'A-12',
            inDays: '2 hari lagi',
          ),
          const SizedBox(height: 10),
          const _DueSoonRow(
            name: 'Randy Panglila',
            room: 'A-01',
            inDays: '4 hari lagi',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.12),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pengingat jatuh tempo telah dikirim ke 2 penghuni'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Ingatkan Semua'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DueSoonRow extends StatelessWidget {
  const _DueSoonRow({
    required this.name,
    required this.room,
    required this.inDays,
  });

  final String name;
  final String room;
  final String inDays;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.event, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Kamar $room',
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            inDays,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

