import 'package:flutter/material.dart';

import '../../data/repositories/user_repository.dart';
import '../../models/user_merchant.dart';
import '../user/merchant_detail_page.dart';
import '../user/user_theme.dart';
import '../user/user_widgets.dart';

class FavoriteMerchantsPage extends StatefulWidget {
  const FavoriteMerchantsPage({super.key});

  @override
  State<FavoriteMerchantsPage> createState() => _FavoriteMerchantsPageState();
}

class _FavoriteMerchantsPageState extends State<FavoriteMerchantsPage> {
  List<UserMerchant> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await UserRepository.getFavoriteMerchants();
    if (!mounted) return;
    setState(() {
      _items = result.data ?? [];
      _loading = false;
    });
  }

  void _openDetail(UserMerchant merchant) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
          builder: (_) => MerchantDetailPage(merchant: merchant),
        ))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Favorite',
          style: TextStyle(
            color: UserTheme.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: UserTheme.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
                    children: const [
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 64,
                        color: UserTheme.muted,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Belum ada favorite',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: UserTheme.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tekan ikon love di detail merchant untuk menyimpannya di profil.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: UserTheme.muted),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final merchant = _items[index];
                      return _FavoriteMerchantTile(
                        merchant: merchant,
                        onTap: () => _openDetail(merchant),
                      );
                    },
                  ),
      ),
    );
  }
}

class _FavoriteMerchantTile extends StatelessWidget {
  const _FavoriteMerchantTile({
    required this.merchant,
    required this.onTap,
  });

  final UserMerchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              UserImage(
                url: merchant.imageUrl,
                icon: _iconForType(merchant.type),
                width: 72,
                height: 72,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: UserTheme.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      merchant.subtitle.isEmpty
                          ? merchant.address
                          : merchant.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: UserTheme.muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 16, color: Color(0xFFFFB300)),
                        const SizedBox(width: 4),
                        Text(
                          merchant.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: UserTheme.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: UserTheme.muted),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'laundry':
        return Icons.local_laundry_service_rounded;
      case 'catering':
        return Icons.restaurant_rounded;
      default:
        return Icons.local_cafe_rounded;
    }
  }
}
