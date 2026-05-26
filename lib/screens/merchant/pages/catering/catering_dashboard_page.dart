import 'package:flutter/material.dart';

import '../../merchant_ui.dart';
import 'catering_subscribers_page.dart';
import '../shared/merchant_dashboard_view.dart';
import '../shared/merchant_orders_view.dart';

class CateringDashboardPage extends StatelessWidget {
  const CateringDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MerchantDashboardView(
      isLaundry: false,
      headerExtra: MerchantCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CateringSubscribersPage()),
        ),
        child: const Row(
          children: [
            Icon(Icons.people_outline_rounded, color: MerchantPalette.primary),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pelanggan Berlangganan',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: MerchantPalette.text,
                    ),
                  ),
                  Text(
                    'Lihat daftar aktif & expired',
                    style: TextStyle(color: MerchantPalette.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: MerchantPalette.muted),
          ],
        ),
      ),
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
