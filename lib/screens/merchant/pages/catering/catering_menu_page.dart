import 'package:flutter/material.dart';

import '../shared/merchant_products_view.dart';

class CateringMenuPage extends StatelessWidget {
  const CateringMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MerchantProductsView(isLaundry: false);
  }
}
