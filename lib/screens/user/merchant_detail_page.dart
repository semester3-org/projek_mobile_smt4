import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../core/payment_methods.dart';
import '../../core/user_location_service.dart';
import '../../auth/roles.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/user_merchant.dart';
import '../../widgets/location_picker_page.dart';
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

  Future<void> _load({bool silent = false}) async {
    final coords = await UserLocationService.current();
    final result = await UserRepository.getMerchantDetail(
      type: widget.merchant.type,
      id: _merchantId,
      latitude: coords?.latitude,
      longitude: coords?.longitude,
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
    );
  }

  Future<void> _openOrder(
    MerchantMenuItem? item, {
    int? initialCateringDays,
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

    setState(() => _submittingReview = true);
    final isUpdate = _activeReviewFor(productId) != null;
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
      final coords = await UserLocationService.current();
      final refreshed = await UserRepository.getMerchantDetail(
        type: _merchant.type,
        id: _merchantId,
        latitude: coords?.latitude,
        longitude: coords?.longitude,
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
      final coords = await UserLocationService.current();
      final refreshed = await UserRepository.getMerchantDetail(
        type: _merchant.type,
        id: _merchantId,
        latitude: coords?.latitude,
        longitude: coords?.longitude,
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
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  children: [
                    _HeaderCard(merchant: _merchant),
                    const SizedBox(height: 22),
                    _MerchantSummary(merchant: _merchant),
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
  });

  final MerchantMenuItem item;
  final int? cateringDays;
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

  bool get _isCatering => widget.merchant.type == 'catering';
  bool get _hasWeekdayPackage => widget.item.hasWeekdayPrice;

  double get _price {
    if (!_isCatering) return widget.item.price;
    return widget.item.cateringPriceForDays(_cateringDays);
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
            const SizedBox(height: 14),
            Text(
              '${formatUserCurrency(_price)}${_isCatering ? '' : widget.item.unit}',
              style: const TextStyle(
                color: UserTheme.primaryDark,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (_isCatering) ...[
              const SizedBox(height: 16),
              if (_hasWeekdayPackage)
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 20, label: Text('Weekday')),
                    ButtonSegment(value: 30, label: Text('Full Day')),
                  ],
                  selected: {_cateringDays},
                  onSelectionChanged: (value) {
                    setState(() => _cateringDays = value.first);
                  },
                ),
              const SizedBox(height: 8),
              Text(
                _hasWeekdayPackage && _cateringDays == 20
                    ? 'Weekday: dikirim Senin-Jumat. Sabtu dan Minggu libur.'
                    : 'Full Day: makanan dikirim setiap hari, termasuk Sabtu dan Minggu.',
                style: const TextStyle(color: UserTheme.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  _ProductDetailResult(
                    item: widget.item,
                    cateringDays: _isCatering ? _cateringDays : null,
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
}

class _OrderCheckoutSheet extends StatefulWidget {
  const _OrderCheckoutSheet({
    required this.merchant,
    this.initialItem,
    this.initialCateringDays,
  });

  final UserMerchant merchant;
  final MerchantMenuItem? initialItem;
  final int? initialCateringDays;

  @override
  State<_OrderCheckoutSheet> createState() => _OrderCheckoutSheetState();
}

class _OrderCheckoutSheetState extends State<_OrderCheckoutSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Set<String> _selectedLaundryIds = {};

  MerchantMenuItem? _selectedCateringItem;
  String _paymentMethod = 'cod';
  int _cateringDays = 30;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  bool _didLoadProfile = false;

  bool get _isLaundry => widget.merchant.type == 'laundry';

  List<String> get _paymentOptions =>
      PaymentMethodHelper.checkoutOptionKeys(isLaundry: _isLaundry);

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
    _paymentMethod = _isLaundry ? 'cod' : 'gopay';
    _cateringDays = widget.initialCateringDays ?? 30;
    final initial = widget.initialItem ?? _items.first;
    if (_isLaundry) {
      _selectedLaundryIds.add(initial.id);
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
    return _adjustedCateringPrice(_selectedCateringItem);
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
    });
  }

  String _laundryServiceEstimateFor(List<MerchantMenuItem> items) {
    if (items.isEmpty) return 'Estimasi layanan ditentukan merchant';
    final category = items.first.category.trim();
    if (category.isEmpty) return 'Estimasi layanan ditentukan merchant';
    return category;
  }

  void _submit() {
    final selectedItems = _selectedItems;
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu layanan laundry')),
      );
      return;
    }
    if (!_isLaundry && _total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih paket catering terlebih dahulu')),
      );
      return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat tujuan wajib diisi')),
      );
      return;
    }

    final selectedCatering = _selectedCateringItem;
    final useWeekday = widget.merchant.type == 'catering' &&
        _cateringDays == 20 &&
        (selectedCatering?.hasWeekdayPrice ?? false);
    final cateringNote = widget.merchant.type == 'catering'
        ? (useWeekday
            ? 'Paket Weekday: dikirim Senin-Jumat, Sabtu/Minggu tidak dikirim.'
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
            : (useWeekday ? 'Paket Weekday' : 'Paket Full Day'),
        paymentMethod: _paymentMethod,
        subscriptionDays: _isLaundry ? null : (useWeekday ? 20 : 30),
        customerName: _nameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        notes: notes,
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
            if (widget.initialItem != null) ...[
              _lockedItemSummary(widget.initialItem!),
              if (!_isLaundry && widget.initialItem!.hasWeekdayPrice) ...[
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 20, label: Text('Weekday')),
                    ButtonSegment(value: 30, label: Text('Full Day')),
                  ],
                  selected: {_cateringDays},
                  onSelectionChanged: (value) {
                    setState(() => _cateringDays = value.first);
                  },
                ),
              ],
            ] else if (_isLaundry)
              _laundryItemPicker()
            else
              _cateringItemPicker(),
            const SizedBox(height: 18),
            _CheckoutField(
              controller: _nameCtrl,
              label: 'Nama Penerima',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 12),
            _CheckoutField(
              controller: _phoneCtrl,
              label: 'Nomor Telepon',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paymentOptions.contains(_paymentMethod)
                  ? _paymentMethod
                  : _paymentOptions.first,
              decoration: _checkoutDecoration(
                label: 'Metode Pembayaran',
                icon: Icons.payments_outlined,
              ),
              items: _paymentOptions
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(
                        '${PaymentMethodHelper.getDisplayName(method)} (${PaymentMethodHelper.getCategory(method)})',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _paymentMethod = value);
              },
            ),
            const SizedBox(height: 18),
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
                          'Ditimbang merchant setelah cucian selesai. Harga per kg ditampilkan sebagai referensi saat jemput ke kos.',
                          style: TextStyle(
                            color: UserTheme.muted,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    )
                  : Row(
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

  Widget _lockedItemSummary(MerchantMenuItem item) {
    final unitLabel = item.unit.isNotEmpty ? item.unit : '/kg';
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
          if (item.category.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Estimasi: ${item.category}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: UserTheme.muted, fontSize: 13),
            ),
          ],
          if (!_isLaundry) ...[
            const SizedBox(height: 6),
            Text(
              '${formatUserCurrency(_adjustedCateringPrice(item))} / ${_cateringDays == 20 && item.hasWeekdayPrice ? 'Weekday' : 'Full Day'}',
              style: const TextStyle(color: UserTheme.muted),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Referensi harga: ${formatUserCurrency(item.price)}$unitLabel',
              style: const TextStyle(color: UserTheme.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _laundryItemPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih layanan laundry (tanpa jumlah kg). Merchant akan menimbang dan menetapkan total setelah selesai.',
          style: TextStyle(color: UserTheme.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 10),
        ..._items.map((item) {
          final selected = _selectedLaundryIds.contains(item.id);
          final unitLabel = item.unit.isNotEmpty ? item.unit : '/kg';
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
    );
  }

  Widget _cateringItemPicker() {
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
                          '${item.description}\n${formatUserCurrency(_adjustedCateringPrice(item))} / ${_cateringDays == 20 && item.hasWeekdayPrice ? 'Weekday' : 'Full Day'}',
                          style: const TextStyle(color: UserTheme.muted),
                        ),
                        if (item.hasWeekdayPrice) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Weekday tersedia: ${formatUserCurrency(item.price20Days!)}',
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
              ButtonSegment(value: 20, label: Text('Weekday')),
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
              ? 'Weekday: dikirim Senin-Jumat. Sabtu dan Minggu libur.'
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
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final multiline = maxLines > 1;
    if (multiline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
            textAlign: TextAlign.center,
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
      decoration: _checkoutDecoration(
        label: label,
        icon: icon,
      ),
    );
  }
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
    final icon = _iconForType(merchant.type);
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: merchant.tags.map((tag) => UserTag(label: tag)).toList(),
          ),
        ],
      ],
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
      return _buildLaundryCard();
    }
    return _buildCateringCard();
  }

  Widget _buildLaundryCard() {
    return GestureDetector(
      onTap: widget.onOrder,
      child: Container(
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
              width: 84,
              height: 84,
              borderRadius: BorderRadius.circular(14),
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
    );
  }

  Widget _buildCateringCard() {
    final basePrice = widget.item.price;

    return GestureDetector(
      onTap: widget.onOrder,
      child: Container(
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
              height: 180,
              borderRadius: BorderRadius.circular(16),
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
    );
  }
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
    final myReviews = reviewState?.myReviews ?? const <MerchantReview>[];
    final canReview = products.isNotEmpty;

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
                Text(
                  activeReview == null
                      ? 'Belum ada ulasan aktif untuk produk ini.'
                      : 'Ulasan produk ini sudah ada. Anda bisa mengedit atau menghapusnya.',
                  style: const TextStyle(
                    color: UserTheme.muted,
                    fontSize: 12,
                    height: 1.35,
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
                  onPressed: isSubmitting || !canReview ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: UserTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isSubmitting
                      ? 'Menyimpan...'
                      : activeReview == null
                          ? 'Kirim Ulasan'
                          : 'Update Ulasan'),
                ),
              ),
              if (activeReview != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isSubmitting ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Hapus Ulasan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
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
          ...myReviews.map((review) => _ReviewCard(review: review)),
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
        ...merchant.reviews.map((review) => _ReviewCard(review: review)),
        if (merchant.reviews.isNotEmpty)
          Center(
            child: TextButton(
              onPressed: () {},
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final MerchantReview review;

  @override
  Widget build(BuildContext context) {
    final deleted = review.isDeleted;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: deleted ? const Color(0xFFF4F5F7) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [UserTheme.softShadow(opacity: 0.04)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: UserTheme.softBlue,
                child: Text(
                  review.reviewer.isEmpty
                      ? 'U'
                      : review.reviewer[0].toUpperCase(),
                  style: const TextStyle(
                    color: UserTheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewer,
                      style: const TextStyle(
                        color: UserTheme.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (review.productName.isNotEmpty)
                      Text(
                        review.productName,
                        style: const TextStyle(
                          color: UserTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text(
                      _reviewTimeText(review),
                      style: const TextStyle(
                        color: UserTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating.round()
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFFFB300),
                    size: 17,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            deleted ? 'Ulasan ini sudah dihapus.' : review.comment,
            style: TextStyle(
              color: deleted ? UserTheme.muted : UserTheme.text,
              height: 1.45,
              fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _reviewTimeText(MerchantReview review) {
    if (review.isDeleted && review.deletedAt.isNotEmpty) {
      return 'Dihapus ${_formatReviewDate(review.deletedAt)}';
    }
    if (review.updatedAt.isNotEmpty &&
        review.createdAt.isNotEmpty &&
        review.updatedAt != review.createdAt) {
      return 'Diedit ${_formatReviewDate(review.updatedAt)}';
    }
    if (review.createdAt.isNotEmpty) {
      return 'Dikirim ${_formatReviewDate(review.createdAt)}';
    }
    return review.timeLabel;
  }

  String _formatReviewDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
