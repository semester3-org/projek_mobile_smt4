import 'package:flutter/material.dart';

import '../user/merchant_list_page.dart';

class CateringPage extends StatelessWidget {
  const CateringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MerchantListPage(
      type: 'catering',
      title: 'Pilih Merchant',
      searchHint: 'Cari catering terdekat...',
      filters: ['Semua', 'Terdekat', 'Terpopuler', 'Diet Sehat'],
    );
  }
}
