import 'package:flutter/material.dart';

import '../../../data/repositories/merchant_repository.dart';
import '../../../models/laundry_service_estimate.dart';
import '../merchant_ui.dart';

class MerchantLaundryEstimatesPanel extends StatefulWidget {
  const MerchantLaundryEstimatesPanel({super.key});

  @override
  State<MerchantLaundryEstimatesPanel> createState() =>
      _MerchantLaundryEstimatesPanelState();
}

class _MerchantLaundryEstimatesPanelState
    extends State<MerchantLaundryEstimatesPanel> {
  List<LaundryServiceEstimate> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await MerchantRepository.getLaundryEstimates();
    if (!mounted) return;
    setState(() {
      _items = result.data ?? [];
      _loading = false;
    });
  }

  Future<void> _openForm([LaundryServiceEstimate? item]) async {
    final nameCtrl = TextEditingController(text: item?.serviceName ?? '');
    final minCtrl = TextEditingController(
      text: item == null ? '' : '${item.minHours}',
    );
    final maxCtrl = TextEditingController(
      text: item == null ? '' : '${item.maxHours}',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Tambah Estimasi' : 'Edit Estimasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama layanan',
                hintText: 'Cuci Express',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Min jam',
                hintText: '1',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: maxCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max jam',
                hintText: '2 atau 48 untuk 1-2 hari',
              ),
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
    await MerchantRepository.saveLaundryEstimate(
      id: item?.id,
      serviceName: nameCtrl.text.trim(),
      minHours: int.tryParse(minCtrl.text) ?? 1,
      maxHours: int.tryParse(maxCtrl.text) ?? 24,
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
                  'Estimasi Waktu Layanan',
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
            'Contoh: Express 1-2 jam, Regular 24-48 jam (1-2 hari).',
            style: TextStyle(color: MerchantPalette.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_items.isEmpty)
            const Text(
              'Belum ada estimasi. User akan melihat estimasi default.',
              style: TextStyle(color: MerchantPalette.muted),
            )
          else
            ..._items.where((e) => e.isActive).map(
                  (e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.serviceName,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(e.estimateLabel.isNotEmpty
                        ? e.estimateLabel
                        : '${e.minHours}-${e.maxHours} jam'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openForm(e),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
