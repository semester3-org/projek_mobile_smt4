import 'package:flutter/material.dart';

import '../app/app_theme.dart';

/// Daftar fasilitas statis — sesuai tabel `facilities` di database.
const List<String> kFacilityOptions = [
  'WiFi',
  'AC',
  'Kamar mandi dalam',
  'Dapur bersama',
  'Parkir motor',
  'Laundry',
  'Keamanan 24 jam',
  'Kulkas bersama',
  'Teras rokok',
  'Gazebo',
];

/// Search bar + tombol filter (harga & fasilitas).
class HomeSearchSection extends StatelessWidget {
  const HomeSearchSection({
    super.key,
    required this.locationController,
    required this.onFilterTap,
    this.maxPrice,
    this.selectedFacilities = const {},
  });

  final TextEditingController locationController;
  final VoidCallback onFilterTap;
  final int? maxPrice;
  final Set<String> selectedFacilities;

  @override
  Widget build(BuildContext context) {
    final hasFilter = maxPrice != null || selectedFacilities.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: locationController,
          decoration: const InputDecoration(
            hintText: 'Cari lokasi, area, jalan...',
            prefixIcon: Icon(Icons.search, color: AppTheme.primaryGreen),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onFilterTap,
          icon: const Icon(Icons.tune, size: 20),
          label: Text(hasFilter ? 'Filter aktif' : 'Harga & fasilitas'),
        ),
        if (hasFilter) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (maxPrice != null)
                Chip(
                  label: Text('Maks: Rp ${_formatPrice(maxPrice!)}'),
                  backgroundColor: AppTheme.surfaceTint,
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ...selectedFacilities.map(
                (f) => Chip(
                  label: Text(f),
                  backgroundColor: AppTheme.surfaceTint,
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatPrice(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Bottom sheet filter harga + checklist fasilitas.
Future<void> showKosFilterSheet(
  BuildContext context, {
  required int? initialMaxPrice,
  required Set<String> initialFacilities,
  required void Function(int? maxPrice, Set<String> facilities) onApply,
}) async {
  int? maxPrice = initialMaxPrice;
  final facilities = Set<String>.from(initialFacilities);
  final priceOptions = <int?>[null, 800000, 1000000, 1500000, 2000000];

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewPadding.bottom + 16,
              top: 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filter pencarian',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Text('Rentang harga per bulan',
                    style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: priceOptions.map((p) {
                    final selected = maxPrice == p;
                    final label =
                        p == null ? 'Semua' : '≤ Rp ${_shortRp(p)}';
                    return FilterChip(
                      selected: selected,
                      label: Text(label),
                      onSelected: (_) =>
                          setModalState(() => maxPrice = p),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Fasilitas',
                    style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...kFacilityOptions.map((f) {
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(f),
                    value: facilities.contains(f),
                    onChanged: (v) {
                      setModalState(() {
                        v == true ? facilities.add(f) : facilities.remove(f);
                      });
                    },
                  );
                }),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    onApply(maxPrice, Set<String>.from(facilities));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Terapkan'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

String _shortRp(int v) {
  if (v >= 1000000) return '${v ~/ 1000000}jt';
  return '${v ~/ 1000}rb';
}