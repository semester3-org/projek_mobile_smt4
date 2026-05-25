import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../auth/roles.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/user_merchant.dart';
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
  final _reviewCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _merchant = widget.merchant;
    _load();
    _loadFavorite();
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final merchantId = widget.merchant.id.isNotEmpty ? widget.merchant.id : (widget.merchant.placeId.isNotEmpty ? widget.merchant.placeId : widget.merchant.merchantId);
    
    final result = await UserRepository.getMerchantDetail(
      type: widget.merchant.type,
      id: merchantId,
    );
    if (!mounted) return;
    setState(() {
      _merchant = result.data ?? widget.merchant;
      _loading = false;
    });
  }

  Future<void> _loadFavorite() async {
    final favorite = await UserRepository.isMerchantFavorite(
      type: widget.merchant.type,
      merchantId: widget.merchant.id,
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

  Future<void> _openOrder(MerchantMenuItem? item) async {
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
      ),
    );

    if (draft == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mengirim pesanan ke merchant...')),
    );

    final result = await UserRepository.createOrder(
      merchant: _merchant,
      items: draft.items,
      quantities: draft.quantities,
      deliveryAddress: draft.deliveryAddress,
      estimatedTime: draft.estimatedTime,
      paymentMethod: draft.paymentMethod,
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
    final result = await UserRepository.submitMerchantRating(
      type: _merchant.type,
      merchantId:
          _merchant.merchantId.isNotEmpty ? _merchant.merchantId : _merchant.id,
      rating: _selectedRating,
      comment: comment,
    );
    if (!mounted) return;

    final newReview = MerchantReview(
      reviewer: 'Anda',
      rating: _selectedRating.toDouble(),
      comment: comment,
      timeLabel: 'Baru saja',
    );
    final newCount = _merchant.reviewCount + 1;
    final newRating =
        ((_merchant.rating * _merchant.reviewCount) + _selectedRating) /
            newCount;

    setState(() {
      _merchant = _merchant.copyWith(
        rating: newRating,
        reviewCount: newCount,
        reviews: [newReview, ..._merchant.reviews],
      );
      _reviewCtrl.clear();
      _submittingReview = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isSuccess
            ? 'Ulasan berhasil dikirim'
            : 'Ulasan tersimpan di perangkat. ${result.error ?? ''}'.trim()),
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
                            _openOrder(item);
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _ReviewSection(
                    merchant: _merchant,
                    selectedRating: _selectedRating,
                    controller: _reviewCtrl,
                    isSubmitting: _submittingReview,
                    onRatingChanged: (rating) {
                      setState(() => _selectedRating = rating);
                    },
                    onSubmit: _submitReview,
                  ),
                  const SizedBox(height: 22),
                  const UserBottomSpacer(),
                ],
              ),
      ),
      bottomNavigationBar: null,
    );
  }
}
class _OrderDraft {
  const _OrderDraft({
    required this.items,
    required this.quantities,
    required this.deliveryAddress,
    required this.estimatedTime,
    required this.paymentMethod,
    required this.customerName,
    required this.customerPhone,
    required this.notes,
  });

  final List<MerchantMenuItem> items;
  final Map<String, int> quantities;
  final String deliveryAddress;
  final String estimatedTime;
  final String paymentMethod;
  final String customerName;
  final String customerPhone;
  final String notes;
}

class _OrderCheckoutSheet extends StatefulWidget {
  const _OrderCheckoutSheet({
    required this.merchant,
    this.initialItem,
  });

  final UserMerchant merchant;
  final MerchantMenuItem? initialItem;

  @override
  State<_OrderCheckoutSheet> createState() => _OrderCheckoutSheetState();
}

class _OrderCheckoutSheetState extends State<_OrderCheckoutSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Map<String, int> _quantities = {};

  MerchantMenuItem? _selectedCateringItem;
  String _paymentMethod = 'Cash on Delivery';
  int _cateringDays = 20;
  bool _didLoadProfile = false;

  bool get _isLaundry => widget.merchant.type == 'laundry';

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
    final initial = widget.initialItem ?? _items.first;
    if (_isLaundry) {
      _quantities[initial.id] = 1;
    } else {
      _selectedCateringItem = initial;
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
    });
  }

  double get _total {
    if (_isLaundry) {
      return _items.fold<double>(0, (sum, item) {
        return sum + ((_quantities[item.id] ?? 0) * item.price);
      });
    }
    return _selectedCateringItem?.price ?? 0;
  }

  List<MerchantMenuItem> get _selectedItems {
    if (_isLaundry) {
      return _items.where((item) => (_quantities[item.id] ?? 0) > 0).toList();
    }
    final selected = _selectedCateringItem;
    return selected == null ? const [] : [selected];
  }

  void _submit() {
    final selectedItems = _selectedItems;
    if (selectedItems.isEmpty || _total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu item pesanan')),
      );
      return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat tujuan wajib diisi')),
      );
      return;
    }

    final cateringNote = widget.merchant.type == 'catering'
        ? 'Paket $_cateringDays hari: ${_cateringDays == 20 ? 'Senin-Jumat, Sabtu/Minggu tidak dikirim' : 'Dikirim setiap hari selama 30 hari'}.'
        : '';
    final notes = [
      if (cateringNote.isNotEmpty) cateringNote,
      if (_notesCtrl.text.trim().isNotEmpty) _notesCtrl.text.trim(),
    ].join('\n');

    Navigator.of(context).pop(
      _OrderDraft(
        items: selectedItems,
        quantities: {
          for (final item in selectedItems)
            item.id: _isLaundry ? (_quantities[item.id] ?? 1) : 1,
        },
        deliveryAddress: _addressCtrl.text.trim(),
        estimatedTime: _isLaundry
            ? (widget.merchant.hasDistanceEstimate &&
                    widget.merchant.eta.isNotEmpty
                ? widget.merchant.eta
                : 'Estimasi ditentukan merchant')
            : 'Paket $_cateringDays hari',
        paymentMethod: _paymentMethod,
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
            if (_isLaundry) _LaundryItemPicker() else _CateringItemPicker(),
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
            _CheckoutField(
              controller: _addressCtrl,
              label: 'Alamat Tujuan',
              icon: Icons.location_on_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: _checkoutDecoration(
                label: 'Metode Pembayaran',
                icon: Icons.payments_outlined,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Cash on Delivery',
                  child: Text('Cash on Delivery'),
                ),
                DropdownMenuItem(
                  value: 'Transfer Bank',
                  child: Text('Transfer Bank'),
                ),
                DropdownMenuItem(
                  value: 'E-Wallet',
                  child: Text('E-Wallet'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _paymentMethod = value);
              },
            ),
            const SizedBox(height: 12),
            _CheckoutField(
              controller: _notesCtrl,
              label: _isLaundry
                  ? 'Catatan tambahan untuk laundry'
                  : 'Catatan tambahan untuk catering',
              icon: Icons.notes_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
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

  Widget _LaundryItemPicker() {
    return Column(
      children: _items.map((item) {
        final quantity = _quantities[item.id] ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
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
                      [
                        formatUserCurrency(item.price),
                        if (item.unit.isNotEmpty) item.unit,
                      ].join(''),
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
              _QuantityStepper(
                value: quantity,
                onChanged: (value) {
                  setState(() => _quantities[item.id] = value);
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _CateringItemPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._items.map((item) {
          return RadioListTile<MerchantMenuItem>(
            value: item,
            groupValue: _selectedCateringItem,
            onChanged: (value) => setState(() => _selectedCateringItem = value),
            contentPadding: EdgeInsets.zero,
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${item.description}\n${formatUserCurrency(item.price)}${item.unit}',
            ),
          );
        }),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 20, label: Text('20 hari')),
            ButtonSegment(value: 30, label: Text('30 hari')),
          ],
          selected: {_cateringDays},
          onSelectionChanged: (value) {
            setState(() => _cateringDays = value.first);
          },
        ),
        const SizedBox(height: 8),
        Text(
          _cateringDays == 20
              ? 'Paket 20 hari dikirim Senin sampai Jumat.'
              : 'Paket 30 hari dikirim penuh setiap hari.',
          style: const TextStyle(color: UserTheme.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: value <= 0 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        SizedBox(
          width: 28,
          child: Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline_rounded),
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
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _checkoutDecoration(label: label, icon: icon),
    );
  }
}

InputDecoration _checkoutDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
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
                                    color: Colors.black.withOpacity(0.45),
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
              children:
                  merchant.tags.map((tag) => UserTag(label: tag)).toList()),
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
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB300)),
                    const SizedBox(width: 6),
                    Text(
                      '${merchant.rating.toStringAsFixed(1)} (${merchant.reviewCount} Ulasan)',
                      style: const TextStyle(
                        color: UserTheme.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
  String _selectedDuration = '30';

  @override
  Widget build(BuildContext context) {
    if (widget.type == 'laundry') {
      return _buildLaundryCard();
    }
    return _buildCateringCard();
  }

  Widget _buildLaundryCard() {
    return Container(
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
    );
  }

  Widget _buildCateringCard() {
    // Calculate price based on duration
    final basePrice = widget.item.price;
    final durationDays = int.tryParse(_selectedDuration) ?? 30;
    final adjustedPrice = (basePrice / 30 * durationDays);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [UserTheme.softShadow(opacity: 0.05)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          UserImage(
            url: widget.item.imageUrl,
            icon: Icons.restaurant_rounded,
            width: double.infinity,
            height: 180,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            widget.item.name,
            style: const TextStyle(
              color: UserTheme.text,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            widget.item.description,
            style: const TextStyle(
              color: UserTheme.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Duration selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: UserTheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pilih Durasi:',
                    style: TextStyle(
                      color: UserTheme.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildDurationButton('20', 'hari'),
                const SizedBox(width: 8),
                _buildDurationButton('30', 'hari'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Price and button
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
                      formatUserCurrency(adjustedPrice),
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
    );
  }

  Widget _buildDurationButton(String days, String label) {
    final isSelected = _selectedDuration == days;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedDuration = days);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? UserTheme.primary : Colors.white,
            border: Border.all(
              color: isSelected ? UserTheme.primary : UserTheme.muted.withOpacity(0.2),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$days $label',
              style: TextStyle(
                color: isSelected ? Colors.white : UserTheme.text,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
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
    required this.selectedRating,
    required this.controller,
    required this.isSubmitting,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  final UserMerchant merchant;
  final int selectedRating;
  final TextEditingController controller;
  final bool isSubmitting;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 10),
              Row(
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  return IconButton(
                    onPressed: () => onRatingChanged(rating),
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
                  onPressed: isSubmitting ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: UserTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isSubmitting ? 'Mengirim...' : 'Kirim Ulasan'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    Text(
                      review.timeLabel,
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
            review.comment,
            style: const TextStyle(
              color: UserTheme.text,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
