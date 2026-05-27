import 'package:flutter/material.dart';

import '../models/user_merchant.dart';
import '../screens/user/user_theme.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.showProductName = false,
  });

  final MerchantReview review;
  final bool showProductName;

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
                      review.reviewer.isEmpty ? 'Pengguna' : review.reviewer,
                      style: const TextStyle(
                        color: UserTheme.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (showProductName && review.productName.isNotEmpty)
                      Text(
                        review.productName,
                        style: const TextStyle(
                          color: UserTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return Icon(
                    star <= review.rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFFFB300),
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (review.comment.isNotEmpty)
            Text(
              review.comment,
              style: const TextStyle(
                color: UserTheme.text,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          if (review.comment.isNotEmpty) const SizedBox(height: 12),
          Text(
            review.timeLabel,
            style: const TextStyle(
              color: UserTheme.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
