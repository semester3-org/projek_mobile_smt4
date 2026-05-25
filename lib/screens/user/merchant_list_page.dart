import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _locationUnavailable = false;
    });

    final position = widget.showLocationPrompt ? await _resolveLocation() : null;
    final result = await UserRepository.getMerchants(
      widget.type,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
    if (!mounted) return;
    setState(() {
      _merchants = result.data ?? [];
      _loading = false;
    });
  }

  Future<Position?> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationUnavailable = true);
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationUnavailable = true);
        return null;
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      if (mounted) setState(() => _locationUnavailable = true);
      return null;
    }
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
                                  color: UserTheme.text,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _DistanceSummary(merchant: merchant),
                      ],
                    ),
                    if (merchant.hasDistanceEstimate &&
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
                    const SizedBox(height: 6),
                    Text(
                      merchant.subtitle,
                      style: const TextStyle(color: UserTheme.muted),
                    ),
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
                          child: const Text('Pesan'),
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
    return Column(
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
        Text(
          merchant.hasDistanceEstimate
              ? '${merchant.distanceKm.toStringAsFixed(1)} km'
              : 'Aktifkan lokasi',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: merchant.hasDistanceEstimate
                ? UserTheme.primaryDark
                : UserTheme.muted,
            fontWeight: FontWeight.w800,
            fontSize: merchant.hasDistanceEstimate ? 14 : 12,
          ),
        ),
      ],
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
