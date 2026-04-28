import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/route_transitions.dart';
import '../../data/repositories/kos_repository.dart';
import '../../models/kos_listing.dart';
import '../../widgets/cards/kos_card.dart';
import '../../widgets/home_search_section.dart';
import '../cafe/cafe_page.dart';
import '../kos/kos_detail_page.dart';
import '../laundry/laundry_page.dart';

/// Beranda: search, filter, kategori, rekomendasi kos — data dari API.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.favoriteKosIds,
    required this.onToggleFavorite,
  });

  final Set<String> favoriteKosIds;
  final void Function(String kosId) onToggleFavorite;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _locationCtrl = TextEditingController();
  int? _maxPrice;
  final Set<String> _selectedFacilities = {};

  // ── State API ─────────────────────────────────────────────────────────────
  List<KosListing> _kosList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchKos();

    // Trigger ulang fetch saat query berubah (debounce sederhana)
    _locationCtrl.addListener(_onSearchChanged);
  }

  DateTime _lastSearch = DateTime.now();

  void _onSearchChanged() {
    final now = DateTime.now();
    _lastSearch = now;
    // Debounce 500 ms
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_lastSearch == now && mounted) _fetchKos();
    });
  }

  @override
  void dispose() {
    _locationCtrl.removeListener(_onSearchChanged);
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── Fetch dari API ────────────────────────────────────────────────────────

  Future<void> _fetchKos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await KosRepository.getAll(
      search:     _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      maxPrice:   _maxPrice,
      facilities: _selectedFacilities.isEmpty ? null : _selectedFacilities.toList(),
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _kosList   = result.data!;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result.error;
        _isLoading    = false;
      });
    }
  }

  // ── Filter sheet ──────────────────────────────────────────────────────────

  Future<void> _openFilter() async {
    await showKosFilterSheet(
      context,
      initialMaxPrice:   _maxPrice,
      initialFacilities: _selectedFacilities,
      onApply: (max, fac) {
        setState(() {
          _maxPrice = max;
          _selectedFacilities
            ..clear()
            ..addAll(fac);
        });
        _fetchKos(); // re-fetch dengan filter baru
      },
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openKosDetail(KosListing kos, String heroTag) {
    Navigator.of(context).push(
      fadeSlideRoute<void>(
        KosDetailPage(
          kos:             kos,
          heroTag:         heroTag,
          isFavorite:      widget.favoriteKosIds.contains(kos.id),
          onToggleFavorite: () => widget.onToggleFavorite(kos.id),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(
        title: const Text('KosFinder'),
        actions: [
          IconButton(
            tooltip: 'Notifikasi',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchKos,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            HomeSearchSection(
              locationController: _locationCtrl,
              onFilterTap:        _openFilter,
              maxPrice:           _maxPrice,
              selectedFacilities: _selectedFacilities,
            ),
            const SizedBox(height: 16),

            // ── Kategori ────────────────────────────────────────────────
            Text(
              'Kategori',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CategoryTile(
                    icon:     Icons.home_work_outlined,
                    label:    'Kos',
                    subtitle: 'Cari & filter',
                    onTap:    _fetchKos,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CategoryTile(
                    icon:     Icons.local_laundry_service_outlined,
                    label:    'Laundry',
                    subtitle: 'Terdekat',
                    onTap: () => Navigator.of(context)
                        .push(fadeSlideRoute<void>(const LaundryPage())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CategoryTile(
                    icon:     Icons.local_cafe_outlined,
                    label:    'Kafe',
                    subtitle: 'Di sekitar',
                    onTap: () => Navigator.of(context)
                        .push(fadeSlideRoute<void>(const CafePage())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Rekomendasi ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rekomendasi untukmu',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: _fetchKos,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Loading / error / list ──────────────────────────────────
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              _ErrorWidget(message: _errorMessage!, onRetry: _fetchKos)
            else if (_kosList.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Tidak ada kos yang cocok.\nUbah filter atau kata kunci.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              )
            else
              ...List.generate(_kosList.length, (i) {
                final kos     = _kosList[i];
                final heroTag = 'kos-hero-${kos.id}-$i';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: KosCard(
                    kos:           kos,
                    heroTagSuffix: '$i',
                    onTap:         () => _openKosDetail(kos, heroTag),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ── Error widget ───────────────────────────────────────────────────────────────

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon:  const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
        ]),
      );
}

// ── Category tile ──────────────────────────────────────────────────────────────

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _down = true),
      onTapUp:     (_) => setState(() => _down = false),
      onTapCancel: ()  => setState(() => _down = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: Colors.grey.shade200),
          boxShadow: _down
              ? []
              : [
                  BoxShadow(
                    color:      AppTheme.primaryGreen.withOpacity(0.08),
                    blurRadius: 12,
                    offset:     const Offset(0, 4),
                  ),
                ],
        ),
        transform: Matrix4.diagonal3Values(
          _down ? 0.98 : 1.0,
          _down ? 0.98 : 1.0,
          1,
        ),
        child: Column(children: [
          Icon(widget.icon, color: AppTheme.primaryGreen, size: 28),
          const SizedBox(height: 8),
          Text(widget.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(widget.subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ]),
      ),
    );
  }
}