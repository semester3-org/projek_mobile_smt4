import 'package:flutter/material.dart';

import '../../../data/repositories/merchant_repository.dart';
import '../../../models/catering_package_category.dart';
import '../merchant_ui.dart';

class MerchantPackageCategoriesPanel extends StatefulWidget {
  const MerchantPackageCategoriesPanel({super.key});

  @override
  State<MerchantPackageCategoriesPanel> createState() =>
      _MerchantPackageCategoriesPanelState();
}

class _MerchantPackageCategoriesPanelState
    extends State<MerchantPackageCategoriesPanel> {
  List<CateringPackageCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await MerchantRepository.getPackageCategories();
    if (!mounted) return;
    setState(() {
      _categories = result.data ?? [];
      _loading = false;
    });
  }

  Future<void> _openForm([CateringPackageCategory? category]) async {
    final nameCtrl = TextEditingController(text: category?.categoryName ?? '');
    final descCtrl = TextEditingController(text: category?.description ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? 'Tambah Kategori Paket' : 'Edit Kategori'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama kategori'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Referensi / deskripsi'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    await MerchantRepository.savePackageCategory(
      id: category?.id,
      categoryName: nameCtrl.text.trim(),
      description: descCtrl.text.trim(),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kategori Paket (Referensi)',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: MerchantPalette.text,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Tambah'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Simpan jenis paket untuk dipakai ulang saat membuat produk catering.',
            style: TextStyle(color: MerchantPalette.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_categories.isEmpty)
            const Text(
              'Belum ada kategori. Tambahkan misalnya Paket Hemat, Premium.',
              style: TextStyle(color: MerchantPalette.muted),
            )
          else
            ..._categories.where((c) => c.isActive).map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.categoryName,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: c.description.isEmpty
                        ? null
                        : Text(c.description),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openForm(c),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
