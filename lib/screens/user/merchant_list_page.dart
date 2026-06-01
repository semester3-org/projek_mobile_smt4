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
  Set<String> _favoriteKeys = {};
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'Semua';
  String _selectedPackageCategory = 'Semua kategori';
  String _selectedDeliveryType = 'Semua tipe';
  String _selectedLaundryPricingType = 'Semua tipe harga';
  String _selectedLaundryDuration = 'Semua durasi';
  bool _locationUnavailable = false;

  bool get _isCatering => widget.type == 'catering';

  List<String> get _packageCategoryOptions {
    final categories = <String>{};
    for (final merchant in _merchants) {
      for (final item in merchant.menuItems) {
        final category = item.category.trim();
        if (category.isNotEmpty) categories.add(category);
      }
    }
    final sorted = categories.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['Semua kategori', ...sorted];
  }

  List<String> get _deliveryTypeOptions => const [
        'Semua tipe',
        'Full Day',
        'Weekday',
        'Keduanya',
      ];

  List<String> get _laundryPricingTypeOptions {
    final typeSet = <String>{};
    for (final merchant in _merchants) {
      for (final item in merchant.menuItems) {
        final label = item.pricingTypeLabel.trim();
        if (label.isNotEmpty) typeSet.add(label);
      }
    }
    final sorted = typeSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['Semua tipe harga', ...sorted];
  }

  List<String> get _laundryDurationOptions => const [
        'Semua durasi',
        '≤ 6 jam',
        '1 hari',
        '2+ hari',
      ];

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

  Future<void> _load({bool silent = false, bool forceRefresh = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
        _locationUnavailable = false;
      });
    }

    final result = await UserRepository.getMerchants(
      widget.type,
      forceRefresh: forceRefresh,
    );
    final favoriteKeys = await UserRepository.getFavoriteMerchantKeys();
    if (!mounted) return;
    setState(() {
      _merchants = result.data ?? [];
      _favoriteKeys = favoriteKeys;
      _error = result.isSuccess ? null : result.error;
      _loading = false;
    });
  }

  List<UserMerchant> get _filteredMerchants {
    final keyword = _searchCtrl.text.trim().toLowerCase();
    final effectiveCategory = _packageCategoryOptions.contains(
      _selectedPackageCategory,
    )
        ? _selectedPackageCategory
        : 'Semua kategori';
    final items = _merchants.where((merchant) {
      final matchesSearch = keyword.isEmpty ||
          merchant.name.toLowerCase().contains(keyword) ||
          merchant.subtitle.toLowerCase().contains(keyword) ||
          merchant.tags.any((tag) => tag.toLowerCase().contains(keyword));

      if (!matchesSearch) return false;

      if (_isCatering) {
        if (effectiveCategory != 'Semua kategori' &&
            !merchant.menuItems.any(
              (item) =>
                  item.category.toLowerCase() ==
                  effectiveCategory.toLowerCase(),
            )) {
          return false;
        }
        if (!_matchesDeliveryType(merchant)) {
          return false;
        }
      } else if (!_matchesLaundryFilters(merchant)) {
        return false;
      }

      if (_selectedFilter == 'Semua' ||
          _selectedFilter == 'Terdekat' ||
          _selectedFilter == 'Terpopuler' ||
          _selectedFilter == 'Rating Tertinggi') {
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
        final reviews = b.reviewCount.compareTo(a.reviewCount);
        if (reviews != 0) return reviews;
        final rating = b.rating.compareTo(a.rating);
        if (rating != 0) return rating;
        return a.distanceKm.compareTo(b.distanceKm);
      });
    } else if (_selectedFilter == 'Rating Tertinggi') {
      items.sort((a, b) {
        final rating = b.rating.compareTo(a.rating);
        if (rating != 0) return rating;
        final reviews = b.reviewCount.compareTo(a.reviewCount);
        if (reviews != 0) return reviews;
        return a.distanceKm.compareTo(b.distanceKm);
      });
    }

    return items;
  }

  bool _matchesDeliveryType(UserMerchant merchant) {
    if (_selectedDeliveryType == 'Semua tipe') return true;
    final hasFullDay = merchant.menuItems.any((item) => item.price > 0);
    final hasWeekday = merchant.menuItems.any((item) => item.hasWeekdayPrice);
    return switch (_selectedDeliveryType) {
      'Full Day' => hasFullDay,
      'Weekday' => hasWeekday,
      'Keduanya' => hasFullDay && hasWeekday,
      _ => true,
    };
  }

  bool _matchesLaundryFilters(UserMerchant merchant) {
    final pricingType = _laundryPricingTypeOptions.contains(
      _selectedLaundryPricingType,
    )
        ? _selectedLaundryPricingType
        : 'Semua tipe harga';
    final duration = _selectedLaundryDuration;

    return merchant.menuItems.any((item) {
      if (pricingType != 'Semua tipe harga' &&
          item.pricingTypeLabel.toLowerCase() != pricingType.toLowerCase()) {
        return false;
      }
      if (duration != 'Semua durasi' &&
          !_matchesLaundryDuration(item.durationLabel, duration)) {
        return false;
      }
      return true;
    });
  }

  bool _matchesLaundryDuration(String label, String filter) {
    final lower = label.toLowerCase();
    final value =
        int.tryParse(RegExp(r'\d+').firstMatch(lower)?.group(0) ?? '');
    if (filter == '≤ 6 jam') {
      return lower.contains('jam') && value != null && value <= 6;
    }
    if (filter == '1 hari') {
      return lower.contains('hari') && value == 1;
    }
    if (filter == '2+ hari') {
      return lower.contains('hari') && value != null && value >= 2;
    }
    return true;
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
        onRefresh: () => _load(forceRefresh: true),
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
                  if (_isCatering) ...[
                    const SizedBox(height: 14),
                    _CateringPackageFilters(
                      categories: _packageCategoryOptions,
                      deliveryTypes: _deliveryTypeOptions,
                      selectedCategory: _packageCategoryOptions.contains(
                        _selectedPackageCategory,
                      )
                          ? _selectedPackageCategory
                          : 'Semua kategori',
                      selectedDeliveryType: _selectedDeliveryType,
                      onCategoryChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedPackageCategory = value);
                      },
                      onDeliveryTypeChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedDeliveryType = value);
                      },
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    _LaundryServiceFilters(
                      pricingTypes: _laundryPricingTypeOptions,
                      durations: _laundryDurationOptions,
                      selectedPricingType: _laundryPricingTypeOptions.contains(
                        _selectedLaundryPricingType,
                      )
                          ? _selectedLaundryPricingType
                          : 'Semua tipe harga',
                      selectedDuration: _selectedLaundryDuration,
                      onPricingChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedLaundryPricingType = value);
                      },
                      onDurationChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedLaundryDuration = value);
                      },
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (_error != null) ...[
                    _LoadErrorBanner(
                      message: _error!,
                      onRetry: () => _load(forceRefresh: true),
                    ),
                    const SizedBox(height: 16),
                  ],
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

class _CateringPackageFilters extends StatelessWidget {
  const _CateringPackageFilters({
    required this.categories,
    required this.deliveryTypes,
    required this.selectedCategory,
    required this.selectedDeliveryType,
    required this.onCategoryChanged,
    required this.onDeliveryTypeChanged,
  });

  final List<String> categories;
  final List<String> deliveryTypes;
  final String selectedCategory;
  final String selectedDeliveryType;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onDeliveryTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E8F2)),
        boxShadow: [UserTheme.softShadow(opacity: 0.035)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 19,
                color: UserTheme.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Filter Paket',
                style: TextStyle(
                  color: UserTheme.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  value: selectedCategory,
                  values: categories,
                  icon: Icons.category_outlined,
                  onChanged: onCategoryChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilterDropdown(
                  value: selectedDeliveryType,
                  values: deliveryTypes,
                  icon: Icons.delivery_dining_outlined,
                  onChanged: onDeliveryTypeChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LaundryServiceFilters extends StatelessWidget {
  const _LaundryServiceFilters({
    required this.pricingTypes,
    required this.durations,
    required this.selectedPricingType,
    required this.selectedDuration,
    required this.onPricingChanged,
    required this.onDurationChanged,
  });

  final List<String> pricingTypes;
  final List<String> durations;
  final String selectedPricingType;
  final String selectedDuration;
  final ValueChanged<String?> onPricingChanged;
  final ValueChanged<String?> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E8F2)),
        boxShadow: [UserTheme.softShadow(opacity: 0.035)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 19,
                color: UserTheme.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Filter Layanan',
                style: TextStyle(
                  color: UserTheme.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  value: selectedPricingType,
                  values: pricingTypes,
                  icon: Icons.sell_outlined,
                  onChanged: onPricingChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilterDropdown(
                  value: selectedDuration,
                  values: durations,
                  icon: Icons.schedule_outlined,
                  onChanged: onDurationChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.values,
    required this.icon,
    required this.onChanged,
  });

  final String value;
  final List<String> values;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = values.contains(value) ? value : values.first;
    return DropdownButtonFormField<String>(
      initialValue: effectiveValue,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: UserTheme.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
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
                        if (merchant.hasDistanceEstimate) ...[
                          const SizedBox(width: 12),
                          _DistanceSummary(merchant: merchant),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    _MerchantRatingSummary(merchant: merchant),
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

class _MerchantRatingSummary extends StatelessWidget {
  const _MerchantRatingSummary({required this.merchant});

  final UserMerchant merchant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 18),
        const SizedBox(width: 4),
        Text(
          merchant.rating.toStringAsFixed(1),
          style: const TextStyle(
            color: UserTheme.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(${merchant.reviewCount} ulasan merchant)',
          style: const TextStyle(color: UserTheme.muted, fontSize: 12),
        ),
      ],
    );
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

class _LoadErrorBanner extends StatelessWidget {
  const _LoadErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC2C2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: UserTheme.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: UserTheme.text,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Muat Ulang'),
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
