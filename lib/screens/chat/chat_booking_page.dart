import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// Chat / booking — UI percakapan dummy.
class ChatBookingPage extends StatelessWidget {
  const ChatBookingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chats = [
      const _ChatPreview(
        title: 'Pemilik — Kos Hijau Asri',
        subtitle: 'Terima kasih, kamar masih tersedia.',
        time: '10:20',
      ),
      const _ChatPreview(
        title: 'Booking #1024',
        subtitle: 'Konfirmasi jadwal kunjung kos',
        time: 'Kemarin',
      ),
      const _ChatPreview(
        title: 'Support KosFinder',
        subtitle: 'Halo! Ada yang bisa kami bantu?',
        time: 'Sen',
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(
        title: const Text('Chat & booking'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: chats.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, i) {
          final c = chats[i];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppTheme.surfaceTint,
              child: Icon(Icons.person, color: AppTheme.primaryGreen),
            ),
            title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(c.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(
              c.time,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Buka chat: ${c.title} (demo)')),
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatPreview {
  const _ChatPreview({
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final String title;
  final String subtitle;
  final String time;
}
