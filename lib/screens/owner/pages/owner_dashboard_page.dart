import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../auth/auth_scope.dart';
import '../../../core/api_service.dart';
import 'owner_finance_page.dart';
import 'owner_notifications_page.dart';
import 'owner_security_page.dart';
import 'owner_help_page.dart';
import '../subpages/owner_tenants_page.dart';

class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key, this.onNavigateToFinance});

  final void Function(int)? onNavigateToFinance;

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  bool _isLoading = true;
  String? _error;
  
  Map<String, dynamic> _stats = {
    'total': 0,
    'occupied': 0,
    'available': 0,
    'maintenance': 0,
  };
  Map<String, dynamic> _revenue = {
    'monthly': 0,
    'growth': '0% dari bulan lalu',
  };
  List<dynamic> _activities = [];
  List<dynamic> _dueSoon = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await ApiService.get('api/owner_dashboard');
    if (!mounted) return;

    if (!res.success) {
      setState(() {
        _isLoading = false;
        _error = res.message ?? 'Gagal memuat data dashboard';
      });
      return;
    }

    try {
      final data = res.data!['data'] as Map<String, dynamic>;
      setState(() {
        _stats = data['statistics'] as Map<String, dynamic>;
        _revenue = data['revenue'] as Map<String, dynamic>;
        _activities = data['activities'] as List<dynamic>;
        _dueSoon = data['dueSoon'] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Format data dashboard tidak valid';
      });
    }
  }

  String _formatPrice(int price) {
    return 'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return 'Selamat pagi';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat siang';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat sore';
    } else {
      return 'Selamat malam';
    }
  }

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
            tooltip: 'Refresh',
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
               ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadDashboardData,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  color: AppTheme.primaryGreen,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Text(
                        '${_getGreeting()}, $name!',
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
                      _StatRow(
                        left: _StatCard(
                          title: 'Total Kamar',
                          value: _stats['total'].toString(),
                          subtitle: 'Unit Properti',
                          icon: Icons.meeting_room_rounded,
                          occupied: _stats['occupied'] as int,
                          total: _stats['total'] as int,
                        ),
                        right: _MiniStatsCard(
                          occupied: _stats['occupied'].toString(),
                          available: _stats['available'].toString(),
                          maintenance: _stats['maintenance'].toString(),
                          onNavigate: widget.onNavigateToFinance,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _RevenueCard(
                        monthlyRevenue: _formatPrice(_revenue['monthly'] as int),
                        growthText: _revenue['growth'] as String,
                        onNavigateToFinance: widget.onNavigateToFinance,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Menu Cepat',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      _QuickMenu(
                        onSecurity: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const OwnerSecurityPage(),
                            ),
                          );
                        },
                        onHelp: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const OwnerHelpPage(),
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
                            onPressed: () => widget.onNavigateToFinance?.call(4),
                            child: const Text('Lihat Semua'),
                          ),
                        ],
                      ),
                      if (_activities.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'Belum ada aktivitas hari ini.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          ),
                        )
                      else
                        ..._activities.map((act) {
                          final colorVal = int.parse(act['color'] as String);
                          return _ActivityTile(
                            color: Color(colorVal),
                            title: act['title'] as String,
                            subtitle: act['subtitle'] as String,
                            time: act['time'] as String,
                          );
                        }),
                      const SizedBox(height: 18),
                      Text(
                        'Jatuh Tempo Mendatang',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      _DueSoonCard(dueSoonList: _dueSoon),
                    ],
                  ),
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
    required this.occupied,
    required this.total,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final int occupied;
  final int total;

  @override
  Widget build(BuildContext context) {
    final double rate = total > 0 ? (occupied / total) : 0.0;
    final int percent = (rate * 100).round();

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
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$percent%',
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: rate,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primaryGreen,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatsCard extends StatelessWidget {
  const _MiniStatsCard({
    required this.occupied,
    required this.available,
    required this.maintenance,
    this.onNavigate,
  });

  final String occupied;
  final String available;
  final String maintenance;
  final void Function(int)? onNavigate;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String value, Color bg, Color fg, int tabIndex) {
      return InkWell(
        onTap: () => onNavigate?.call(tabIndex),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: fg.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
              Text(
                value,
                style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            chip('Terisi', occupied, const Color(0xFFEAF3FF), AppTheme.primaryGreen, 1),
            const SizedBox(height: 10),
            chip('Kosong', available, const Color(0xFFE3F2FD), const Color(0xFF1565C0), 1),
            const SizedBox(height: 10),
            chip('Maint.', maintenance, const Color(0xFFFFF3E0), const Color(0xFFEF6C00), 1),
          ],
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.monthlyRevenue,
    required this.growthText,
    this.onNavigateToFinance,
  });

  final String monthlyRevenue;
  final String growthText;
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
                  Text(
                    monthlyRevenue,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    growthText,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
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
                onNavigateToFinance?.call(3);
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
    required this.onSecurity,
    required this.onHelp,
  });

  final VoidCallback onSecurity;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final items = <_QuickMenuItem>[
      _QuickMenuItem(
        icon: Icons.security_rounded,
        label: 'Keamanan Akun',
        onTap: onSecurity,
      ),
      _QuickMenuItem(
        icon: Icons.help_outline_rounded,
        label: 'Pusat Bantuan',
        onTap: onHelp,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 10) / 2;
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: Text(time, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ),
    );
  }
}

class _DueSoonCard extends StatelessWidget {
  const _DueSoonCard({required this.dueSoonList});

  final List<dynamic> dueSoonList;

  @override
  Widget build(BuildContext context) {
    if (dueSoonList.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Tidak ada tagihan jatuh tempo dalam waktu dekat.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F2A),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          ...dueSoonList.map((due) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DueSoonRow(
                  name: due['name'] as String,
                  room: due['room'] as String,
                  inDays: due['inDays'] as String,
                ),
              )),
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
                  SnackBar(
                    content: Text('Pengingat jatuh tempo telah dikirim ke ${dueSoonList.length} penghuni'),
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
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
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
