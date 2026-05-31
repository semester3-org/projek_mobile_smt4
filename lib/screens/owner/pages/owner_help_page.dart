import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class OwnerHelpPage extends StatelessWidget {
  const OwnerHelpPage({super.key});

  void _showHelpDetail(BuildContext context, String title, String detail) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          detail,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Paham'),
          ),
        ],
      ),
    );
  }

  void _showContactSupport(BuildContext context) {
    final msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim Permintaan Bantuan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tuliskan kendala teknis atau operasional yang Anda alami. Tim support kami akan segera membalas via email.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: msgController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Pesan Kendala',
                hintText: 'Tulis deskripsi kendala Anda...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (msgController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pesan kendala wajib diisi!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Permintaan bantuan berhasil dikirim! Kami akan menghubungi Anda segera.'),
                  backgroundColor: AppTheme.primaryGreen,
                ),
              );
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(title: const Text('Bantuan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Pusat Bantuan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Temukan jawaban cepat untuk pertanyaan umum tentang operasional kos Anda.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          _HelpTile(
            title: 'Cara menambahkan kamar baru',
            subtitle: 'Panduan singkat untuk menambah kamar dan mengatur statusnya.',
            onTap: () => _showHelpDetail(
              context,
              'Cara Menambahkan Kamar Baru',
              '1. Navigasi ke halaman "Kamar" dari menu bawah.\n'
              '2. Klik tombol "Tambah Kamar" (ikon hijau di sudut kanan bawah).\n'
              '3. Isi informasi kamar seperti nomor kamar, tipe (AC/Kipas), kapasitas, tipe sewa, dan harga.\n'
              '4. Pilih fasilitas yang tersedia (WiFi, AC, Kamar Mandi Dalam, dll).\n'
              '5. Klik "Simpan". Kamar Anda akan langsung terdaftar di database server.',
            ),
          ),
          _HelpTile(
            title: 'Cara mengelola pembayaran',
            subtitle: 'Pelajari alur pemantauan penerimaan dan tagihan.',
            onTap: () => _showHelpDetail(
              context,
              'Cara Mengelola Pembayaran',
              '1. Buka menu "Keuangan" dari navigasi utama.\n'
              '2. Di tab "Daftar Riwayat Pembayaran", Anda akan melihat transaksi dengan status Lunas, Menunggu, atau Jatuh Tempo.\n'
              '3. Untuk menyetujui bukti bayar offline/transfer yang diupload oleh anak kos, klik transaksi bertanda "Menunggu".\n'
              '4. Di Bottom Sheet detail, klik tombol biru "Konfirmasi Pembayaran".\n'
              '5. Status transaksi akan seketika berubah menjadi Lunas di database.',
            ),
          ),
          _HelpTile(
            title: 'Cara menghubungkan penyewa',
            subtitle: 'Bagikan kode akses kos Anda ke penyewa.',
            onTap: () => _showHelpDetail(
              context,
              'Cara Menghubungkan Penyewa',
              '1. Navigasi ke menu "Profil" -> pilih "Data Properti".\n'
              '2. Anda akan melihat kode unik berbentuk "KOS-XXXXXX" di setiap properti kos Anda.\n'
              '3. Klik tombol "Bagikan Kode" untuk menyalin kode akses tersebut.\n'
              '4. Calon penyewa dapat menggunakan kode ini di aplikasi KosFinder mereka untuk mendaftar sewa kamar secara otomatis.',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showContactSupport(context),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Kirim Permintaan Bantuan'),
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
