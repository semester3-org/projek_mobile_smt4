import 'package:flutter/material.dart';

import '../shared/merchant_dashboard_view.dart';
import 'laundry_orders_page.dart';

class LaundryDashboardPage extends StatelessWidget {
  const LaundryDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MerchantDashboardView(
      isLaundry: true,
      onViewAllOrders: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LaundryOrdersPage()),
      ),
    );
  }
}
