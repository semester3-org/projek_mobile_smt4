import 'package:flutter/material.dart';
import '../../core/user_location_service.dart';
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
  Set<String> _favoriteKeys = {};
  bool _loading = true;
  String _selectedFilter = 'Semua';
  bool _locationUnavailable = false;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.filters.first;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _locationUnavailable = false;
      });
    }

    final coords = widget.showLocationPrompt
        ? await UserLocationService.current()
        : await UserLocationService.current();
    if (widget.showLocationPrompt && coords == null && mounted) {
      setState(() => _locationUnavailable = true);
    }
    final result = await UserRepository.getMerchants(
      widget.type,
      latitude: coords?.latitude,
      longitude: coords?.longitude,
    );
    final favoriteKeys = await UserRepository.getFavoriteMerchantKeys();
    if (!mounted) return;
    setState(() {
      _merchants = result.data ?? [];
      _favoriteKeys = favoriteKeys;
      _loading = false;
    });
  }

  List<UserMerchant> get _filteredMerchants {
    final keyword = _searchCtrl.text.trim().toLowerCase();
    final items = _merchants.where((merchant) {
      final matchesSearch = keyword.isEmpty ||
          merchant.name.toLowerCase().contains(keyword) ||
          merchant.subtitle.toLowerCase().contains(keyword) ||
          merchant.tags.any((tag) => tag.toLowerCase().contains(keyword));

      if (!matchesSearch) return false;
      if (_selectedFilter == 'Semua' ||
          _selectedFilter == 'Terdekat' ||
          _selectedFilter == 'Terpopuler') {
        return true;
      }
      return merchant.tags.any(
        (tag) => tag.toLowerCase().contains(_selectedFilter.toLowerCase()),
      );
    }).toList();

    if (_selectedFilter == 'Terdekat') {
      items.sort((a, b) {
        if (a.hasDistanceEstimate != b.hasDistanceEstimate) {
          return a.hasDistanceEstimate ? -1 : 1;
        }
        return a.distanceKm.compareTo(b.distanceKm);
      });
    } else if (_selectedFilter == 'Terpopuler') {
      items.sort((a, b) {
        final rating = b.rating.compareTo(a.rating);
        if (rating != 0) return rating;
        return a.distanceKm.compareTo(b.distanceKm);
      });
    }

    return items;
  }

  Future<void> _openDetail(UserMerchant merchant) async {
    final updated = await Navigator.of(context).push<UserMerchant>(
      MaterialPageRoute<UserMerchant>(
        builder: (_) => MerchantDetailPage(merchant: merchant),
      ),
    );
    if (updated != null && mounted) {
      final favoriteKeys = await UserRepository.getFavoriteMerchantKeys();
      if (!mounted) return;
      setState(() {
        _merchants =
            _merchants.map((m) => m.id == updated.id ? updated : m).toList();
        _favoriteKeys = favoriteKeys;
      });
    } else {
      _load(silent: true);
    }
  }

  Future<void> _toggleFavorite(UserMerchant merchant) async {
    final favorite = await UserRepository.toggleMerchantFavorite(merchant);
    if (!mounted) return;
    setState(() {
      final key = _favoriteKey(merchant);
      if (favorite) {
        _favoriteKeys.add(key);
      } else {
        _favoriteKeys.remove(key);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          favorite ? 'Disimpan ke favorite' : 'Dihapus dari favorite',
        ),
      ),
    );
  }

  String _favoriteKey(UserMerchant merchant) =>
      '${merchant.type}:${merchant.merchantId.isNotEmpty ? merchant.merchantId : merchant.id}';

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationListPage()),
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
          UserNotificationIconButton(
            onPressed: _openNotifications,
            color: UserTheme.muted,
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
                  if (widget.showLocationPrompt && _locationUnavailable) ...[
                    _LocationUnavailableBanner(onRetry: _load),
                    const SizedBox(height: 18),
                  ],
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
                          isFavorite: _favoriteKeys.contains(
                            _favoriteKey(merchant),
                          ),
                          onTap: () => _openDetail(merchant),
                          onToggleFavorite: () => _toggleFavorite(merchant),
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
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final UserMerchant merchant;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(merchant.type);

    final closed = !merchant.isAvailable;

    return Material(
      color: closed ? const Color(0xFFF1F3F5) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: closed ? const Color(0xFFF1F3F5) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: closed
                ? Border.all(color: const Color(0xFFD5DAE1))
                : Border.all(color: Colors.transparent),
            boxShadow: [UserTheme.softShadow(opacity: closed ? 0.03 : 0.06)],
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
                  if (closed)
                    Positioned.fill(
                      child: Container(
                        color: Colors.grey.withValues(alpha: 0.18),
                      ),
                    ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Favorite',
                        onPressed: onToggleFavorite,
                        icon: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color:
                              isFavorite ? Colors.redAccent : UserTheme.muted,
                        ),
                      ),
                    ),
                  ),
                  if (closed)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'TUTUP',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      top: 14,
                      right: 14,
                      child: RatingBadge(
                        rating: merchant.rating,
                      ),
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
                                  color: closed
                                      ? const Color(0xFF4B5563)
                                      : UserTheme.text,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _DistanceSummary(merchant: merchant),
                      ],
                    ),
                    if (closed && merchant.openHours.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: Color(0xFF6D7375),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Jam operasional ${merchant.openHours}',
                              style: const TextStyle(
                                color: Color(0xFF6D7375),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (merchant.hasDistanceEstimate &&
                        merchant.eta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            size: 16,
                            color: UserTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Perkiraan sampai ${merchant.eta}',
                            style: const TextStyle(color: UserTheme.muted),
                          ),
                        ],
                      ),
                    ],
                    if (merchant.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        merchant.subtitle,
                        style: const TextStyle(color: UserTheme.muted),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                        Expanded(
                          child: merchant.minPrice > 0
                              ? Column(
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
                                            text: formatUserCurrency(
                                              merchant.minPrice,
                                            ),
                                            style: TextStyle(
                                              color: closed
                                                  ? const Color(0xFF4B5563)
                                                  : UserTheme.primaryDark,
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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    const Icon(
                                      Icons.near_me_rounded,
                                      size: 17,
                                      color: UserTheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        merchant.eta,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: UserTheme.primaryDark,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: closed ? null : onTap,
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
                          child: Text(closed ? 'Tutup' : 'Pesan'),
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
        return Icons.storefront_rounded;
    }
  }
}

class _DistanceSummary extends StatelessWidget {
  const _DistanceSummary({required this.merchant});

  final UserMerchant merchant;

  @override
  Widget build(BuildContext context) {
    final hasEta = merchant.hasDistanceEstimate && merchant.eta.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'Estimasi jarak',
            style: TextStyle(
              color: UserTheme.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            merchant.hasDistanceEstimate
                ? '${merchant.distanceKm.toStringAsFixed(1)} km'
                : 'Atur lokasi profil',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: merchant.hasDistanceEstimate
                  ? UserTheme.primaryDark
                  : UserTheme.muted,
              fontWeight: FontWeight.w800,
              fontSize: merchant.hasDistanceEstimate ? 14 : 12,
            ),
          ),
          if (hasEta) ...[
            const SizedBox(height: 2),
            Text(
              merchant.eta,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: UserTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationUnavailableBanner extends StatelessWidget {
  const _LocationUnavailableBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD8A8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_outlined, color: Color(0xFFE66000)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Estimasi jarak dan waktu hanya ditampilkan setelah lokasi diizinkan.',
              style: TextStyle(
                color: UserTheme.text,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Coba Lagi'),
          ),
        ],
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
        return Icons.storefront_rounded;
    }
  }
}
