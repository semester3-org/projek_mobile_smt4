import 'package:flutter/material.dart';

import '../shared/merchant_dashboard_view.dart';
import 'catering_orders_page.dart';

class CateringDashboardPage extends StatelessWidget {
  const CateringDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MerchantDashboardView(
      isLaundry: false,
      onViewAllOrders: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CateringOrdersPage()),
      ),
    );
  }
}
