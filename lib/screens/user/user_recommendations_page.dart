import 'package:flutter/material.dart';

import '../../data/repositories/user_repository.dart';
import '../../models/user_merchant.dart';
import 'merchant_detail_page.dart';
import 'user_theme.dart';
import 'user_widgets.dart';

/// Rekomendasi merchant laundry & catering (bukan tab catering saja).
class UserRecommendationsPage extends StatefulWidget {
  const UserRecommendationsPage({super.key});

  @override
  State<UserRecommendationsPage> createState() =>
      _UserRecommendationsPageState();
}

class _UserRecommendationsPageState extends State<UserRecommendationsPage> {
  List<UserMerchant> _laundry = [];
  List<UserMerchant> _catering = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final laundry = await UserRepository.getMerchants('laundry');
    final catering = await UserRepository.getMerchants('catering');
    if (!mounted) return;

    final laundryList = List<UserMerchant>.from(laundry.data ?? [])
      ..sort(_compareMerchants);
    final cateringList = List<UserMerchant>.from(catering.data ?? [])
      ..sort(_compareMerchants);

    setState(() {
      _laundry = laundryList.take(6).toList();
      _catering = cateringList.take(6).toList();
      _loading = false;
    });
  }

  int _compareMerchants(UserMerchant a, UserMerchant b) {
    final rating = b.rating.compareTo(a.rating);
    if (rating != 0) return rating;
    if (a.hasDistanceEstimate != b.hasDistanceEstimate) {
      return a.hasDistanceEstimate ? -1 : 1;
    }
    return a.distanceKm.compareTo(b.distanceKm);
  }

  void _open(UserMerchant merchant) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MerchantDetailPage(merchant: merchant),
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
          'Rekomendasi Merchant',
          style: TextStyle(
            color: UserTheme.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: UserTheme.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  const Text(
                    'Merchant terbaik berdasarkan rating dan jarak dari kos Anda.',
                    style: TextStyle(color: UserTheme.muted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  const UserSectionHeader(title: 'Rekomendasi Laundry'),
                  const SizedBox(height: 12),
                  if (_laundry.isEmpty)
                    const _EmptyHint(text: 'Belum ada merchant laundry.')
                  else
                    ..._laundry.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child:
                            _MerchantTile(merchant: m, onTap: () => _open(m)),
                      ),
                    ),
                  const SizedBox(height: 28),
                  const UserSectionHeader(title: 'Rekomendasi Catering'),
                  const SizedBox(height: 12),
                  if (_catering.isEmpty)
                    const _EmptyHint(text: 'Belum ada merchant catering.')
                  else
                    ..._catering.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child:
                            _MerchantTile(merchant: m, onTap: () => _open(m)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(color: UserTheme.muted)),
    );
  }
}

class _MerchantTile extends StatelessWidget {
  const _MerchantTile({required this.merchant, required this.onTap});

  final UserMerchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final closed = !merchant.isAvailable;
    return Material(
      color: closed ? const Color(0xFFF1F3F5) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: closed ? Border.all(color: const Color(0xFFD5DAE1)) : null,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              UserImage(
                url: merchant.imageUrl,
                icon: merchant.type == 'laundry'
                    ? Icons.local_laundry_service_rounded
                    : Icons.restaurant_rounded,
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
                      merchant.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color:
                            closed ? const Color(0xFF4B5563) : UserTheme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 16, color: Color(0xFFFFB300)),
                        const SizedBox(width: 4),
                        Text(
                          merchant.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: UserTheme.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (merchant.hasDistanceEstimate) ...[
                          const SizedBox(width: 10),
                          Text(
                            '${merchant.distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(color: UserTheme.muted),
                          ),
                        ],
                      ],
                    ),
                    if (closed && merchant.openHours.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Jam operasional ${merchant.openHours}',
                        style: const TextStyle(
                          color: Color(0xFF6D7375),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (merchant.eta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Estimasi ${merchant.eta}',
                        style: const TextStyle(
                          color: UserTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (closed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'TUTUP',
                    style: TextStyle(
                      color: Color(0xFFC62828),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: UserTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}
