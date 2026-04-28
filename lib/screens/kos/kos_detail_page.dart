import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/kos_listing.dart';

/// Detail kos: carousel foto, info, booking / hubungi pemilik.
class KosDetailPage extends StatefulWidget {
  const KosDetailPage({
    super.key,
    required this.kos,
    required this.heroTag,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final KosListing kos;
  final String heroTag;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  State<KosDetailPage> createState() => _KosDetailPageState();
}

class _KosDetailPageState extends State<KosDetailPage> {
  late final PageController _pageController;
  int _page = 0;
  late bool _favorite;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _favorite = widget.isFavorite;
  }

  @override
  void didUpdateWidget(covariant KosDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _favorite = widget.isFavorite;
    }
  }

  void _onFavoriteTap() {
    widget.onToggleFavorite();
    setState(() => _favorite = !_favorite);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatRupiah(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf/bulan';
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.kos.imageUrls;

    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                tooltip: 'Favorit',
                onPressed: _onFavoriteTap,
                icon: Icon(
                  _favorite ? Icons.favorite : Icons.favorite_border,
                  color: _favorite ? Colors.redAccent : null,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: urls.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, index) {
                      final url = urls[index];
                      final child = Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.surfaceTint,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      );
                      // Hero hanya pada gambar pertama agar transisi konsisten
                      if (index == 0) {
                        return Hero(tag: widget.heroTag, child: child);
                      }
                      return child;
                    },
                  ),
                  // Indikator dot carousel
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(urls.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : Colors.white.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.kos.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(
                        widget.kos.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.place_outlined, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.kos.location,
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _formatRupiah(widget.kos.pricePerMonth),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Fasilitas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.kos.facilities
                        .map(
                          (f) => Chip(
                            label: Text(f),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Deskripsi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.kos.description,
                    style: TextStyle(
                      height: 1.45,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Hubungi: ${widget.kos.ownerContact}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.phone_outlined),
                  label: const Text('Hubungi pemilik'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Booking (UI demo — tanpa backend)'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.event_available_rounded),
                  label: const Text('Booking'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
