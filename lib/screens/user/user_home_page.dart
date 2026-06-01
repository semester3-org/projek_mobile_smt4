import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../core/realtime_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/catering_subscriber.dart';
import '../../models/user_dashboard.dart';
import '../profile/billing_list_page.dart';
import '../profile/notification_list_page.dart';
import 'order_detail_page.dart';
import 'user_catering_subscriptions_page.dart';
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
  bool _loadingDashboard = false;
  StreamSubscription<void>? _dashboardRefreshSub;
  void _orderStatusHandler() => _load(silent: true, forceRefresh: true);

  @override
  void initState() {
    super.initState();
    _dashboardRefreshSub = UserRepository.profileRefreshRequests.listen((_) {
      if (mounted) _load(forceRefresh: true);
    });
    RealtimeService().startUserOrderPolling();
    RealtimeService().addEventListener(
      'order_status_updated',
      _orderStatusHandler,
    );
  }

  @override
  void dispose() {
    _dashboardRefreshSub?.cancel();
    RealtimeService()
        .removeEventListener('order_status_updated', _orderStatusHandler);
    RealtimeService().stopUserOrderPolling();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  Future<void> _load({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    if (_loadingDashboard) return;
    _loadingDashboard = true;
    final session = AuthScope.of(context).session;
    final displayName = session?.displayName ?? 'User';
    try {
      if (!silent) {
        setState(() {
          _dashboard ??= UserDashboard.fallback(displayName);
          _loading = _dashboard == null;
        });
      }
      final result = await UserRepository.getDashboard(
        displayName: displayName,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;

      setState(() {
        _dashboard = result.data ?? UserDashboard.fallback(displayName);
        _loading = false;
      });
    } finally {
      _loadingDashboard = false;
    }
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
          UserNotificationIconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationListPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(forceRefresh: true),
        color: UserTheme.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                children: [
                  Text(
                    '${_getGreeting()},',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: UserTheme.muted,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Halo, $displayName',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: UserTheme.text,
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => widget.onSelectTab(3),
                        child: CircleAvatar(
                          backgroundColor: UserTheme.softBlue,
                          child: Text(
                            displayName.isEmpty
                                ? 'U'
                                : displayName[0].toUpperCase(),
                            style: const TextStyle(
                              color: UserTheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _BillingHero(dashboard: _dashboard!),
                  const SizedBox(height: 14),
                  const _HomeCateringSubscriptions(),
                  const SizedBox(height: 28),
                  const UserSectionHeader(title: 'Layanan Utama'),
                  const SizedBox(height: 14),
                  _ServiceGrid(onSelectTab: widget.onSelectTab),
                  const SizedBox(height: 22),
                  if (_dashboard!.announcementTitle.trim().isNotEmpty) ...[
                    _AnnouncementCard(dashboard: _dashboard!),
                    const SizedBox(height: 28),
                  ],
                  const UserBottomSpacer(),
                ],
              ),
      ),
    );
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
                    color: Colors.white.withValues(alpha: 0.76),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white.withValues(alpha: 0.68),
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
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context)
                    .push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => const BillingListPage(),
                  ),
                )
                    .then((changed) {
                  if (changed == true) {
                    UserRepository.requestProfileRefresh();
                  }
                });
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
            Navigator.of(context)
                .push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => const BillingListPage(),
              ),
            )
                .then((changed) {
              if (changed == true) {
                UserRepository.requestProfileRefresh();
              }
            });
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

class _HomeCateringSubscriptions extends StatefulWidget {
  const _HomeCateringSubscriptions();

  @override
  State<_HomeCateringSubscriptions> createState() =>
      _HomeCateringSubscriptionsState();
}

class _HomeCateringSubscriptionsState
    extends State<_HomeCateringSubscriptions> {
  List<CateringSubscriber> _active = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final result = await UserRepository.getCateringSubscriptions(status: 'all');
    if (!mounted) return;
    final items = (result.data ?? [])
        .where((s) =>
            s.isActive ||
            s.subscriptionStatus == 'pending' ||
            s.subscriptionStatus == 'pending_payment')
        .toList();
    setState(() => _active = items.take(2).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_active.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._active.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CateringActiveHero(subscription: s),
          ),
        ),
      ],
    );
  }
}

class _CateringActiveHero extends StatelessWidget {
  const _CateringActiveHero({required this.subscription});

  final CateringSubscriber subscription;

  @override
  Widget build(BuildContext context) {
    final title = subscription.productName.isNotEmpty
        ? subscription.productName
        : subscription.packageLabel;
    final hasPeriod = (subscription.startDate ?? '').trim().isNotEmpty &&
        (subscription.endDate ?? '').trim().isNotEmpty;
    final status = subscription.subscriptionStatus.toLowerCase();
    final statusLabel = switch (status) {
      'active' => 'AKTIF',
      'pending' => 'MENUNGGU PERSETUJUAN',
      'pending_payment' => 'MENUNGGU BAYAR',
      'cancel_requested' => 'AKTIF - BATAL BULAN DEPAN',
      _ => status.toUpperCase(),
    };
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: subscription.orderId.isEmpty
            ? null
            : () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final result =
                    await UserRepository.getOrderDetail(subscription.orderId);
                if (!context.mounted) return;
                if (!result.isSuccess || result.data == null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        result.error ?? 'Gagal memuat detail langganan',
                      ),
                    ),
                  );
                  return;
                }
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => UserOrderDetailPage(order: result.data!),
                  ),
                );
              },
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFD8B8)),
            boxShadow: [UserTheme.softShadow(opacity: 0.05)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PAKET CATERING AKTIF',
                      style: TextStyle(
                        color: Color(0xFFB85F00),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const UserCateringSubscriptionsPage(),
                        ),
                      );
                    },
                    child: const Text('Lihat Semua'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: UserTheme.text,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subscription.merchantName,
                style: const TextStyle(color: UserTheme.muted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _CateringHeroPill(
                    icon: Icons.restaurant_rounded,
                    text: subscription.packageLabel,
                  ),
                  const SizedBox(width: 8),
                  _CateringHeroPill(
                    icon: Icons.verified_rounded,
                    text: statusLabel,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (hasPeriod)
                Row(
                  children: [
                    const Icon(
                      Icons.date_range_outlined,
                      size: 17,
                      color: Color(0xFFB85F00),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_fmt(subscription.startDate)} - ${_fmt(subscription.endDate)}',
                        style: const TextStyle(
                          color: UserTheme.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      formatUserCurrency(subscription.totalAmount),
                      style: const TextStyle(
                        color: Color(0xFFB85F00),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatUserCurrency(subscription.totalAmount),
                    style: const TextStyle(
                      color: Color(0xFFB85F00),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return formatShortDate(date);
  }
}

class _CateringHeroPill extends StatelessWidget {
  const _CateringHeroPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFFFE3C7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFFB85F00)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8A4A00),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
