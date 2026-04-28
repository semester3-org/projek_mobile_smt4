import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class OwnerHelpPage extends StatelessWidget {
  const OwnerHelpPage({super.key});

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
          const _HelpTile(
            title: 'Cara menambahkan kamar baru',
            subtitle: 'Panduan singkat untuk menambah kamar dan mengatur statusnya.',
          ),
          const _HelpTile(
            title: 'Cara mengelola pembayaran',
            subtitle: 'Pelajari alur pemantauan penerimaan dan tagihan.',
          ),
          const _HelpTile(
            title: 'Cara menghubungi tim support',
            subtitle: 'Kirim pesan jika butuh bantuan teknis atau operasional.',
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {},
            child: const Text('Kirim Permintaan Bantuan'),
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        onTap: () {},
      ),
    );
  }
}
