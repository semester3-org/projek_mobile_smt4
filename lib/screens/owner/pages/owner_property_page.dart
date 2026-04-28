import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_theme.dart';

class OwnerPropertyPage extends StatelessWidget {
  const OwnerPropertyPage({super.key});

  void _showAddPropertyDialog(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Properti Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Properti',
                  hintText: 'Contoh: Kos Melati',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Lokasi / Alamat',
                  hintText: 'Jl. ...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga per Bulan (Rp)',
                  hintText: 'Contoh: 1500000',
                  border: OutlineInputBorder(),
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (Opsional)',
                  hintText: 'Fasilitas, dll...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              // Info: access_code di-generate otomatis oleh server
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kode akses kos akan di-generate otomatis setelah properti disimpan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  addressController.text.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Properti "${nameController.text}" berhasil ditambahkan!'),
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nama dan alamat wajib diisi!'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showAccessCode(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kode Akses Kos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bagikan kode ini kepada calon penghuni agar mereka bisa mendaftar kamar.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: 'Salin kode',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kode disalin!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(title: const Text('Data Properti')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Properti Anda',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kelola semua detail dan fasilitas properti Anda di sini. Tambah, edit, dan review listing kos agar tampil maksimal.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          _PropertyTile(
            title: 'Kos Hijau Asri',
            location: 'Jl. Melati No. 12, Sleman',
            accessCode: 'KOS-K1A2B3-4521',
            status: 'Aktif',
            detail: '12 kamar • 4 tersedia',
            pricePerMonth: 1200000,
            onShowCode: (code) => _showAccessCode(context, code),
          ),
          _PropertyTile(
            title: 'Kost Minimalis Putih',
            location: 'Jl. Kenanga 5, Depok',
            accessCode: 'KOS-K2C3D4-8832',
            status: 'Aktif',
            detail: '8 kamar • 1 tersedia',
            pricePerMonth: 950000,
            onShowCode: (code) => _showAccessCode(context, code),
          ),
          _PropertyTile(
            title: 'Green House Residence',
            location: 'Jl. Merpati 88, Condongcatur',
            accessCode: 'KOS-K3E4F5-2210',
            status: 'Aktif',
            detail: '15 kamar • 2 tersedia',
            pricePerMonth: 1500000,
            onShowCode: (code) => _showAccessCode(context, code),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _showAddPropertyDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Tambahkan Properti Baru'),
          ),
        ],
      ),
    );
  }
}

class _PropertyTile extends StatelessWidget {
  const _PropertyTile({
    required this.title,
    required this.location,
    required this.accessCode,
    required this.status,
    required this.detail,
    required this.pricePerMonth,
    required this.onShowCode,
  });

  final String title;
  final String location;
  final String accessCode;
  final String status;
  final String detail;
  final int pricePerMonth;
  final void Function(String code) onShowCode;

  String _formatPrice(int price) {
    return 'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}/bln';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Chip(
                  label: Text(status),
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.12),
                  labelStyle: const TextStyle(color: AppTheme.primaryGreen),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(location, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(detail, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(_formatPrice(pricePerMonth),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Divider(height: 16),
            // Tampilkan access_code dengan tombol salin
            Row(
              children: [
                const Icon(Icons.vpn_key_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Kode: $accessCode',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => onShowCode(accessCode),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Bagikan'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}