import 'package:flutter/material.dart';

import '../shared/merchant_dashboard_view.dart';
import '../shared/merchant_orders_view.dart';

class CateringDashboardPage extends StatelessWidget {
  const CateringDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MerchantDashboardView(
      isLaundry: false,
      onViewAllOrders: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MerchantOrdersView(isLaundry: false, showBack: true),
          fullscreenDialog: false,
        ),
      ),
    );
  }
}
