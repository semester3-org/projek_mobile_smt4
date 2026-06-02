import 'package:flutter/material.dart';

import '../../core/realtime_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/catering_subscriber.dart';
import '../../widgets/catering_subscription_card.dart';
import 'user_theme.dart';

class UserCateringSubscriptionsPage extends StatefulWidget {
  const UserCateringSubscriptionsPage({super.key});

  @override
  State<UserCateringSubscriptionsPage> createState() =>
      _UserCateringSubscriptionsPageState();
}

class _UserCateringSubscriptionsPageState
    extends State<UserCateringSubscriptionsPage> {
  List<CateringSubscriber> _items = [];
  bool _loading = true;
  int _tab = 0;

  static const _filters = ['all', 'active', 'expired'];

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeService().startUserOrderPolling();
    RealtimeService().addEventListener('order_status_updated', _silentLoad);
  }

  @override
  void dispose() {
    RealtimeService().removeEventListener('order_status_updated', _silentLoad);
    RealtimeService().stopUserOrderPolling();
    super.dispose();
  }

  String _itemsSignature(List<CateringSubscriber> items) {
    return items
        .map(
          (item) => [
            item.id,
            item.orderId,
            item.subscriptionStatus,
            item.startDate ?? '',
            item.endDate ?? '',
            item.cancellationRequestedAt ?? '',
          ].join('|'),
        )
        .join('::');
  }

  Future<void> _silentLoad() => _load(showLoading: false);

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _loading = true);
    }
    final result = await UserRepository.getCateringSubscriptions(
      status: _filters[_tab],
    );
    if (!mounted) return;
    var nextItems = result.data ?? [];
    // Hide expired cards on Semua/Aktif so only current subscriptions remain.
    if (_tab != 2) {
      nextItems = nextItems.where((item) => !item.isExpired).toList();
    } else {
      nextItems = nextItems.where((item) => item.isExpired).toList();
    }

    // Deduplicate by orderId: keep the subscription with the latest endDate
    final Map<String, CateringSubscriber> byOrder = {};
    DateTime? tryParse(String? raw) {
      if (raw == null) return null;
      try {
        return DateTime.tryParse(raw);
      } catch (_) {
        return null;
      }
    }
    for (final s in nextItems) {
      final key = (s.orderId.isNotEmpty) ? s.orderId : s.id;
      final existing = byOrder[key];
      if (existing == null) {
        byOrder[key] = s;
        continue;
      }
      final curEnd = tryParse(s.endDate);
      final exEnd = tryParse(existing.endDate);
      if (curEnd != null && exEnd != null) {
        if (curEnd.isAfter(exEnd)) byOrder[key] = s;
      } else if (curEnd != null && exEnd == null) {
        byOrder[key] = s;
      } else if (curEnd == null && exEnd == null) {
        // keep existing (fallback)
      }
    }
    nextItems = byOrder.values.toList();
    final hasChanged = _itemsSignature(nextItems) != _itemsSignature(_items);
    setState(() {
      if (hasChanged || showLoading) {
        _items = nextItems;
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Langganan Catering',
          style: TextStyle(
            color: UserTheme.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: UserTheme.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            const Text(
              'Paket catering aktif dan riwayat langganan Anda.',
              style: TextStyle(color: UserTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(3, (i) {
                final labels = ['Semua', 'Aktif', 'Expired'];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    child: FilterChip(
                      label: Text(labels[i]),
                      selected: _tab == i,
                      onSelected: (_) {
                        setState(() => _tab = i);
                        _load();
                      },
                      selectedColor: UserTheme.softBlue,
                      checkmarkColor: UserTheme.primary,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    'Belum ada langganan catering.',
                    style: TextStyle(color: UserTheme.muted),
                  ),
                ),
              )
            else
              ..._items.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: CateringSubscriptionCard(subscription: s),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
