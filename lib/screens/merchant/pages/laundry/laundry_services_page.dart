import 'package:flutter/material.dart';

import '../shared/merchant_products_view.dart';

class LaundryServicesPage extends StatelessWidget {
  const LaundryServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MerchantProductsView(isLaundry: true);
  }
}
