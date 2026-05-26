import 'package:flutter/material.dart';

import '../../../../core/realtime_service.dart';
import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/catering_subscriber.dart';
import '../../merchant_ui.dart';

class CateringSubscribersPage extends StatefulWidget {
  const CateringSubscribersPage({super.key});

  @override
  State<CateringSubscribersPage> createState() =>
      _CateringSubscribersPageState();
}

class _CateringSubscribersPageState extends State<CateringSubscribersPage> {
  List<CateringSubscriber> _items = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;

  static const _filters = ['all', 'active', 'expired'];

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeService().addEventListener('merchant_order_updated', _load);
    RealtimeService().startMerchantOrdersPolling();
  }

  @override
  void dispose() {
    RealtimeService().removeEventListener('merchant_order_updated', _load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await MerchantRepository.getCateringSubscribers(
      status: _filters[_tab],
    );
    if (!mounted) return;
    setState(() {
      _items = result.data ?? [];
      _error = result.error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MerchantPage(
      topBar: const MerchantTopBar(
        title: 'Pelanggan Catering',
        showBack: true,
        showAvatar: false,
      ),
      children: [
        const Text(
          'Daftar user yang berlangganan paket catering Anda.',
          style: TextStyle(color: MerchantPalette.muted, height: 1.4),
        ),
        const SizedBox(height: 18),
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
                  selectedColor: MerchantPalette.softBlue,
                  checkmarkColor: MerchantPalette.primary,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          MerchantCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_error!, style: const TextStyle(color: MerchantPalette.danger)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Muat Ulang')),
              ],
            ),
          )
        else if (_items.isEmpty)
          const MerchantCard(
            child: Text(
              'Belum ada pelanggan pada filter ini.',
              style: TextStyle(color: MerchantPalette.muted),
            ),
          )
        else
          ..._items.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SubscriberTile(subscriber: s),
            ),
          ),
        const MerchantBottomSpacer(),
      ],
    );
  }
}

class _SubscriberTile extends StatelessWidget {
  const _SubscriberTile({required this.subscriber});

  final CateringSubscriber subscriber;

  @override
  Widget build(BuildContext context) {
    final active = subscriber.isActive && !subscriber.isExpired;
    return MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subscriber.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: MerchantPalette.text,
                  ),
                ),
              ),
              MerchantStatusPill(
                label: active ? 'AKTIF' : 'EXPIRED',
                color: active ? MerchantPalette.success : MerchantPalette.muted,
              ),
            ],
          ),
          if (subscriber.userPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subscriber.userPhone,
                style: const TextStyle(color: MerchantPalette.muted)),
          ],
          const SizedBox(height: 10),
          Text(
            subscriber.productName.isNotEmpty
                ? subscriber.productName
                : subscriber.packageLabel,
            style: const TextStyle(
              color: MerchantPalette.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${subscriber.startDate ?? '-'} s/d ${subscriber.endDate ?? '-'}',
            style: const TextStyle(color: MerchantPalette.muted, fontSize: 13),
          ),
          if (subscriber.subscriptionStatus == 'cancel_requested') ...[
            const SizedBox(height: 8),
            const Text(
              'User membatalkan — paket tetap jalan sampai akhir periode.',
              style: TextStyle(
                color: MerchantPalette.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
