import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/user_merchant.dart';
import 'merchant_detail_page.dart';
import 'user_theme.dart';
import 'user_widgets.dart';

class UserRecommendationsPage extends StatefulWidget {
  const UserRecommendationsPage({super.key});

  @override
  State<UserRecommendationsPage> createState() =>
      _UserRecommendationsPageState();
}

class _UserRecommendationsPageState extends State<UserRecommendationsPage> {
  List<MerchantMenuItem> _items = [];
  bool _loading = true;
  String? _openingMerchantId;

  @override
  void initState() {
    super.initState();
    _load(forceRefresh: true);
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    final displayName = AuthScope.of(context).session?.displayName ?? 'User';
    final result = await UserRepository.getDashboard(
      displayName: displayName,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    setState(() {
      _items = result.data?.recommendations ?? const [];
      _loading = false;
    });
  }

  Future<void> _openMerchant(MerchantMenuItem item) async {
    if (item.merchantId.isEmpty || item.merchantType.isEmpty) return;
    if (_openingMerchantId != null) return;
    setState(() => _openingMerchantId = item.merchantId);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await UserRepository.getMerchantDetail(
      type: item.merchantType,
      id: item.merchantId,
    );
    if (!mounted) return;
    setState(() => _openingMerchantId = null);
    if (!result.isSuccess || result.data == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Gagal membuka detail merchant'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => MerchantDetailPage(merchant: result.data!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Rekomendasi Menu',
          style: TextStyle(
            color: UserTheme.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(forceRefresh: true),
        color: UserTheme.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  const Text(
                    'Produk dan layanan yang tersedia dari merchant aktif.',
                    style: TextStyle(color: UserTheme.muted, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  if (_items.isEmpty)
                    const _EmptyHint()
                  else
                    ..._items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MenuTile(
                          item: item,
                          loading: _openingMerchantId == item.merchantId,
                          onTap: () => _openMerchant(item),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Belum ada produk atau layanan aktif untuk direkomendasikan.',
        style: TextStyle(color: UserTheme.muted),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.item,
    required this.loading,
    required this.onTap,
  });

  final MerchantMenuItem item;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = item.merchantType.toLowerCase();
    final isLaundry = type == 'laundry';
    final icon =
        isLaundry ? Icons.local_laundry_service_rounded : Icons.restaurant;
    final unit = _unitSuffix(item.unit);
    final price = item.hasPromo && (item.promoPrice ?? 0) > 0
        ? item.promoPrice!
        : item.price;
    final priceLabel = '${formatUserCurrency(price)}$unit';
    final subtitle = [
      if (item.merchantName.trim().isNotEmpty) item.merchantName.trim(),
      if (item.category.trim().isNotEmpty) item.category.trim(),
    ].join(' - ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: item.merchantId.isEmpty ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              UserImage(
                url: item.imageUrl,
                icon: icon,
                width: 72,
                height: 72,
                borderRadius: BorderRadius.circular(14),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: UserTheme.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: UserTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      priceLabel,
                      style: const TextStyle(
                        color: UserTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.hasPromo && item.originalPrice != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${formatUserCurrency(item.originalPrice!)}$unit',
                        style: const TextStyle(
                          color: UserTheme.muted,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: UserTheme.muted),
            ],
          ),
        ),
      ),
    );
  }

  String _unitSuffix(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == 'fixed') return '';
    return value.startsWith('/') ? value : '/$value';
  }
}
