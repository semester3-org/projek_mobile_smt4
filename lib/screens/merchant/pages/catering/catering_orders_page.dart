import 'package:flutter/material.dart';

import '../shared/merchant_orders_view.dart';

class CateringOrdersPage extends StatelessWidget {
  const CateringOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MerchantOrdersView(isLaundry: false);
  }
}
