import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/repositories/owner_repository.dart';
import '../../widgets/exit_guard.dart';
import 'pages/owner_dashboard_page.dart';
import 'pages/owner_finance_page.dart';
import 'pages/owner_rooms_page.dart';
import 'pages/owner_notifications_page.dart';
import 'pages/owner_profile_page.dart';
import 'subpages/owner_tenants_page.dart';

class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _index = 0;

  void _navigateToTab(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return ExitGuard(
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            OwnerDashboardPage(onNavigateToFinance: _navigateToTab),
            OwnerRoomsPage(onOpenProfile: () => _navigateToTab(5)),
            const OwnerTenantsPage(),
            const OwnerFinancePage(),
            const OwnerNotificationsPage(),
            const OwnerProfilePage(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          selectedItemColor: AppTheme.primaryGreen,
          unselectedItemColor: Colors.grey.shade600,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.meeting_room_outlined),
              activeIcon: Icon(Icons.meeting_room_rounded),
              label: 'Kamar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.how_to_reg_outlined),
              activeIcon: Icon(Icons.how_to_reg_rounded),
              label: 'Approval',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Keuangan',
            ),
            BottomNavigationBarItem(
              icon: _OwnerNotificationNavIcon(selected: false),
              activeIcon: _OwnerNotificationNavIcon(selected: true),
              label: 'Notifikasi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerNotificationNavIcon extends StatefulWidget {
  const _OwnerNotificationNavIcon({required this.selected});

  final bool selected;

  @override
  State<_OwnerNotificationNavIcon> createState() =>
      _OwnerNotificationNavIconState();
}

class _OwnerNotificationNavIconState extends State<_OwnerNotificationNavIcon> {
  Timer? _timer;
  StreamSubscription<void>? _countSubscription;
  int _count = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCount();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _loadCount());
    _countSubscription =
        OwnerRepository.notificationCountChanges.listen((_) => _loadCount());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCount() async {
    if (_loading) return;
    _loading = true;
    try {
      final count = await OwnerRepository.unreadNotificationCount();
      if (mounted) {
        setState(() => _count = count);
      }
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(widget.selected
            ? Icons.notifications_rounded
            : Icons.notifications_none_rounded),
        if (_count > 0)
          Positioned(
            right: -7,
            top: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                _count > 99 ? '99+' : '$_count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
