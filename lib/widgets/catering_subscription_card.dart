import 'package:flutter/material.dart';

import '../models/catering_subscriber.dart';
import '../models/order.dart';
import '../screens/user/order_detail_page.dart';
import '../screens/user/user_theme.dart';
import '../screens/user/user_widgets.dart';

class CateringSubscriptionCard extends StatelessWidget {
  const CateringSubscriptionCard({
    super.key,
    required this.subscription,
    this.compact = false,
  });

  final CateringSubscriber subscription;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = subscription.subscriptionStatus.toLowerCase();
    final isActive = subscription.isActive && !subscription.isExpired;
    final statusColor = isActive
        ? UserTheme.primary
        : subscription.isExpired
            ? UserTheme.muted
            : const Color(0xFFB55B00);
    final statusLabel = switch (status) {
      'active' => 'AKTIF',
      'cancel_requested' => 'AKTIF (BATAL BULAN DEPAN)',
      'expired' || 'ended' => 'EXPIRED',
      _ => status.toUpperCase(),
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: subscription.orderId.isEmpty
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => UserOrderDetailPage(
                      order: Order(
                        id: subscription.orderCode.isNotEmpty
                            ? subscription.orderCode
                            : subscription.orderId,
                        databaseId: subscription.orderId,
                        merchantName: subscription.merchantName,
                        service: 'catering',
                        orderDate: DateTime.tryParse(
                                subscription.startDate ?? '') ??
                            DateTime.now(),
                        totalAmount: subscription.totalAmount,
                        status: isActive ? 'confirmed' : 'completed',
                        items: [
                          OrderItem(
                            name: subscription.productName.isNotEmpty
                                ? subscription.productName
                                : subscription.packageLabel,
                            description: subscription.productDescription,
                            quantity: 1,
                            price: subscription.totalAmount,
                            subtotal: subscription.totalAmount,
                          ),
                        ],
                        subscriptionDays: subscription.packageType
                                .contains('20')
                            ? 20
                            : 30,
                        subscriptionStartDate: DateTime.tryParse(
                            subscription.startDate ?? ''),
                        subscriptionEndDate:
                            DateTime.tryParse(subscription.endDate ?? ''),
                        subscriptionStatus: subscription.subscriptionStatus,
                      ),
                    ),
                  ),
                );
              },
        child: Container(
          padding: EdgeInsets.all(compact ? 16 : 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? UserTheme.primary.withValues(alpha: 0.25)
                  : const Color(0xFFE3E9F3),
            ),
            boxShadow: [UserTheme.softShadow(opacity: 0.04)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: UserTheme.softBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: UserTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.productName.isNotEmpty
                              ? subscription.productName
                              : subscription.packageLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: UserTheme.text,
                          ),
                        ),
                        Text(
                          subscription.merchantName,
                          style: const TextStyle(
                            color: UserTheme.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 14),
                if (subscription.productDescription.isNotEmpty)
                  Text(
                    subscription.productDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: UserTheme.muted,
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Icon(Icons.date_range_outlined,
                      size: 16, color: UserTheme.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_fmt(subscription.startDate)} — ${_fmt(subscription.endDate)}',
                      style: const TextStyle(
                        color: UserTheme.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    formatUserCurrency(subscription.totalAmount),
                    style: const TextStyle(
                      color: UserTheme.primaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return formatShortDate(d);
  }
}
