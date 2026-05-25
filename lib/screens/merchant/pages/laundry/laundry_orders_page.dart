import 'package:flutter/material.dart';

import '../shared/merchant_orders_view.dart';

class LaundryOrdersPage extends StatelessWidget {
  const LaundryOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MerchantOrdersView(isLaundry: true);
  }
}
