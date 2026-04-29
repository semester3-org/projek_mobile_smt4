import 'package:flutter/material.dart';

import '../user/merchant_list_page.dart';

class CafePage extends StatelessWidget {
  const CafePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MerchantListPage(
      type: 'cafe',
      title: 'Pilihan Kafe',
      searchHint: 'Cari kafe favoritmu...',
      filters: ['Semua', 'Terdekat', 'Rating Tertinggi', 'Outdoor'],
      showLocationPrompt: true,
    );
  }
}
