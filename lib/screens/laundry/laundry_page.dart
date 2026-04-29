import 'package:flutter/material.dart';

import '../user/merchant_list_page.dart';

class LaundryPage extends StatelessWidget {
  const LaundryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MerchantListPage(
      type: 'laundry',
      title: 'Pilih Merchant',
      searchHint: 'Cari laundry terdekat...',
      filters: ['Semua', 'Kiloan', 'Satuan', 'Express', 'Terdekat'],
    );
  }
}
