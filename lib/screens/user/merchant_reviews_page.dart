import 'package:flutter/material.dart';

import '../../models/user_merchant.dart';
import '../../widgets/review_card.dart';
import 'user_theme.dart';

class MerchantReviewsPage extends StatefulWidget {
  const MerchantReviewsPage({
    super.key,
    required this.reviews,
    required this.merchantName,
  });

  final List<MerchantReview> reviews;
  final String merchantName;

  @override
  State<MerchantReviewsPage> createState() => _MerchantReviewsPageState();
}

class _MerchantReviewsPageState extends State<MerchantReviewsPage> {
  String _selectedRating = 'Semua';

  List<MerchantReview> get _filteredReviews {
    return widget.reviews.where((review) {
      if (_selectedRating == 'Semua') return true;
      final rating = int.tryParse(_selectedRating) ?? 0;
      return review.rating.round() == rating;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReviews;
    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Ulasan ${widget.merchantName}',
          style: const TextStyle(
            color: UserTheme.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Bintang',
              style: TextStyle(
                color: UserTheme.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Semua', '5', '4', '3', '2', '1'].map((value) {
                  final selected = _selectedRating == value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value == 'Semua' ? value : '$value Bintang'),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedRating = value);
                      },
                      selectedColor: UserTheme.primary,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : UserTheme.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Menampilkan ${filtered.length} dari ${widget.reviews.length} ulasan',
              style: const TextStyle(color: UserTheme.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.reviews.isEmpty
                            ? 'Belum ada ulasan untuk merchant ini.'
                            : 'Tidak ada ulasan yang cocok dengan filter.',
                        style: const TextStyle(color: UserTheme.muted),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        return ReviewCard(
                          review: filtered[index],
                          showProductName: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
