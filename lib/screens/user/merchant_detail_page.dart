import 'package:flutter/material.dart';

import '../../data/repositories/user_repository.dart';
import '../../models/order.dart';
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
  bool _submittingReview = false;
  int _selectedRating = 4;
  final _reviewCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _merchant = widget.merchant;
    _load();
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await UserRepository.getMerchantDetail(
      type: widget.merchant.type,
      id: widget.merchant.id,
    );
    if (!mounted) return;
    setState(() {
      _merchant = result.data ?? widget.merchant;
      _loading = false;
    });
  }

  void _openOrder(MerchantMenuItem? item) {
    final selectedItem = item ??
        (_merchant.menuItems.isNotEmpty
            ? _merchant.menuItems.first
            : MerchantMenuItem(
                id: '${_merchant.id}-order',
                name: _merchant.type == 'laundry'
                    ? 'Cuci Lipat (Regular)'
                    : 'Paket Layanan',
                description: _merchant.name,
                price: _merchant.minPrice > 0 ? _merchant.minPrice : 25000,
                imageUrl: _merchant.imageUrl,
              ));
    final serviceFee = _merchant.type == 'cafe' ? 0.0 : 5000.0;
    final order = Order(
      id: 'SR-${_merchant.type.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      merchantName: _merchant.name,
      service: _merchant.type,
      orderDate: DateTime.now(),
      totalAmount: selectedItem.price + serviceFee,
      status: 'pending',
      paymentMethod: 'GOPAY',
      items: [
        OrderItem(
          name: selectedItem.name,
          quantity: 1,
          price: selectedItem.price,
          subtotal: selectedItem.price,
        ),
      ],
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserOrderDetailPage(order: order),
      ),
    );
  }

  Future<void> _submitReview() async {
    final comment = _reviewCtrl.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tulis pengalaman Anda terlebih dahulu')),
      );
      return;
    }

    setState(() => _submittingReview = true);
    final result = await UserRepository.submitMerchantRating(
      type: _merchant.type,
      merchantId: _merchant.id,
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
    final isCafe = _merchant.type == 'cafe';

    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          isCafe ? _merchant.name : 'Detail Merchant',
          style: const TextStyle(
            color: UserTheme.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.favorite_border_rounded),
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
                  if (isCafe) ...[
                    _CafeInfo(merchant: _merchant),
                    const SizedBox(height: 22),
                  ] else
                    _MerchantSummary(merchant: _merchant),
                  const SizedBox(height: 30),
                  UserSectionHeader(
                    title: _merchant.type == 'laundry'
                        ? 'Daftar Layanan'
                        : 'Daftar Menu',
                    actionLabel: _merchant.menuItems.length > 2
                        ? 'Lihat Semua'
                        : null,
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
                          onOrder: () => _openOrder(item),
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
                  if (_merchant.type == 'cafe') _LocationCard(merchant: _merchant),
                  const UserBottomSpacer(),
                ],
              ),
      ),
      bottomNavigationBar: _merchant.type == 'cafe'
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: FilledButton(
                  onPressed: _merchant.isAvailable ? () => _openOrder(null) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: UserTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Pesan Sekarang'),
                ),
              ),
            ),
    );
  }
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
              const Icon(Icons.location_on_outlined, size: 18, color: UserTheme.muted),
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
          Wrap(children: merchant.tags.map((tag) => UserTag(label: tag)).toList()),
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
        return Icons.local_cafe_rounded;
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
                    const Icon(Icons.location_on_outlined, size: 18, color: UserTheme.muted),
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
          const SizedBox(width: 14),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: UserTheme.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text('Hubungi'),
          ),
        ],
      ),
    );
  }
}

class _CafeInfo extends StatelessWidget {
  const _CafeInfo({required this.merchant});

  final UserMerchant merchant;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniInfoCard(
                icon: Icons.schedule_rounded,
                label: 'Jam Buka',
                value: merchant.openHours,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: _MiniInfoCard(
                icon: Icons.wifi_rounded,
                label: 'Fasilitas Utama',
                value: 'High Speed\nWi-Fi',
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        UserSectionHeader(title: 'Informasi Kafe'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [UserTheme.softShadow(opacity: 0.05)],
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.article_outlined,
                title: 'Tentang Kami',
                body: merchant.description,
              ),
              Divider(color: Colors.blueGrey.shade50, height: 28),
              _InfoRow(
                icon: Icons.check_circle_outline_rounded,
                title: 'Fasilitas Lengkap',
                body: merchant.tags.join('  -  '),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  const _MiniInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [UserTheme.softShadow(opacity: 0.04)],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: UserTheme.softBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: UserTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: UserTheme.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: UserTheme.text,
                    fontWeight: FontWeight.w800,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: UserTheme.primaryDark),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: UserTheme.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(
                  color: UserTheme.muted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.type,
    required this.item,
    required this.onOrder,
  });

  final String type;
  final MerchantMenuItem item;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
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
            url: item.imageUrl,
            icon: type == 'laundry'
                ? Icons.local_laundry_service_rounded
                : Icons.restaurant_rounded,
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
                  item.name,
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
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: UserTheme.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  formatUserCurrency(item.price),
                  style: const TextStyle(
                    color: UserTheme.primaryDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (type == 'laundry') ...[
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onOrder,
              style: FilledButton.styleFrom(
                backgroundColor: UserTheme.primaryDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Pesan'),
            ),
          ],
        ],
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.merchant});

  final UserMerchant merchant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UserSectionHeader(title: 'Lokasi & Kontak'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [UserTheme.softShadow(opacity: 0.04)],
          ),
          child: Column(
            children: [
              Container(
                height: 132,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3F8),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Buka di Maps'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: UserTheme.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: UserTheme.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      merchant.phone,
                      style: const TextStyle(color: UserTheme.muted),
                    ),
                  ),
                  const Icon(Icons.mail_outline, size: 16, color: UserTheme.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      merchant.email,
                      style: const TextStyle(color: UserTheme.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
