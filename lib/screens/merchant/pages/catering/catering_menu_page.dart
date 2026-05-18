import 'package:flutter/material.dart';

import '../../merchant_ui.dart';
import '../shared/merchant_edit_product_page.dart';
import '../shared/merchant_notifications_page.dart';

class CateringMenuPage extends StatelessWidget {
  const CateringMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'MerchantHub',
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MerchantNotificationsPage(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: MerchantPalette.primaryLight,
        foregroundColor: Colors.white,
        onPressed: () => _openEdit(context),
        child: const Icon(Icons.add_rounded),
      ),
      children: [
        const Text(
          'Produk',
          style: TextStyle(
            color: MerchantPalette.text,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: MerchantSearchField(hint: 'Cari Menu...'),
            ),
            const SizedBox(width: 12),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MerchantPalette.border),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: MerchantPalette.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _FoodProductCard(
          imageUrl:
              'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=900',
          status: 'Tersedia',
          statusColor: MerchantPalette.primaryLight,
          name: 'Salmon Quinoa Bowl',
          description:
              'Nasi quinoa sehat dengan salmon panggang, edamame, dan saus teriyaki',
          price: 'Rp 85.000',
          onEdit: () => _openEdit(context),
        ),
        const SizedBox(height: 22),
        _FoodProductCard(
          imageUrl:
              'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=900',
          status: 'Tersedia',
          statusColor: MerchantPalette.primaryLight,
          name: 'Nasi Kuning Box',
          description:
              'Paket nasi kuning komplit dengan ayam suwir, orek tempe, dan sambal goreng',
          price: 'Rp 45.000',
          onEdit: () => _openEdit(context),
        ),
        const SizedBox(height: 22),
        _FoodProductCard(
          imageUrl:
              'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=900',
          status: 'Penuh',
          statusColor: MerchantPalette.danger,
          name: 'Beef Steak Salad',
          description:
              'Sajian salad premium dengan potongan daging sapi sirloin panggang',
          price: 'Rp 120.000',
          onEdit: () => _openEdit(context),
        ),
        const SizedBox(height: 22),
        _FoodProductCard(
          imageUrl:
              'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=900',
          status: 'Tersedia',
          statusColor: MerchantPalette.primaryLight,
          name: 'Berry Breeze',
          description:
              'Smoothie berry campuran yang segar dan kaya akan antioksidan',
          price: 'Rp 35.000',
          onEdit: () => _openEdit(context),
        ),
        const SizedBox(height: 22),
        _FoodProductCard(
          imageUrl:
              'https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?w=900',
          status: 'Tersedia',
          statusColor: MerchantPalette.primaryLight,
          name: 'Signature Artisan Pizza',
          description:
              'Pizza tipis garing dengan keju mozzarella premium, basil, dan saus tomat',
          price: 'Rp 98.000',
          onEdit: () => _openEdit(context),
        ),
        const SizedBox(height: 22),
        _FoodProductCard(
          imageUrl:
              'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=900',
          status: 'Tersedia',
          statusColor: MerchantPalette.primaryLight,
          name: 'Tiramisu Signature',
          description:
              'Dessert klasik Italia dengan lapisan biskuit kopi dan krim mascarpone',
          price: 'Rp 42.000',
          onEdit: () => _openEdit(context),
        ),
        const MerchantBottomSpacer(),
      ],
    );
  }

  static void _openEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MerchantEditProductPage(isLaundry: false),
      ),
    );
  }
}

class _FoodProductCard extends StatelessWidget {
  const _FoodProductCard({
    required this.imageUrl,
    required this.status,
    required this.statusColor,
    required this.name,
    required this.description,
    required this.price,
    required this.onEdit,
  });

  final String imageUrl;
  final String status;
  final Color statusColor;
  final String name;
  final String description;
  final String price;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              MerchantImage(
                url: imageUrl,
                icon: Icons.restaurant_menu_rounded,
                width: double.infinity,
                height: 190,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: MerchantStatusPill(
                  label: status,
                  color: statusColor,
                  background: statusColor.withValues(alpha: 0.16),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: MerchantPalette.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPalette.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        price,
                        style: const TextStyle(
                          color: MerchantPalette.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 17),
                      label: const Text('Edit'),
                      style: FilledButton.styleFrom(
                        backgroundColor: MerchantPalette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
