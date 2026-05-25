import 'package:flutter/material.dart';

import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/merchant_models.dart';
import '../../merchant_ui.dart';
import 'merchant_notifications_page.dart';

class MerchantDashboardView extends StatefulWidget {
  const MerchantDashboardView({
    super.key,
    required this.isLaundry,
    required this.onViewAllOrders,
  });

  final bool isLaundry;
  final VoidCallback onViewAllOrders;

  @override
  State<MerchantDashboardView> createState() => _MerchantDashboardViewState();
}

class _MerchantDashboardViewState extends State<MerchantDashboardView> {
  MerchantDashboard? _dashboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await MerchantRepository.getDashboard();
    if (!mounted) return;
    setState(() {
      _dashboard = result.data;
      _error = result.error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.isLaundry
        ? Icons.local_laundry_service_outlined
        : Icons.restaurant_menu_rounded;
    final dashboard = _dashboard;

    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'MerchantHub',
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MerchantNotificationsPage()),
        ),
      ),
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 120),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _ErrorState(message: _error!, onRetry: _load)
        else if (dashboard != null) ...[
          Text(
            'Halo, ${dashboard.merchantName}!',
            style: const TextStyle(
              color: MerchantPalette.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Berikut performa bisnismu hari ini.',
            style: TextStyle(color: MerchantPalette.muted, fontSize: 15),
          ),
          const SizedBox(height: 28),
          MerchantMetricCard(
            title: 'TOTAL PESANAN',
            value: dashboard.totalOrders.toString(),
            trailing: MerchantStatusPill(
              label: 'REAL DB',
              color: MerchantPalette.success,
              background: MerchantPalette.success.withValues(alpha: 0.13),
            ),
          ),
          const SizedBox(height: 12),
          MerchantCard(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
            child: Row(
              children: [
                Icon(icon, color: MerchantPalette.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pesanan sedang diproses: ${dashboard.processingOrders} pesanan',
                    style: const TextStyle(
                      color: MerchantPalette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: MerchantMetricCard(
                  title: widget.isLaundry ? 'LAYANAN AKTIF' : 'PAKET AKTIF',
                  value: dashboard.activeProducts.toString(),
                  subtitle: 'Ditambahkan merchant',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MerchantMetricCard(
                  title: 'PROMO BERJALAN',
                  value: dashboard.activePromos.toString(),
                  subtitle: 'LIVE',
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          MerchantSectionHeader(
            title: 'Pesanan Terbaru',
            actionLabel: dashboard.recentOrders.isEmpty ? null : 'Lihat Semua',
            onAction: widget.onViewAllOrders,
          ),
          const SizedBox(height: 10),
          if (dashboard.recentOrders.isEmpty)
            const MerchantCard(
              child: Text(
                'Belum ada pesanan masuk.',
                style: TextStyle(color: MerchantPalette.muted),
              ),
            )
          else ...[
            _HighlightOrderCard(order: dashboard.recentOrders.first),
            const SizedBox(height: 14),
            ...dashboard.recentOrders.skip(1).take(3).map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _RecentOrderCard(order: order),
                  ),
                ),
          ],
          const MerchantBottomSpacer(),
        ],
      ],
    );
  }
}

class _HighlightOrderCard extends StatelessWidget {
  const _HighlightOrderCard({required this.order});

  final MerchantOrder order;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      padding: const EdgeInsets.all(18),
      color: MerchantPalette.softBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fiber_new_rounded,
                  color: MerchantPalette.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Highlight pesanan masuk terbaru',
                  style: TextStyle(
                    color: MerchantPalette.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              MerchantStatusPill(
                label: order.statusLabel,
                color: _statusColor(order.statusGroup),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            order.code,
            style: const TextStyle(
              color: MerchantPalette.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatDateTime(order.createdAt)} - ${order.serviceName}',
            style: const TextStyle(color: MerchantPalette.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard({required this.order});

  final MerchantOrder order;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: MerchantPalette.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.code,
                  style: const TextStyle(
                    color: MerchantPalette.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  order.serviceName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPalette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(order.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: MerchantPalette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MerchantStatusPill(
            label: order.statusLabel,
            color: _statusColor(order.statusGroup),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: MerchantPalette.danger)),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Muat Ulang')),
        ],
      ),
    );
  }
}

Color _statusColor(String group) {
  switch (group) {
    case 'pending':
      return MerchantPalette.danger;
    case 'done':
      return MerchantPalette.success;
    default:
      return const Color(0xFF1D4ED8);
  }
}

String _formatDateTime(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}
