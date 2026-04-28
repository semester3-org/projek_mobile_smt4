import 'package:flutter/material.dart';

import '../../models/laundry_place.dart';
import '../../app/app_theme.dart';

/// Kartu laundry: foto, nama, rating, jarak.
class LaundryCard extends StatefulWidget {
  const LaundryCard({
    super.key,
    required this.place,
    this.onTap,
  });

  final LaundryPlace place;
  final VoidCallback? onTap;

  @override
  State<LaundryCard> createState() => _LaundryCardState();
}

class _LaundryCardState extends State<LaundryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: EdgeInsets.only(bottom: _hover ? 6 : 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _hover = v),
          borderRadius: BorderRadius.circular(16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                  child: SizedBox(
                    width: 108,
                    height: 108,
                    child: _LaundryThumb(url: widget.place.imageUrl),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.place.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.place.address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Colors.amber.shade700,
                            ),
                            Text(
                              widget.place.rating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.near_me_outlined,
                              size: 16,
                              color: AppTheme.primaryGreen,
                            ),
                            Text(
                              '${widget.place.distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.place.openHours,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LaundryThumb extends StatelessWidget {
  const _LaundryThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppTheme.surfaceTint,
        child: const Icon(Icons.local_laundry_service, color: AppTheme.primaryGreen),
      ),
    );
  }
}
