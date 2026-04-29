import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/user_dashboard.dart';
import '../profile/billing_list_page.dart';
import 'user_theme.dart';
import 'user_widgets.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({
    super.key,
    required this.onSelectTab,
  });

  final ValueChanged<int> onSelectTab;

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  UserDashboard? _dashboard;
  bool _loading = true;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  Future<void> _load() async {
    final session = AuthScope.of(context).session;
    final displayName = session?.displayName ?? 'User';
    setState(() {
      _dashboard ??= UserDashboard.fallback(displayName);
      _loading = false;
    });
    final result = await UserRepository.getDashboard(displayName: displayName);
    if (!mounted) return;

    setState(() {
      _dashboard = result.data ?? UserDashboard.fallback(displayName);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthScope.of(context).session;
    final displayName = _firstName(session?.displayName ?? 'User');

    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.home_work_rounded, color: UserTheme.primary, size: 22),
            SizedBox(width: 10),
            Text(
              'Sentra Ruang',
              style: TextStyle(
                color: UserTheme.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => widget.onSelectTab(4),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => widget.onSelectTab(5),
              child: CircleAvatar(
                backgroundColor: UserTheme.softBlue,
                child: Text(
                  displayName.isEmpty ? 'U' : displayName[0].toUpperCase(),
                  style: const TextStyle(
                    color: UserTheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: UserTheme.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                children: [
                  Text(
                    'Selamat pagi,',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: UserTheme.muted,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Halo, $displayName',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: UserTheme.text,
                        ),
                  ),
                  const SizedBox(height: 22),
                  _BillingHero(dashboard: _dashboard!),
                  const SizedBox(height: 28),
                  const UserSectionHeader(title: 'Layanan Utama'),
                  const SizedBox(height: 14),
                  _ServiceGrid(onSelectTab: widget.onSelectTab),
                  const SizedBox(height: 22),
                  _AnnouncementCard(dashboard: _dashboard!),
                  const SizedBox(height: 28),
                  UserSectionHeader(
                    title: 'Rekomendasi Menu',
                    actionLabel: 'Lihat Semua',
                    onAction: () => widget.onSelectTab(2),
                  ),
                  const SizedBox(height: 12),
                  _RecommendationList(dashboard: _dashboard!),
                  const UserBottomSpacer(),
                ],
              ),
      ),
    );
  }

  String _firstName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'User';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class _BillingHero extends StatelessWidget {
  const _BillingHero({required this.dashboard});

  final UserDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1475C8), Color(0xFF00508F)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [UserTheme.softShadow(opacity: 0.16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TAGIHAN AKTIF',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.76),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white.withOpacity(0.68),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatUserCurrency(dashboard.activeBillAmount),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  dashboard.activeBillLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              Text(
                dashboard.dueDateText,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: dashboard.billProgress.clamp(0, 1).toDouble(),
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BillingListPage(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: UserTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Bayar Sekarang',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.05,
      children: [
        _ServiceTile(
          icon: Icons.apartment_rounded,
          iconColor: UserTheme.primary,
          iconBg: UserTheme.softBlue,
          title: 'Pembayaran Kos',
          subtitle: 'Sewa & Listrik',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BillingListPage()),
            );
          },
        ),
        _ServiceTile(
          icon: Icons.restaurant_rounded,
          iconColor: const Color(0xFFFF7A1A),
          iconBg: const Color(0xFFFFF1E5),
          title: 'Catering',
          subtitle: 'Menu Harian',
          onTap: () => onSelectTab(2),
        ),
        _ServiceTile(
          icon: Icons.local_laundry_service_rounded,
          iconColor: const Color(0xFF8A3FFC),
          iconBg: const Color(0xFFF1E7FF),
          title: 'Laundry',
          subtitle: 'Cuci & Setrika',
          onTap: () => onSelectTab(1),
        ),
        _ServiceTile(
          icon: Icons.local_cafe_rounded,
          iconColor: const Color(0xFF009B8F),
          iconBg: const Color(0xFFE7FAF6),
          title: 'Kafe',
          subtitle: 'Snack & Kopi',
          onTap: () => onSelectTab(3),
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [UserTheme.softShadow(opacity: 0.04)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: UserTheme.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: UserTheme.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.dashboard});

  final UserDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.campaign_rounded, color: UserTheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dashboard.announcementTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: UserTheme.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dashboard.announcementSubtitle,
                  style: const TextStyle(color: UserTheme.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: UserTheme.muted),
        ],
      ),
    );
  }
}

class _RecommendationList extends StatelessWidget {
  const _RecommendationList({required this.dashboard});

  final UserDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dashboard.recommendations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = dashboard.recommendations[index];
          return SizedBox(
            width: 238,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [UserTheme.softShadow(opacity: 0.05)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserImage(
                    url: item.imageUrl,
                    icon: Icons.restaurant_rounded,
                    height: 126,
                    width: double.infinity,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: UserTheme.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatUserCurrency(item.price),
                          style: const TextStyle(
                            color: UserTheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
