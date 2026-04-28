import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class OwnerRatingPage extends StatelessWidget {
  const OwnerRatingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(title: const Text('Rating')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _RatingTile(
            name: 'Budi Santoso',
            room: 'A-01',
            stars: 5,
            message: 'Kamar bersih, respon cepat. Mantap!',
          ),
          _RatingTile(
            name: 'Dian Sastro',
            room: 'A-12',
            stars: 4,
            message: 'Lokasi strategis, tapi parkir agak sempit.',
          ),
          _RatingTile(
            name: 'Randy Panglila',
            room: 'B-03',
            stars: 5,
            message: 'Fasilitas lengkap dan aman.',
          ),
        ],
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({
    required this.name,
    required this.room,
    required this.stars,
    required this.message,
  });

  final String name;
  final String room;
  final int stars;
  final String message;

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
                const CircleAvatar(
                  backgroundColor: AppTheme.surfaceTint,
                  child: Icon(Icons.person, color: AppTheme.primaryGreen),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text('Kamar $room',
                          style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 18,
                      color: const Color(0xFFFFB300),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(message, style: TextStyle(color: Colors.grey.shade800)),
          ],
        ),
      ),
    );
  }
}

