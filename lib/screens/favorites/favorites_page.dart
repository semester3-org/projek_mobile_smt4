import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/route_transitions.dart';
import '../../data/repositories/kos_repository.dart';
import '../../models/kos_listing.dart';
import '../../widgets/cards/kos_card.dart';
import '../kos/kos_detail_page.dart';

/// Kos yang ditandai favorit — data di-fetch dari API berdasarkan ID favorit.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    required this.favoriteKosIds,
    required this.onToggleFavorite,
  });

  final Set<String> favoriteKosIds;
  final void Function(String kosId) onToggleFavorite;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<KosListing> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // Dipanggil ulang saat favoriteKosIds berubah dari luar
  @override
  void didUpdateWidget(covariant FavoritesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favoriteKosIds != widget.favoriteKosIds) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (widget.favoriteKosIds.isEmpty) {
      setState(() { _items = []; _isLoading = false; _error = null; });
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    // Fetch semua kos, lalu filter yang ID-nya ada di favoriteKosIds.
    // Alternatif efisien: fetch satu per satu dengan KosRepository.getById(),
    // tapi untuk jumlah favorit yang kecil, cara ini cukup.
    final result = await KosRepository.getAll();
    if (!mounted) return;

    if (result.isSuccess) {
      final filtered = result.data!
          .where((k) => widget.favoriteKosIds.contains(k.id))
          .toList();
      setState(() { _items = filtered; _isLoading = false; });
    } else {
      setState(() { _error = result.error; _isLoading = false; });
    }
  }

  void _openDetail(KosListing kos, String heroTag) {
    Navigator.of(context).push(
      fadeSlideRoute<void>(
        KosDetailPage(
          kos:              kos,
          heroTag:          heroTag,
          isFavorite:       widget.favoriteKosIds.contains(kos.id),
          onToggleFavorite: () => widget.onToggleFavorite(kos.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(title: const Text('Favorit')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _fetch,
              icon:  const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ]),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.favorite_border, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Belum ada kos favorit',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tambahkan dari halaman detail kos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final kos     = _items[i];
        final heroTag = 'kos-hero-${kos.id}-fav-$i';
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: KosCard(
            kos:           kos,
            heroTagSuffix: 'fav-$i',
            onTap:         () => _openDetail(kos, heroTag),
          ),
        );
      },
    );
  }
}