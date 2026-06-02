import 'package:flutter/material.dart';

import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/merchant_models.dart';
import '../../merchant_ui.dart';

class MerchantProductReviewsPage extends StatefulWidget {
  const MerchantProductReviewsPage({super.key});

  @override
  State<MerchantProductReviewsPage> createState() =>
      _MerchantProductReviewsPageState();
}

class _MerchantProductReviewsPageState
    extends State<MerchantProductReviewsPage> {
  List<MerchantProductReviewSummary> _items = [];
  bool _loading = true;
  String? _error;
  int _ratingFilter = 0;
  String? _expandedProductId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await MerchantRepository.getProductReviews(
      rating: _ratingFilter == 0 ? null : _ratingFilter,
    );
    if (!mounted) return;
    setState(() {
      _items = result.data ?? [];
      _error = result.error;
      _loading = false;
    });
  }

  void _setFilter(int value) {
    if (_ratingFilter == value) return;
    setState(() => _ratingFilter = value);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return MerchantPage(
      topBar: const MerchantTopBar(
        title: 'Ulasan Produk',
        showAvatar: false,
        showBack: true,
      ),
      onRefresh: _load,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        const Text(
          'Daftar Produk',
          style: TextStyle(
            color: MerchantPalette.text,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Lihat nama user, rating bintang, komentar, dan waktu ulasan. Gunakan filter bintang untuk memisahkan rating baik dan buruk.',
          style: TextStyle(
            color: MerchantPalette.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        _RatingFilterBar(
          selected: _ratingFilter,
          onSelected: _setFilter,
        ),
        const SizedBox(height: 20),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          MerchantCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(color: MerchantPalette.danger),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _load,
                  child: const Text('Muat Ulang'),
                ),
              ],
            ),
          )
        else if (_items.isEmpty)
          const MerchantCard(
            child: Text(
              'Belum ada produk atau ulasan yang sesuai filter.',
              style: TextStyle(color: MerchantPalette.muted),
            ),
          )
        else
          ..._items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ProductReviewCard(
                item: item,
                expanded: _expandedProductId == item.product.id,
                onTap: () {
                  setState(() {
                    _expandedProductId = _expandedProductId == item.product.id
                        ? null
                        : item.product.id;
                  });
                },
              ),
            ),
          ),
        const MerchantBottomSpacer(),
      ],
    );
  }
}

class _RatingFilterBar extends StatelessWidget {
  const _RatingFilterBar({
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
              label: 'Semua',
              value: 0,
              selected: selected,
              onSelected: onSelected),
          for (var rating = 5; rating >= 1; rating--)
            _FilterChip(
              label: '$rating',
              value: rating,
              selected: selected,
              onSelected: onSelected,
              icon: Icons.star_rounded,
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final int value;
  final int selected;
  final ValueChanged<int> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final active = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: active,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : const Color(0xFFFFB300),
              ),
              const SizedBox(width: 4),
            ],
            Text(label),
          ],
        ),
        selectedColor: MerchantPalette.primary,
        labelStyle: TextStyle(
          color: active ? Colors.white : MerchantPalette.text,
          fontWeight: FontWeight.w800,
        ),
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}

class _ProductReviewCard extends StatelessWidget {
  const _ProductReviewCard({
    required this.item,
    required this.expanded,
    required this.onTap,
  });

  final MerchantProductReviewSummary item;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    return MerchantCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  MerchantImage(
                    url: product.imageUrl,
                    icon: Icons.restaurant_rounded,
                    width: 58,
                    height: 58,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MerchantPalette.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFB300),
                              size: 17,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              product.reviewCount > 0
                                  ? 'Rating produk ${product.rating.toStringAsFixed(1)} (${product.reviewCount} ulasan)'
                                  : 'Belum ada rating produk',
                              style: const TextStyle(
                                color: MerchantPalette.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: MerchantPalette.muted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: item.reviews.isEmpty
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tidak ada ulasan sesuai filter.',
                        style: TextStyle(color: MerchantPalette.muted),
                      ),
                    )
                  : Column(
                      children: item.reviews
                          .map(
                            (review) => _ReviewTile(review: review),
                          )
                          .toList(),
                    ),
            ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final MerchantProductReview review;

  @override
  Widget build(BuildContext context) {
    final email = review.reviewerEmail.trim();
    final updated =
        review.updatedAt.difference(review.createdAt).inSeconds.abs() > 2;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewer,
                      style: const TextStyle(
                        color: MerchantPalette.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MerchantPalette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating.round()
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFFFB300),
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${review.rating.toStringAsFixed(0)}/5',
                style: const TextStyle(
                  color: MerchantPalette.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${updated ? 'Diedit' : 'Dibuat'} ${_formatReviewDate(updated ? review.updatedAt : review.createdAt)}',
            style: const TextStyle(
              color: MerchantPalette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: const TextStyle(
              color: MerchantPalette.text,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatReviewDate(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }
}
