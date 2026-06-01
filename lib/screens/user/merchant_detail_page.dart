import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_scope.dart';
import '../../core/payment_methods.dart';
import '../../auth/roles.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/user_merchant.dart';
import '../../widgets/location_picker_page.dart';
import '../../widgets/review_card.dart';
import 'merchant_reviews_page.dart';
import 'order_detail_page.dart';
import 'user_theme.dart';
import 'user_widgets.dart';

class MerchantDetailPage extends StatefulWidget {
  const MerchantDetailPage({
    super.key,
    required this.merchant,
  });

  final UserMerchant merchant;

  @override
  State<MerchantDetailPage> createState() => _MerchantDetailPageState();
}

class _MerchantDetailPageState extends State<MerchantDetailPage> {
  late UserMerchant _merchant;
  bool _loading = true;
  bool _isFavorite = false;
  bool _submittingReview = false;
  int _selectedRating = 0;
  UserMerchantReviewState? _reviewState;
  String? _selectedReviewProductId;
  final _reviewCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _merchant = widget.merchant;
    _load();
    _loadFavorite();
    _loadReviewState();
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({
    bool forceRefresh = false,
  }) async {
    final result = await UserRepository.getMerchantDetail(
      type: widget.merchant.type,
      id: _merchantId,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    setState(() {
      _merchant = result.data ?? widget.merchant;
      _loading = false;
    });
  }

  String get _merchantId =>
      _merchant.merchantId.isNotEmpty ? _merchant.merchantId : _merchant.id;

  Future<void> _loadFavorite() async {
    final merchantId = widget.merchant.merchantId.isNotEmpty
        ? widget.merchant.merchantId
        : widget.merchant.id;
    final favorite = await UserRepository.isMerchantFavorite(
      type: widget.merchant.type,
      merchantId: merchantId,
    );
    if (!mounted) return;
    setState(() => _isFavorite = favorite);
  }

  Future<void> _toggleFavorite() async {
    final favorite = await UserRepository.toggleMerchantFavorite(_merchant);
    if (!mounted) return;
    setState(() => _isFavorite = favorite);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          favorite ? 'Disimpan ke favorite' : 'Dihapus dari favorite',
        ),
      ),
    );
  }

  MerchantReview? _activeReviewFor(String? productId) {
    if (productId == null || productId.isEmpty) return null;
    final reviews = _reviewState?.myReviews ?? const <MerchantReview>[];
    for (final review in reviews) {
      if (!review.isDeleted && review.productId == productId) return review;
    }
    return null;
  }

  void _syncReviewForm() {
    final products = _reviewState?.reviewableProducts ?? const [];
    if (products.isEmpty) {
      _selectedReviewProductId = null;
      _selectedRating = 0;
      _reviewCtrl.clear();
      return;
    }
    if (_selectedReviewProductId == null ||
        !products.any((product) => product.id == _selectedReviewProductId)) {
      _selectedReviewProductId = products.first.id;
    }
    final active = _activeReviewFor(_selectedReviewProductId);
    _selectedRating = active?.rating.round() ?? 0;
    _reviewCtrl.text = active?.comment ?? '';
  }

  Future<void> _loadReviewState() async {
    final result = await UserRepository.getMerchantReviewState(
      type: _merchant.type,
      merchantId: _merchantId,
    );
    if (!mounted || !result.isSuccess) return;
    setState(() {
      _reviewState = result.data;
      _syncReviewForm();
    });
  }

  void _selectReviewProduct(String productId) {
    setState(() {
      _selectedReviewProductId = productId;
      _syncReviewForm();
    });
  }

  Future<void> _showProductDetail(MerchantMenuItem item) async {
    final result = await showModalBottomSheet<_ProductDetailResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProductDetailSheet(
        merchant: _merchant,
        item: item,
      ),
    );

    if (result == null) return;
    await _openOrder(
      result.item,
      initialCateringDays: result.cateringDays,
      initialLaundryAddonIds: result.selectedAddonIds,
    );
  }

  Future<void> _openOrder(
    MerchantMenuItem? item, {
    int? initialCateringDays,
    List<String> initialLaundryAddonIds = const [],
  }) async {
    final draft = await showModalBottomSheet<_OrderDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OrderCheckoutSheet(
        merchant: _merchant,
        initialItem: item,
        initialCateringDays: initialCateringDays,
        initialLaundryAddonIds: initialLaundryAddonIds,
      ),
    );

    if (draft == null) return;

    if (!_merchant.isAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merchant sedang tutup')),
      );
      return;
    }

    if (!mounted) return;
    if (_merchant.type == 'catering') {
      final existingMessage = await _existingCateringOrderMessage();
      if (!mounted) return;
      if (existingMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existingMessage)),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mengirim pesanan ke merchant...')),
    );

    final result = await UserRepository.createOrder(
      merchant: _merchant,
      items: draft.items,
      quantities: draft.quantities,
      deliveryAddress: draft.deliveryAddress,
      deliveryLatitude: draft.deliveryLatitude,
      deliveryLongitude: draft.deliveryLongitude,
      estimatedTime: draft.estimatedTime,
      paymentMethod: draft.paymentMethod,
      subscriptionDays: draft.subscriptionDays,
      customerName: draft.customerName,
      customerPhone: draft.customerPhone,
      notes: draft.notes,
      addonIds: draft.selectedAddonIds,
    );
    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => UserOrderDetailPage(order: result.data!),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Gagal membuat pesanan')),
    );
  }

  Future<String?> _existingCateringOrderMessage() async {
    final result = await UserRepository.getCateringSubscriptions(status: 'all');
    if (!result.isSuccess) return null;
    final active = (result.data ?? const []).where((subscription) {
      final status = subscription.subscriptionStatus.toLowerCase();
      return subscription.isActive ||
          status == 'pending' ||
          status == 'pending_payment';
    }).toList();
    if (active.isEmpty) return null;
    final item = active.first;
    final product = item.productName.isNotEmpty
        ? item.productName
        : item.packageLabel.isNotEmpty
            ? item.packageLabel
            : 'catering';
    return 'Kamu masih punya pesanan/langganan $product. Gunakan menu perpanjang di detail langganan agar jadwal tidak bentrok.';
  }

  Future<void> _submitReview() async {
    final comment = _reviewCtrl.text.trim();
    final productId = _selectedReviewProductId;
    if (productId == null || productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ulasan hanya bisa dibuat untuk produk yang pernah dibeli',
          ),
        ),
      );
      return;
    }
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jumlah bintang terlebih dahulu')),
      );
      return;
    }
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tulis pengalaman Anda terlebih dahulu')),
      );
      return;
    }

    final active = _activeReviewFor(productId);
    if (active != null && active.remainingEditAttempts <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batas edit ulasan telah tercapai.')),
      );
      return;
    }

    setState(() => _submittingReview = true);
    final isUpdate = active != null;
    final result = await UserRepository.submitMerchantRating(
      type: _merchant.type,
      merchantId: _merchantId,
      productId: productId,
      rating: _selectedRating,
      comment: comment,
      update: isUpdate,
    );
    if (!mounted) return;

    if (result.isSuccess) {
      final refreshed = await UserRepository.getMerchantDetail(
        type: _merchant.type,
        id: _merchantId,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _merchant = refreshed.data ?? _merchant;
        _reviewState = result.data;
        _syncReviewForm();
        _submittingReview = false;
      });
    } else {
      setState(() => _submittingReview = false);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isSuccess
            ? (isUpdate
                ? 'Ulasan berhasil diperbarui'
                : 'Ulasan berhasil dikirim')
            : result.error ?? 'Gagal mengirim ulasan'),
      ),
    );
  }

  Future<void> _deleteReview() async {
    final productId = _selectedReviewProductId;
    if (productId == null || productId.isEmpty) return;
    final active = _activeReviewFor(productId);
    if (active == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus ulasan?'),
        content: const Text(
          'Ulasan akan dihapus dari rating publik. Setelah itu Anda bisa membuat ulasan baru untuk produk ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submittingReview = true);
    final result = await UserRepository.deleteMerchantRating(
      type: _merchant.type,
      merchantId: _merchantId,
      productId: productId,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      final refreshed = await UserRepository.getMerchantDetail(
        type: _merchant.type,
        id: _merchantId,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _merchant = refreshed.data ?? _merchant;
        _reviewState = result.data;
        _syncReviewForm();
        _submittingReview = false;
      });
    } else {
      setState(() => _submittingReview = false);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isSuccess
            ? 'Ulasan berhasil dihapus'
            : result.error ?? 'Gagal menghapus ulasan'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
      },
      child: Scaffold(
        backgroundColor: UserTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context, _merchant),
          ),
          title: const Text(
            'Detail Merchant',
            style: TextStyle(
              color: UserTheme.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(
                _isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _isFavorite ? Colors.redAccent : null,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.share_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: UserTheme.primary,
          onRefresh: () => _load(forceRefresh: true),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  children: [
                    _HeaderCard(merchant: _merchant),
                    const SizedBox(height: 22),
                    _MerchantSummary(merchant: _merchant),
                    const SizedBox(height: 18),
                    _ActivePromoSection(merchant: _merchant),
                    const SizedBox(height: 30),
                    UserSectionHeader(
                      title: _merchant.type == 'laundry'
                          ? 'Daftar Layanan'
                          : 'Daftar Menu',
                    ),
                    const SizedBox(height: 14),
                    if (_merchant.menuItems.isEmpty)
                      _EmptyMenu(type: _merchant.type)
                    else
                      ..._merchant.menuItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _MenuItemCard(
                            type: _merchant.type,
                            item: item,
                            onOrder: () {
                              _showProductDetail(item);
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    _ReviewSection(
                      merchant: _merchant,
                      reviewState: _reviewState,
                      selectedProductId: _selectedReviewProductId,
                      selectedRating: _selectedRating,
                      controller: _reviewCtrl,
                      isSubmitting: _submittingReview,
                      activeReview: _activeReviewFor(_selectedReviewProductId),
                      onProductChanged: _selectReviewProduct,
                      onRatingChanged: (rating) {
                        setState(() => _selectedRating = rating);
                      },
                      onSubmit: _submitReview,
                      onDelete: _deleteReview,
                    ),
                    const SizedBox(height: 22),
                    const UserBottomSpacer(),
                  ],
                ),
        ),
        bottomNavigationBar: null,
      ),
    );
  }
}

class _ProductDetailResult {
  const _ProductDetailResult({
    required this.item,
    this.cateringDays,
    this.selectedAddonIds = const [],
  });

  final MerchantMenuItem item;
  final int? cateringDays;
  final List<String> selectedAddonIds;
}

class _ProductDetailSheet extends StatefulWidget {
  const _ProductDetailSheet({
    required this.merchant,
    required this.item,
  });

  final UserMerchant merchant;
  final MerchantMenuItem item;

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  int _cateringDays = 30;
  final Set<String> _selectedAddonIds = {};

  bool get _isCatering => widget.merchant.type == 'catering';
  bool get _hasWeekdayPackage => widget.item.hasWeekdayPrice;

  double get _price {
    if (!_isCatering) return widget.item.price;
    return widget.item.cateringPriceForDays(_cateringDays);
  }

  bool get _showPromo {
    final hasPromo = widget.item.hasPromo &&
        (widget.item.promoPrice ?? 0) > 0 &&
        (widget.item.promoDiscountAmount ?? 0) > 0;
    if (!hasPromo) return false;
    return _promoPrice < _price;
  }

  double get _promoPrice {
    final discountAmount = widget.item.promoDiscountAmount ?? 0;
    if (discountAmount <= 0) return _price;
    final promoPrice = _price - discountAmount;
    return promoPrice.clamp(0, double.infinity);
  }

  double get _displayPrice {
    if (!_showPromo) return _price;
    return _promoPrice;
  }

  double get _discountAmount =>
      (_price - _displayPrice).clamp(0, double.infinity);

  void _toggleAddon(String id) {
    setState(() {
      if (_selectedAddonIds.contains(id)) {
        _selectedAddonIds.remove(id);
      } else {
        _selectedAddonIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7E3F4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            UserImage(
              url: widget.item.imageUrl,
              icon: _isCatering
                  ? Icons.restaurant_rounded
                  : Icons.local_laundry_service_rounded,
              width: double.infinity,
              height: 190,
              borderRadius: BorderRadius.circular(18),
            ),
            const SizedBox(height: 18),
            Text(
              widget.item.name,
              style: const TextStyle(
                color: UserTheme.text,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.item.description.isEmpty
                  ? widget.merchant.description
                  : widget.item.description,
              style: const TextStyle(
                color: UserTheme.muted,
                height: 1.45,
              ),
            ),
            if (_isCatering) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ProductInfoChip(
                    icon: Icons.star_rounded,
                    label:
                        '${widget.item.rating.toStringAsFixed(1)} (${widget.item.reviewCount})',
                    color: const Color(0xFFFFB300),
                  ),
                  _ProductInfoChip(
                    icon: Icons.delivery_dining_rounded,
                    label: widget.item.mealDeliveryCount >= 2
                        ? '2x makan/hari'
                        : '1x makan/hari',
                    color: UserTheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CateringDeliveryInfoBox(item: widget.item),
            ],
            if (_showPromo &&
                (widget.item.promoDescription ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                widget.item.promoDescription!,
                style: const TextStyle(
                  color: UserTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
            if (_showPromo &&
                _isCatering &&
                _hasWeekdayPackage &&
                _cateringDays == 20) ...[
              const SizedBox(height: 6),
              const Text(
                'Catatan: promo dihitung berdasarkan paket Full Day (30 hari).',
                style: TextStyle(
                  color: UserTheme.muted,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              '${formatUserCurrency(_displayPrice)}${_isCatering ? '' : widget.item.unit}',
              style: const TextStyle(
                color: UserTheme.primaryDark,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (_showPromo) ...[
              Text(
                '${formatUserCurrency(_price)}${_isCatering ? '' : widget.item.unit}',
                style: const TextStyle(
                  color: UserTheme.muted,
                  decoration: TextDecoration.lineThrough,
                  fontSize: 13,
                ),
              ),
              Text(
                'Hemat ${formatUserCurrency(_discountAmount)}',
                style: const TextStyle(
                  color: UserTheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
            if (_isCatering) ...[
              const SizedBox(height: 16),
              if (_hasWeekdayPackage)
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 20, label: Text('Weekday 30 hari')),
                    ButtonSegment(value: 30, label: Text('Full Day 30 hari')),
                  ],
                  selected: {_cateringDays},
                  onSelectionChanged: (value) {
                    setState(() => _cateringDays = value.first);
                  },
                ),
              const SizedBox(height: 8),
              Text(
                _hasWeekdayPackage && _cateringDays == 20
                    ? 'Weekday 30 hari: dikirim Senin-Jumat. Sabtu dan Minggu libur.'
                    : 'Full Day: makanan dikirim setiap hari, termasuk Sabtu dan Minggu.',
                style: const TextStyle(color: UserTheme.muted, fontSize: 12),
              ),
            ],
            if (!_isCatering && widget.item.addons.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Tambahan Layanan Opsional',
                style: TextStyle(
                  color: UserTheme.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.item.addons.map(_buildAddonOption),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  _ProductDetailResult(
                    item: widget.item,
                    cateringDays: _isCatering ? _cateringDays : null,
                    selectedAddonIds: _selectedAddonIds.toList(),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: UserTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Lanjut Pesan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddonOption(MerchantMenuAddon addon) {
    final selected = _selectedAddonIds.contains(addon.id);
    return InkWell(
      onTap: () => _toggleAddon(addon.id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? UserTheme.softBlue : const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? UserTheme.primary : const Color(0xFFE3EBF6),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => _toggleAddon(addon.id),
              activeColor: UserTheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    addon.name,
                    style: const TextStyle(
                      color: UserTheme.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _laundryAddonPriceLabel(addon),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: UserTheme.primaryDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderDraft {
  const _OrderDraft({
    required this.items,
    required this.quantities,
    required this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    required this.estimatedTime,
    required this.paymentMethod,
    this.subscriptionDays,
    required this.customerName,
    required this.customerPhone,
    required this.notes,
    this.selectedAddonIds = const [],
  });

  final List<MerchantMenuItem> items;
  final Map<String, int> quantities;
  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String estimatedTime;
  final String paymentMethod;
  final int? subscriptionDays;
  final String customerName;
  final String customerPhone;
  final String notes;
  final List<String> selectedAddonIds;
}

class _OrderCheckoutSheet extends StatefulWidget {
  const _OrderCheckoutSheet({
    required this.merchant,
    this.initialItem,
    this.initialCateringDays,
    this.initialLaundryAddonIds = const [],
  });

  final UserMerchant merchant;
  final MerchantMenuItem? initialItem;
  final int? initialCateringDays;
  final List<String> initialLaundryAddonIds;

  @override
  State<_OrderCheckoutSheet> createState() => _OrderCheckoutSheetState();
}

class _OrderCheckoutSheetState extends State<_OrderCheckoutSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Set<String> _selectedLaundryIds = {};
  final Set<String> _selectedLaundryAddonIds = {};

  MerchantMenuItem? _selectedCateringItem;
  String _paymentMethod = 'cod';
  int _cateringDays = 30;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  bool _didLoadProfile = false;
  String? _sheetError;

  bool get _isLaundry => widget.merchant.type == 'laundry';

  List<String> get _paymentOptions =>
      PaymentMethodHelper.checkoutOptionKeys(isLaundry: _isLaundry);

  String _paymentOptionLabel(String method) {
    final displayName = PaymentMethodHelper.getDisplayName(method);
    final category = PaymentMethodHelper.getCategory(method);
    if (category.isEmpty ||
        displayName.toLowerCase().contains(category.toLowerCase())) {
      return displayName;
    }
    return '$displayName - $category';
  }

  List<MerchantMenuItem> get _items {
    if (widget.merchant.menuItems.isNotEmpty) return widget.merchant.menuItems;
    return [
      MerchantMenuItem(
        id: '${widget.merchant.id}-order',
        name: _isLaundry ? 'Layanan Laundry' : 'Paket Catering',
        description: widget.merchant.description,
        price: widget.merchant.minPrice > 0 ? widget.merchant.minPrice : 25000,
        imageUrl: widget.merchant.imageUrl,
        category: _isLaundry ? 'Laundry' : 'Paket Bulanan',
        unit: _isLaundry ? '/item' : '/bulan',
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _paymentMethod = _isLaundry ? 'cod' : '';
    _cateringDays = widget.initialCateringDays ?? 30;
    final initial = widget.initialItem ?? _items.first;
    if (_isLaundry) {
      _selectedLaundryIds.add(initial.id);
      final validAddonIds = initial.addons.map((addon) => addon.id).toSet();
      _selectedLaundryAddonIds.addAll(
        widget.initialLaundryAddonIds.where(validAddonIds.contains),
      );
    } else {
      _selectedCateringItem = initial;
      if (_cateringDays == 20 && !initial.hasWeekdayPrice) {
        _cateringDays = 30;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadProfile) return;
    _didLoadProfile = true;
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final session = AuthScope.of(context).session;
    final result = await UserRepository.getProfile(
      displayName: session?.displayName ?? 'User',
      email: session?.email ?? '',
      role: session?.role.label ?? 'User',
    );
    if (!mounted || result.data == null) return;
    final profile = result.data!;
    setState(() {
      _nameCtrl.text = profile.displayName;
      _phoneCtrl.text = profile.phone ?? '';
      _addressCtrl.text = profile.address ?? '';
      _deliveryLatitude = profile.latitude;
      _deliveryLongitude = profile.longitude;
    });
  }

  double get _total {
    if (_isLaundry) return 0;
    return (_subtotal - _promoDiscount).clamp(0, double.infinity);
  }

  double get _subtotal {
    if (_isLaundry) return 0;
    return _adjustedCateringPrice(_selectedCateringItem);
  }

  double get _promoDiscount {
    if (_isLaundry) return 0;
    final selected = _selectedCateringItem;
    if (selected == null || !selected.hasPromo) return 0;
    return (selected.promoDiscountAmount ?? 0).clamp(0, _subtotal);
  }

  double _adjustedCateringPrice(MerchantMenuItem? item) {
    if (item == null) return 0;
    if (_cateringDays == 20 && !item.hasWeekdayPrice) return item.price;
    return item.cateringPriceForDays(_cateringDays);
  }

  List<MerchantMenuItem> get _selectedItems {
    if (_isLaundry) {
      return _items
          .where((item) => _selectedLaundryIds.contains(item.id))
          .map(
            (item) => MerchantMenuItem(
              id: item.id,
              name: item.name,
              description: item.description,
              price: item.price,
              imageUrl: item.imageUrl,
              category: item.category,
              unit: item.unit,
              price20Days: item.price20Days,
              price30Days: item.price30Days,
              packageDeliveryType: item.packageDeliveryType,
              hasPromo: item.hasPromo,
              originalPrice: item.originalPrice,
              promoPrice: item.promoPrice,
              promoDiscountAmount: item.promoDiscountAmount,
              promoDiscountType: item.promoDiscountType,
              promoDiscountValue: item.promoDiscountValue,
              promoLabel: item.promoLabel,
              promoDescription: item.promoDescription,
              pricingType: item.pricingType,
              pricingTypeLabel: item.pricingTypeLabel,
              durationLabel: item.durationLabel,
              addons: item.addons,
            ),
          )
          .toList();
    }
    final selected = _selectedCateringItem;
    if (selected == null) return const [];
    return [
      MerchantMenuItem(
        id: selected.id,
        name: selected.name,
        description: selected.description,
        price: _adjustedCateringPrice(selected),
        imageUrl: selected.imageUrl,
        category: selected.category,
        unit: selected.unit,
        packageDeliveryType: selected.packageDeliveryType,
        mealDeliveryCount: selected.mealDeliveryCount,
        deliveryTime1: selected.deliveryTime1,
        deliveryTime2: selected.deliveryTime2,
        rating: selected.rating,
        reviewCount: selected.reviewCount,
        hasPromo: selected.hasPromo,
        originalPrice: selected.originalPrice,
        promoPrice: selected.promoPrice,
        promoDiscountAmount: selected.promoDiscountAmount,
        promoDiscountType: selected.promoDiscountType,
        promoDiscountValue: selected.promoDiscountValue,
        promoLabel: selected.promoLabel,
        promoDescription: selected.promoDescription,
        pricingType: selected.pricingType,
        pricingTypeLabel: selected.pricingTypeLabel,
        durationLabel: selected.durationLabel,
        addons: selected.addons,
      ),
    ];
  }

  Future<void> _pickDeliveryLocation() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute<PickedLocation>(
        builder: (_) => LocationPickerPage(
          title: 'Pilih Alamat Tujuan',
          initialAddress: _addressCtrl.text,
          initialLatitude: _deliveryLatitude,
          initialLongitude: _deliveryLongitude,
          primaryColor: UserTheme.primary,
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _addressCtrl.text = result.address;
      _deliveryLatitude = result.latitude;
      _deliveryLongitude = result.longitude;
      _sheetError = null;
    });
  }

  void _showSheetError(String message) {
    setState(() => _sheetError = message);
  }

  String _laundryServiceEstimateFor(List<MerchantMenuItem> items) {
    if (items.isEmpty) return 'Estimasi layanan ditentukan merchant';
    final duration = items.first.durationLabel.trim();
    if (duration.isNotEmpty) return duration;
    final category = items.first.category.trim();
    if (category.isEmpty) return 'Estimasi layanan ditentukan merchant';
    return category;
  }

  List<MerchantMenuAddon> _addonsFor(MerchantMenuItem item) {
    if (_selectedLaundryAddonIds.isEmpty) return const [];
    return item.addons
        .where((addon) => _selectedLaundryAddonIds.contains(addon.id))
        .toList();
  }

  bool _isValidPhoneNumber(String value) {
    final phone = value.trim();
    if (phone.isEmpty) return false;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final hasValidPrefix = digits.startsWith('08') || digits.startsWith('628');
    return hasValidPrefix && digits.length >= 10 && digits.length <= 15;
  }

  void _submit() {
    final selectedItems = _selectedItems;
    if (selectedItems.isEmpty) {
      _showSheetError('Pilih minimal satu layanan laundry');
      return;
    }
    if (!_isLaundry && _total <= 0) {
      _showSheetError('Pilih paket catering terlebih dahulu');
      return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      _showSheetError('Alamat tujuan wajib diisi');
      return;
    }
    final customerName = _nameCtrl.text.trim();
    final validName = RegExp(r"^[A-Za-z .'-]{2,}$").hasMatch(customerName) &&
        RegExp(r'[A-Za-z]').hasMatch(customerName);
    if (_isLaundry && !validName) {
      _showSheetError('Nama penerima hanya boleh huruf dan spasi');
      return;
    }
    if (!_isValidPhoneNumber(_phoneCtrl.text)) {
      _showSheetError(
        'Nomor telepon wajib valid. Gunakan format 08..., 628..., atau +628...',
      );
      return;
    }

    final selectedCatering = _selectedCateringItem;
    final useWeekday = widget.merchant.type == 'catering' &&
        _cateringDays == 20 &&
        (selectedCatering?.hasWeekdayPrice ?? false);
    final cateringNote = widget.merchant.type == 'catering'
        ? (useWeekday
            ? 'Paket Weekday 30 hari: dikirim Senin-Jumat, Sabtu/Minggu tidak dikirim.'
            : 'Paket Full Day: dikirim setiap hari, termasuk Sabtu dan Minggu.')
        : '';
    final notes = [
      if (cateringNote.isNotEmpty) cateringNote,
      if (_isLaundry && _notesCtrl.text.trim().isNotEmpty)
        _notesCtrl.text.trim(),
    ].join('\n');

    Navigator.of(context).pop(
      _OrderDraft(
        items: selectedItems,
        quantities: {
          for (final item in selectedItems) item.id: 1,
        },
        deliveryAddress: _addressCtrl.text.trim(),
        deliveryLatitude: _deliveryLatitude,
        deliveryLongitude: _deliveryLongitude,
        estimatedTime: _isLaundry
            ? _laundryServiceEstimateFor(selectedItems)
            : (useWeekday ? 'Paket Weekday 30 Hari' : 'Paket Full Day'),
        paymentMethod: _paymentMethod,
        subscriptionDays: _isLaundry ? null : 30,
        customerName: customerName,
        customerPhone: _phoneCtrl.text.trim(),
        notes: notes,
        selectedAddonIds:
            _isLaundry ? _selectedLaundryAddonIds.toList() : const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7E3F4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _isLaundry ? 'Detail Pesanan Laundry' : 'Detail Paket Catering',
              style: const TextStyle(
                color: UserTheme.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            if (_sheetError != null) ...[
              _SheetErrorBanner(message: _sheetError!),
              const SizedBox(height: 14),
            ],
            if (widget.initialItem != null) ...[
              lockedItemSummary(widget.initialItem!),
              if (!_isLaundry && widget.initialItem!.hasWeekdayPrice) ...[
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 20, label: Text('Weekday 30 hari')),
                    ButtonSegment(value: 30, label: Text('Full Day')),
                  ],
                  selected: {_cateringDays},
                  onSelectionChanged: (value) {
                    setState(() => _cateringDays = value.first);
                  },
                ),
              ],
            ] else if (_isLaundry)
              laundryItemPicker()
            else
              cateringItemPicker(),
            const SizedBox(height: 18),
            _CheckoutField(
              controller: _nameCtrl,
              label: 'Nama Penerima',
              icon: Icons.person_outline_rounded,
              readOnly: !_isLaundry,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z .'-]")),
                LengthLimitingTextInputFormatter(60),
              ],
            ),
            const SizedBox(height: 12),
            _CheckoutField(
              controller: _phoneCtrl,
              label: 'Nomor Telepon',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLaundry) ...[
              DropdownButtonFormField<String>(
                initialValue: _paymentOptions.contains(_paymentMethod)
                    ? _paymentMethod
                    : _paymentOptions.first,
                isExpanded: true,
                decoration: _checkoutDecoration(
                  label: 'Metode Pembayaran',
                  icon: Icons.payments_outlined,
                ),
                items: _paymentOptions
                    .map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(
                          _paymentOptionLabel(method),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _paymentMethod = value);
                },
              ),
              const SizedBox(height: 18),
            ] else ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8FD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD8E5F4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.payments_outlined, color: UserTheme.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Metode pembayaran dipilih setelah merchant menyetujui pesanan.',
                        style: TextStyle(
                          color: UserTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            _CheckoutField(
              controller: _addressCtrl,
              label: 'Alamat Tujuan',
              icon: Icons.location_on_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDeliveryLocation,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(
                      _deliveryLatitude == null || _deliveryLongitude == null
                          ? 'Pilih Titik Map'
                          : 'Ubah Titik Map',
                    ),
                  ),
                ),
              ],
            ),
            if (_deliveryLatitude != null && _deliveryLongitude != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_deliveryLatitude!.toStringAsFixed(6)}, ${_deliveryLongitude!.toStringAsFixed(6)}',
                style: const TextStyle(
                  color: UserTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_isLaundry) ...[
              const SizedBox(height: 12),
              _CheckoutField(
                controller: _notesCtrl,
                label: 'Catatan tambahan untuk laundry',
                icon: Icons.notes_outlined,
                maxLines: 3,
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isLaundry
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Bayar',
                          style: TextStyle(
                            color: UserTheme.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Subtotal layanan, tambahan layanan, dan promo dihitung merchant setelah penimbangan.',
                          style: TextStyle(
                            color: UserTheme.muted,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Subtotal',
                                style: TextStyle(
                                  color: UserTheme.text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(formatUserCurrency(_subtotal)),
                          ],
                        ),
                        if (_promoDiscount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Promo dipakai',
                                  style: TextStyle(
                                    color: UserTheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                _selectedCateringItem?.promoDescription ??
                                    'Promo aktif',
                                style: const TextStyle(
                                  color: UserTheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Potongan Promo',
                                  style: TextStyle(
                                    color: UserTheme.muted,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                '- ${formatUserCurrency(_promoDiscount)}',
                                style: const TextStyle(
                                  color: UserTheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Total Penghematan',
                                  style: TextStyle(
                                    color: UserTheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                '+ ${formatUserCurrency(_promoDiscount)}',
                                style: const TextStyle(
                                  color: UserTheme.success,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Total Pesanan',
                                style: TextStyle(
                                  color: UserTheme.text,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              formatUserCurrency(_total),
                              style: const TextStyle(
                                color: UserTheme.primaryDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: UserTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Konfirmasi Pesanan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget lockedItemSummary(MerchantMenuItem item) {
    final unitLabel = item.unit.isNotEmpty ? item.unit : '/kg';
    final hasLaundryPromo =
        _isLaundry && item.hasPromo && (item.promoPrice ?? 0) > 0;
    final selectedAddons = _isLaundry ? _addonsFor(item) : const [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UserTheme.softBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UserTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: UserTheme.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          if ((item.durationLabel.isNotEmpty || item.category.isNotEmpty) &&
              _isLaundry) ...[
            const SizedBox(height: 6),
            Text(
              'Estimasi: ${item.durationLabel.isNotEmpty ? item.durationLabel : item.category}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: UserTheme.muted, fontSize: 13),
            ),
          ] else if (item.category.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.category,
              textAlign: TextAlign.center,
              style: const TextStyle(color: UserTheme.muted, fontSize: 13),
            ),
          ],
          if (!_isLaundry) ...[
            const SizedBox(height: 6),
            Text(
              '${formatUserCurrency(_adjustedCateringPrice(item))} / ${_cateringDays == 20 && item.hasWeekdayPrice ? 'Weekday 30 hari' : 'Full Day'}',
              style: const TextStyle(color: UserTheme.muted),
            ),
            const SizedBox(height: 8),
            _CateringDeliveryInfoBox(item: item, compact: true),
          ] else ...[
            const SizedBox(height: 6),
            if (hasLaundryPromo) ...[
              Text(
                'Referensi harga: ${formatUserCurrency(item.originalPrice ?? item.price)}$unitLabel',
                style: const TextStyle(
                  color: UserTheme.muted,
                  fontSize: 13,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Harga promo: ${formatUserCurrency(item.promoPrice ?? item.price)}$unitLabel',
                style: const TextStyle(
                  color: UserTheme.primaryDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ] else
              Text(
                'Referensi harga: ${formatUserCurrency(item.price)}$unitLabel',
                style: const TextStyle(color: UserTheme.muted, fontSize: 13),
              ),
            if (selectedAddons.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFD8E5F4)),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tambahan dipilih',
                  style: TextStyle(
                    color: UserTheme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ...selectedAddons.map(
                (addon) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: UserTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          addon.name,
                          style: const TextStyle(
                            color: UserTheme.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        _laundryAddonPriceLabel(addon),
                        style: const TextStyle(
                          color: UserTheme.primaryDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget laundryItemPicker() {
    final mainServiceItems = _items.where((item) {
      final normalized = item.name.toLowerCase();
      return normalized.contains('cuci') || item.unit.contains('kg');
    }).toList();
    final addonItems =
        _items.where((item) => !mainServiceItems.contains(item)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih layanan utama dan tambahan service opsional. Merchant akan menimbang dan menetapkan total setelah selesai.',
          style: TextStyle(color: UserTheme.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4D6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE1A3)),
          ),
          child: const Text(
            'Referensi harga ditampilkan per satuan. Total akhir akan ditentukan merchant setelah penimbangan.',
            style: TextStyle(
              color: UserTheme.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Layanan Utama',
          style: TextStyle(
            color: UserTheme.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ...((mainServiceItems.isNotEmpty ? mainServiceItems : _items)
            .map((item) {
          final selected = _selectedLaundryIds.contains(item.id);
          final unitLabel = item.unit.isNotEmpty ? item.unit : '/kg';
          final hasPromo = item.hasPromo && (item.promoPrice ?? 0) > 0;
          return InkWell(
            onTap: () {
              setState(() {
                if (selected) {
                  _selectedLaundryIds.remove(item.id);
                } else {
                  _selectedLaundryIds.add(item.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? UserTheme.softBlue : const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? UserTheme.primary : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: selected ? UserTheme.primary : UserTheme.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: UserTheme.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (hasPromo) ...[
                          Text(
                            'Referensi: ${formatUserCurrency(item.originalPrice ?? item.price)}$unitLabel',
                            style: const TextStyle(
                              color: UserTheme.muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            'Promo: ${formatUserCurrency(item.promoPrice ?? item.price)}$unitLabel',
                            style: const TextStyle(
                              color: UserTheme.primaryDark,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ] else
                          Text(
                            'Referensi: ${formatUserCurrency(item.price)}$unitLabel',
                            style: const TextStyle(color: UserTheme.muted),
                          ),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: UserTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        })),
        if (addonItems.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Tambahan Layanan (opsional)',
            style: TextStyle(
              color: UserTheme.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...addonItems.map((item) {
            final selected = _selectedLaundryIds.contains(item.id);
            final unitLabel = item.unit.isNotEmpty
                ? item.unit
                : item.category.isNotEmpty
                    ? item.category
                    : '/item';
            final hasPromo = item.hasPromo && (item.promoPrice ?? 0) > 0;
            return InkWell(
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedLaundryIds.remove(item.id);
                  } else {
                    _selectedLaundryIds.add(item.id);
                  }
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      selected ? UserTheme.softBlue : const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? UserTheme.primary : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: selected ? UserTheme.primary : UserTheme.muted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: UserTheme.text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (hasPromo) ...[
                            Text(
                              'Referensi: ${formatUserCurrency(item.originalPrice ?? item.price)}$unitLabel',
                              style: const TextStyle(
                                color: UserTheme.muted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            Text(
                              'Promo: ${formatUserCurrency(item.promoPrice ?? item.price)}$unitLabel',
                              style: const TextStyle(
                                color: UserTheme.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ] else
                            Text(
                              'Referensi: ${formatUserCurrency(item.price)}$unitLabel',
                              style: const TextStyle(color: UserTheme.muted),
                            ),
                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: UserTheme.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget cateringItemPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._items.map((item) {
          final selected = _selectedCateringItem?.id == item.id;
          return InkWell(
            onTap: () => setState(() {
              _selectedCateringItem = item;
              if (_cateringDays == 20 && !item.hasWeekdayPrice) {
                _cateringDays = 30;
              }
            }),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? UserTheme.softBlue : const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? UserTheme.primary : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? UserTheme.primary : UserTheme.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.description}\n${formatUserCurrency(_adjustedCateringPrice(item))} / ${_cateringDays == 20 && item.hasWeekdayPrice ? 'Weekday 30 hari' : 'Full Day'}',
                          style: const TextStyle(color: UserTheme.muted),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _ProductInfoChip(
                              icon: Icons.star_rounded,
                              label:
                                  '${item.rating.toStringAsFixed(1)} (${item.reviewCount})',
                              color: const Color(0xFFFFB300),
                            ),
                            _ProductInfoChip(
                              icon: Icons.delivery_dining_rounded,
                              label: _cateringDeliveryFrequency(item),
                              color: UserTheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cateringDeliverySchedule(item),
                          style: const TextStyle(
                            color: UserTheme.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (item.hasWeekdayPrice) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Weekday 30 hari tersedia: ${formatUserCurrency(item.price20Days!)}',
                            style: const TextStyle(
                              color: UserTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        if (_selectedCateringItem?.hasWeekdayPrice ?? false)
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 20, label: Text('Weekday 30 hari')),
              ButtonSegment(value: 30, label: Text('Full Day')),
            ],
            selected: {_cateringDays},
            onSelectionChanged: (value) {
              setState(() => _cateringDays = value.first);
            },
          ),
        const SizedBox(height: 8),
        Text(
          _cateringDays == 20 &&
                  (_selectedCateringItem?.hasWeekdayPrice ?? false)
              ? 'Weekday 30 hari: dikirim Senin-Jumat. Sabtu dan Minggu libur.'
              : 'Full Day: makanan dikirim setiap hari, termasuk Sabtu dan Minggu.',
          style: const TextStyle(color: UserTheme.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _CheckoutField extends StatelessWidget {
  const _CheckoutField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.readOnly = false,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool readOnly;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final multiline = maxLines > 1;
    if (multiline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: UserTheme.muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: UserTheme.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            readOnly: readOnly,
            inputFormatters: inputFormatters,
            textAlign: TextAlign.start,
            textAlignVertical: TextAlignVertical.center,
            decoration: _checkoutDecoration(multiline: true),
          ),
        ],
      );
    }
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      decoration: _checkoutDecoration(
        label: label,
        icon: icon,
      ),
    );
  }
}

class _SheetErrorBanner extends StatelessWidget {
  const _SheetErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC9C9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFD82121),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8F1A1A),
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _laundryAddonPriceLabel(MerchantMenuAddon addon) {
  final unit = addon.unit.trim();
  if (addon.pricingType == 'flat' || unit == 'fixed' || unit.isEmpty) {
    return formatUserCurrency(addon.price);
  }
  return '${formatUserCurrency(addon.price)}$unit';
}

InputDecoration _checkoutDecoration({
  String? label,
  IconData? icon,
  bool multiline = false,
}) {
  return InputDecoration(
    labelText: multiline ? null : label,
    hintText: multiline ? label : null,
    hintStyle: multiline
        ? const TextStyle(
            color: Color(0xFF9AA8BC),
            fontSize: 14,
            height: 1.45,
          )
        : null,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    prefixIcon: multiline ? null : (icon != null ? Icon(icon) : null),
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
    contentPadding: EdgeInsets.symmetric(
      horizontal: multiline ? 20 : 16,
      vertical: multiline ? 28 : 16,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.merchant});

  final UserMerchant merchant;

  @override
  Widget build(BuildContext context) {
    final icon = iconForType(merchant.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            UserImage(
              url: merchant.imageUrl,
              icon: icon,
              height: 230,
              width: double.infinity,
              borderRadius: BorderRadius.circular(24),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: RatingBadge(rating: merchant.rating),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (merchant.type == 'catering')
                    const UserTag(
                      label: 'Catering Premium',
                      color: UserTheme.primary,
                    ),
                  Text(
                    merchant.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: merchant.type == 'catering'
                              ? Colors.white
                              : UserTheme.text,
                          fontWeight: FontWeight.w900,
                          shadows: merchant.type == 'catering'
                              ? [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (merchant.type != 'catering') ...[
          const SizedBox(height: 16),
          Text(
            merchant.name,
            style: const TextStyle(
              color: UserTheme.primaryDark,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          if (merchant.address.trim().isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: UserTheme.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    merchant.address,
                    style: const TextStyle(color: UserTheme.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: merchant.tags.map((tag) => UserTag(label: tag)).toList(),
          ),
        ],
      ],
    );
  }

  IconData iconForType(String type) {
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

class _MerchantSummary extends StatelessWidget {
  const _MerchantSummary({required this.merchant});

  final UserMerchant merchant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [UserTheme.softShadow(opacity: 0.05)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (merchant.openHours.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 18, color: UserTheme.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          merchant.openHours,
                          style: const TextStyle(color: UserTheme.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (merchant.address.trim().isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 18, color: UserTheme.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          merchant.address,
                          style: const TextStyle(color: UserTheme.muted),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemCard extends StatefulWidget {
  const _MenuItemCard({
    required this.type,
    required this.item,
    required this.onOrder,
  });

  final String type;
  final MerchantMenuItem item;
  final VoidCallback onOrder;

  @override
  State<_MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<_MenuItemCard> {
  @override
  Widget build(BuildContext context) {
    if (widget.type == 'laundry') {
      return buildLaundryCard();
    }
    return buildCateringCard();
  }

  Widget buildLaundryCard() {
    final hasPromo = widget.item.hasPromo && (widget.item.promoPrice ?? 0) > 0;
    final percentBadge = _percentagePromoBadge(widget.item);
    return GestureDetector(
      onTap: widget.onOrder,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [UserTheme.softShadow(opacity: 0.05)],
            ),
            child: Row(
              children: [
                UserImage(
                  url: widget.item.imageUrl,
                  icon: Icons.local_laundry_service_rounded,
                  width: 72,
                  height: 72,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: UserTheme.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: UserTheme.muted),
                      ),
                      const SizedBox(height: 8),
                      if (hasPromo) ...[
                        Text(
                          '${formatUserCurrency(widget.item.originalPrice ?? widget.item.price)}${widget.item.unit}',
                          style: const TextStyle(
                            color: UserTheme.muted,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${formatUserCurrency(widget.item.promoPrice ?? widget.item.price)}${widget.item.unit}',
                          style: const TextStyle(
                            color: UserTheme.primaryDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Hemat ${formatUserCurrency(widget.item.promoDiscountAmount ?? 0)}',
                          style: const TextStyle(
                            color: UserTheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ] else
                        Text(
                          '${formatUserCurrency(widget.item.price)}${widget.item.unit}',
                          style: const TextStyle(
                            color: UserTheme.primaryDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: widget.onOrder,
                  style: FilledButton.styleFrom(
                    backgroundColor: UserTheme.primaryDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Pesan'),
                ),
              ],
            ),
          ),
          if (percentBadge != null)
            Positioned(
              top: 10,
              right: 10,
              child: _PromoCornerBadge(label: percentBadge),
            ),
        ],
      ),
    );
  }

  Widget buildCateringCard() {
    final hasPromo = widget.item.hasPromo && (widget.item.promoPrice ?? 0) > 0;
    final percentBadge = _percentagePromoBadge(widget.item);
    final basePrice = hasPromo
        ? (widget.item.promoPrice ?? widget.item.price)
        : widget.item.price;

    return GestureDetector(
      onTap: widget.onOrder,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [UserTheme.softShadow(opacity: 0.05)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserImage(
                  url: widget.item.imageUrl,
                  icon: Icons.restaurant_rounded,
                  width: double.infinity,
                  height: 150,
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: UserTheme.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProductInfoChip(
                      icon: Icons.star_rounded,
                      label:
                          '${widget.item.rating.toStringAsFixed(1)} (${widget.item.reviewCount})',
                      color: const Color(0xFFFFB300),
                    ),
                    _ProductInfoChip(
                      icon: Icons.delivery_dining_rounded,
                      label: _cateringDeliveryFrequency(widget.item),
                      color: UserTheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _CateringDeliveryInfoBox(item: widget.item),
                const SizedBox(height: 8),
                Text(
                  widget.item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: UserTheme.muted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Harga',
                            style: TextStyle(
                              color: UserTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatUserCurrency(basePrice)} / bulan',
                            style: const TextStyle(
                              color: UserTheme.primaryDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          if (hasPromo)
                            Text(
                              '${formatUserCurrency(widget.item.originalPrice ?? widget.item.price)} / bulan',
                              style: const TextStyle(
                                color: UserTheme.muted,
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          if (hasPromo)
                            Text(
                              'Hemat ${formatUserCurrency(widget.item.promoDiscountAmount ?? 0)}',
                              style: const TextStyle(
                                color: UserTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: widget.onOrder,
                      style: FilledButton.styleFrom(
                        backgroundColor: UserTheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
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
          if (percentBadge != null)
            Positioned(
              top: 12,
              right: 12,
              child: _PromoCornerBadge(label: percentBadge),
            ),
        ],
      ),
    );
  }
}

String? _percentagePromoBadge(MerchantMenuItem item) {
  if (!item.hasPromo || (item.promoPrice ?? 0) <= 0) return null;
  if ((item.promoDiscountType ?? '').toLowerCase() != 'percentage') return null;
  final value = item.promoDiscountValue ?? 0;
  if (value <= 0) return null;
  final text = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '-$text%';
}

class _PromoCornerBadge extends StatelessWidget {
  const _PromoCornerBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE11D48),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [UserTheme.softShadow(opacity: 0.08)],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProductInfoChip extends StatelessWidget {
  const _ProductInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CateringDeliveryInfoBox extends StatelessWidget {
  const _CateringDeliveryInfoBox({
    required this.item,
    this.compact = false,
  });

  final MerchantMenuItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EAF4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: UserTheme.softBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: UserTheme.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cateringDeliveryFrequency(item),
                  style: const TextStyle(
                    color: UserTheme.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _cateringDeliverySchedule(item),
                  style: const TextStyle(
                    color: UserTheme.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _cateringDeliveryFrequency(MerchantMenuItem item) {
  return item.mealDeliveryCount >= 2 ? '2x makan/hari' : '1x makan/hari';
}

String _cateringDeliverySchedule(MerchantMenuItem item) {
  if (item.mealDeliveryCount >= 2) {
    final second = (item.deliveryTime2 ?? '').trim().isEmpty
        ? '15:00'
        : item.deliveryTime2!.trim();
    return 'Gelombang pengantaran mulai ${item.deliveryTime1} dan $second.';
  }
  return 'Gelombang pengantaran mulai ${item.deliveryTime1}.';
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type == 'laundry'
            ? 'Layanan akan segera ditambahkan.'
            : 'Menu akan segera ditambahkan.',
        style: const TextStyle(color: UserTheme.muted),
      ),
    );
  }
}

class _ActivePromoSection extends StatelessWidget {
  const _ActivePromoSection({required this.merchant});

  final UserMerchant merchant;

  @override
  Widget build(BuildContext context) {
    final promoItems =
        merchant.menuItems.where((item) => item.hasPromo).toList();
    if (promoItems.isEmpty) return const SizedBox.shrink();
    final topPromo = promoItems.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UserTheme.softBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Promo Aktif',
            style: TextStyle(
              color: UserTheme.primaryDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            topPromo.promoDescription ?? 'Diskon produk aktif',
            style: const TextStyle(color: UserTheme.text),
          ),
          const SizedBox(height: 4),
          Text(
            'Hemat ${formatUserCurrency(topPromo.promoDiscountAmount ?? 0)}',
            style: const TextStyle(
              color: UserTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.merchant,
    required this.reviewState,
    required this.selectedProductId,
    required this.selectedRating,
    required this.controller,
    required this.isSubmitting,
    required this.activeReview,
    required this.onProductChanged,
    required this.onRatingChanged,
    required this.onSubmit,
    required this.onDelete,
  });

  final UserMerchant merchant;
  final UserMerchantReviewState? reviewState;
  final String? selectedProductId;
  final int selectedRating;
  final TextEditingController controller;
  final bool isSubmitting;
  final MerchantReview? activeReview;
  final ValueChanged<String> onProductChanged;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final products = reviewState?.reviewableProducts ?? const [];
    final myReviews =
        reviewState?.myReviews.where((review) => !review.isDeleted).toList() ??
            const <MerchantReview>[];
    final canReview = products.isNotEmpty;
    final remainingEditAttempts = activeReview?.remainingEditAttempts ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: UserSectionHeader(title: 'Ulasan & Rating')),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFFB300)),
                Text(
                  ' ${merchant.rating.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: UserTheme.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  ' (${merchant.reviewCount})',
                  style: const TextStyle(color: UserTheme.muted),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [UserTheme.softShadow(opacity: 0.05)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Beri Rating',
                style: TextStyle(
                  color: UserTheme.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (!canReview)
                const Text(
                  'Anda bisa memberi ulasan setelah pernah membeli produk merchant ini dan pesanan sudah selesai.',
                  style: TextStyle(
                    color: UserTheme.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: selectedProductId,
                  decoration: InputDecoration(
                    labelText: 'Produk yang diulas',
                    filled: true,
                    fillColor: const Color(0xFFF7F9FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: products
                      .map(
                        (product) => DropdownMenuItem(
                          value: product.id,
                          child: Text(product.name),
                        ),
                      )
                      .toList(),
                  onChanged: isSubmitting || products.isEmpty
                      ? null
                      : (value) {
                          if (value != null) onProductChanged(value);
                        },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Belum ada ulasan aktif untuk produk ini.',
                  style: TextStyle(
                    color: UserTheme.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (remainingEditAttempts > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Sisa kesempatan edit: $remainingEditAttempts',
                      style: const TextStyle(
                        color: UserTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Row(
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  return IconButton(
                    onPressed: !canReview || isSubmitting
                        ? null
                        : () => onRatingChanged(rating),
                    icon: Icon(
                      rating <= selectedRating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFFFB300),
                      size: 30,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 4,
                enabled: canReview && !isSubmitting,
                decoration: InputDecoration(
                  hintText: 'Bagikan pengalaman Anda di sini...',
                  filled: true,
                  fillColor: const Color(0xFFF7F9FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting ||
                          !canReview ||
                          (activeReview != null && remainingEditAttempts <= 0)
                      ? null
                      : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: UserTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isSubmitting ? 'Menyimpan...' : 'Kirim Ulasan'),
                ),
              ),
            ],
          ),
        ),
        if (myReviews.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Riwayat Ulasan Anda',
            style: TextStyle(
              color: UserTheme.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...myReviews.map(
              (review) => ReviewCard(review: review, showProductName: true)),
        ],
        const SizedBox(height: 16),
        if (merchant.reviews.isNotEmpty)
          const Text(
            'Ulasan Pengguna',
            style: TextStyle(
              color: UserTheme.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        if (merchant.reviews.isNotEmpty) const SizedBox(height: 10),
        ...merchant.reviews
            .take(3)
            .map((review) => ReviewCard(review: review, showProductName: true)),
        if (merchant.reviews.isNotEmpty)
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MerchantReviewsPage(
                      reviews: merchant.reviews,
                      merchantName: merchant.name,
                    ),
                  ),
                );
              },
              child: const Text(
                'Lihat Semua Ulasan',
                style: TextStyle(
                  color: UserTheme.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
