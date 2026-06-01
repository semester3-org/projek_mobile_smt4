import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../auth/roles.dart';
import '../../data/repositories/merchant_repository.dart';
import 'pages/laundry/laundry_dashboard_page.dart';
import 'pages/laundry/laundry_orders_page.dart';
import 'pages/laundry/laundry_services_page.dart';
import 'pages/catering/catering_dashboard_page.dart';
import 'pages/catering/catering_orders_page.dart';
import 'pages/catering/catering_menu_page.dart';
import 'pages/shared/merchant_profile_page.dart';
import 'pages/shared/merchant_promo_page.dart';
import 'merchant_ui.dart';

class MerchantShell extends StatefulWidget {
  const MerchantShell({super.key});

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final merchantType = auth.session?.merchantType ?? MerchantType.laundry;

    final List<Widget> pages = merchantType == MerchantType.laundry
        ? [
            const LaundryDashboardPage(),
            const LaundryOrdersPage(),
            const LaundryServicesPage(),
            const MerchantPromoPage(),
            const MerchantProfilePage(),
          ]
        : [
            const CateringDashboardPage(),
            const CateringOrdersPage(),
            const CateringMenuPage(),
            const MerchantPromoPage(),
            const MerchantProfilePage(),
          ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: MerchantBottomNav(
        currentIndex: _index,
        onChanged: (i) {
          if (i == 1) {
            _MerchantOrderBadgeState.markOrdersOpened();
          }
          setState(() => _index = i);
        },
      ),
    );
  }
}

class MerchantBottomNav extends StatelessWidget {
  const MerchantBottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Dashboard'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Pesanan'),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Produk'),
    (Icons.local_offer_outlined, Icons.local_offer_rounded, 'Promo'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 78,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border.all(color: const Color(0xFFECEFF5)),
          boxShadow: [MerchantPalette.shadow(opacity: 0.08)],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _MerchantBottomNavItem(
                  icon: _items[i].$1,
                  activeIcon: _items[i].$2,
                  label: _items[i].$3,
                  selected: i == currentIndex,
                  showBadge: i == 1,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MerchantBottomNavItem extends StatelessWidget {
  const _MerchantBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    this.showBadge = false,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MerchantPalette.primary : const Color(0xFF4D5662);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 56,
        decoration: BoxDecoration(
          color: selected ? MerchantPalette.softBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? activeIcon : icon, size: 22, color: color),
                if (showBadge) const _MerchantOrderBadge(),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantOrderBadge extends StatefulWidget {
  const _MerchantOrderBadge();

  @override
  State<_MerchantOrderBadge> createState() => _MerchantOrderBadgeState();
}

class _MerchantOrderBadgeState extends State<_MerchantOrderBadge> {
  static final _clearController = StreamController<void>.broadcast();
  static DateTime? _lastOpenedAt;

  static void markOrdersOpened() {
    _lastOpenedAt = DateTime.now();
    _clearController.add(null);
  }

  Timer? _timer;
  StreamSubscription<void>? _clearSubscription;
  int _count = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _clearSubscription = _clearController.stream.listen((_) {
      if (mounted && _count != 0) {
        setState(() => _count = 0);
      }
    });
    _load();
    _timer = Timer.periodic(const Duration(seconds: 18), (_) => _load());
  }

  @override
  void dispose() {
    _clearSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final result = await MerchantRepository.getOrders(status: 'pending');
      if (!mounted) return;
      final openedAt = _lastOpenedAt;
      final orders = result.data ?? const [];
      final next = openedAt == null
          ? orders.length
          : orders.where((order) => order.createdAt.isAfter(openedAt)).length;
      if (next != _count) {
        setState(() => _count = next);
      }
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_count <= 0) return const SizedBox.shrink();
    return Positioned(
      right: -10,
      top: -9,
      child: Container(
        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MerchantPalette.danger,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 1.4),
        ),
        child: Text(
          _count > 99 ? '99+' : _count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}
