import 'package:flutter/material.dart';

import '../shared/merchant_dashboard_view.dart';
import '../shared/merchant_orders_view.dart';

class LaundryDashboardPage extends StatelessWidget {
  const LaundryDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MerchantDashboardView(
      isLaundry: true,
      onViewAllOrders: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MerchantOrdersView(isLaundry: true, showBack: true),
          fullscreenDialog: false,
        ),
      ),
    );
  }
}
