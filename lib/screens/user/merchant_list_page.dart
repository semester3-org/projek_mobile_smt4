import 'package:flutter/material.dart';

import '../../data/repositories/user_repository.dart';
import '../../models/user_merchant.dart';
import '../profile/notification_list_page.dart';
import 'merchant_detail_page.dart';
import 'user_theme.dart';
import 'user_widgets.dart';

class MerchantListPage extends StatefulWidget {
  const MerchantListPage({
    super.key,
    required this.type,
    required this.title,
    required this.searchHint,
    required this.filters,
    this.showLocationPrompt = false,
  });

  final String type;
  final String title;
  final String searchHint;
  final List<String> filters;
  final bool showLocationPrompt;

  @override
  State<MerchantListPage> createState() => _MerchantListPageState();
}

class _MerchantListPageState extends State<MerchantListPage> {
  final _searchCtrl = TextEditingController();
  List<UserMerchant> _merchants = [];
  bool _loading = true;
  String _selectedFilter = 'Semua';
  bool _promptShown = false;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.filters.first;
    _load();

    if (widget.showLocationPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showLocationDialog());
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await UserRepository.getMerchants(widget.type);
    if (!mounted) return;
    setState(() {
      _merchants = result.data ?? [];
      _loading = false;
    });
  }

  List<UserMerchant> get _filteredMerchants {
    final keyword = _searchCtrl.text.trim().toLowerCase();
    return _merchants.where((merchant) {
      final matchesSearch = keyword.isEmpty ||
          merchant.name.toLowerCase().contains(keyword) ||
          merchant.subtitle.toLowerCase().contains(keyword) ||
          merchant.tags.any((tag) => tag.toLowerCase().contains(keyword));

      if (!matchesSearch) return false;
      if (_selectedFilter == 'Semua') return true;
      if (_selectedFilter == 'Terdekat') return merchant.distanceKm <= 1.5;
      if (_selectedFilter == 'Terpopuler' ||
          _selectedFilter == 'Rating Tertinggi') {
        return merchant.rating >= 4.7;
      }
      return merchant.tags.any(
        (tag) => tag.toLowerCase().contains(_selectedFilter.toLowerCase()),
      );
    }).toList();
  }

  void _openDetail(UserMerchant merchant) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MerchantDetailPage(merchant: merchant),
      ),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationListPage()),
    );
  }

  void _showLocationDialog() {
    if (_promptShown || !mounted) return;
    _promptShown = true;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E7FF),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: UserTheme.primaryDark,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Ambil Lokasi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: UserTheme.text,
                      ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Untuk menemukan kafe terbaik di sekitar Anda, izinkan Sentra Ruang mengakses lokasi perangkat Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: UserTheme.muted,
                    height: 1.45,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: UserTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Izinkan Akses'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Nanti Saja',
                    style: TextStyle(color: UserTheme.muted),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMerchants;

    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: UserTheme.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openNotifications,
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: UserTheme.muted,
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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  UserSearchField(
                    hint: widget.searchHint,
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: widget.filters.map((filter) {
                        return UserFilterChip(
                          label: filter,
                          selected: _selectedFilter == filter,
                          onTap: () => setState(() => _selectedFilter = filter),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (filtered.isEmpty)
                    _EmptyMerchantState(type: widget.type)
                  else
                    ...filtered.map(
                      (merchant) => Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: _MerchantCard(
                          merchant: merchant,
                          onTap: () => _openDetail(merchant),
                        ),
                      ),
                    ),
                  const UserBottomSpacer(),
                ],
              ),
      ),
    );
  }
}

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({
    required this.merchant,
    required this.onTap,
  });

  final UserMerchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(merchant.type);
    final isCafe = merchant.type == 'cafe';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [UserTheme.softShadow(opacity: 0.06)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  UserImage(
                    url: merchant.imageUrl,
                    icon: icon,
                    height: 192,
                    width: double.infinity,
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: RatingBadge(
                      rating: merchant.rating,
                      reviewCount: isCafe ? merchant.reviewCount : null,
                    ),
                  ),
                  if (isCafe)
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: _StatusPill(status: merchant.status),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            merchant.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: UserTheme.text,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${merchant.distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: UserTheme.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (!isCafe) ...[
                      const SizedBox(height: 6),
                      Text(
                        merchant.subtitle,
                        style: const TextStyle(color: UserTheme.muted),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      children: merchant.tags
                          .take(3)
                          .map((tag) => UserTag(label: tag))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Divider(color: Colors.blueGrey.shade50, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (merchant.minPrice > 0) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mulai dari',
                                style: TextStyle(
                                  color: UserTheme.muted,
                                  fontSize: 11,
                                ),
                              ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          formatUserCurrency(merchant.minPrice),
                                      style: const TextStyle(
                                        color: UserTheme.primaryDark,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    TextSpan(
                                      text: merchant.priceUnit,
                                      style: const TextStyle(
                                        color: UserTheme.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.near_me_rounded,
                                size: 17,
                                color: UserTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                merchant.eta,
                                style: const TextStyle(
                                  color: UserTheme.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Spacer(),
                        FilledButton(
                          onPressed: onTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: merchant.isAvailable
                                ? UserTheme.primaryDark
                                : const Color(0xFF6D7375),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(isCafe ? 'Lihat Detail' : 'Pesan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isOpen = status.toLowerCase() != 'tutup';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isOpen ? UserTheme.success : const Color(0xFFFF5B62),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmptyMerchantState extends StatelessWidget {
  const _EmptyMerchantState({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(_iconForType(type), size: 54, color: UserTheme.muted),
          const SizedBox(height: 12),
          const Text(
            'Belum ada merchant yang cocok.',
            style: TextStyle(color: UserTheme.muted),
          ),
        ],
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
