import 'package:flutter/material.dart';

import '../../merchant_ui.dart';
import '../shared/merchant_edit_product_page.dart';
import '../shared/merchant_notifications_page.dart';

class LaundryServicesPage extends StatelessWidget {
  const LaundryServicesPage({super.key});

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
        backgroundColor: MerchantPalette.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openEdit(context),
        child: const Icon(Icons.add_rounded),
      ),
      children: [
        const Text(
          'Kelola Produk',
          style: TextStyle(
            color: MerchantPalette.text,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kelola daftar layanan laundry Anda dengan mudah.',
          style: TextStyle(
            color: MerchantPalette.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 34),
        const MerchantCard(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Row(
            children: [
              Text(
                'TOTAL LAYANAN',
                style: TextStyle(
                  color: MerchantPalette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 10),
              Text(
                '12',
                style: TextStyle(
                  color: MerchantPalette.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'Kategori',
                style: TextStyle(
                  color: MerchantPalette.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const MerchantPromoBanner(
          title: 'Promo Berjalan\nCuci Kering diskon 20% khusus member baru.',
          buttonLabel: 'Lihat Promo',
        ),
        const SizedBox(height: 34),
        _LaundryProductCard(
          imageUrl:
              'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=900',
          tag: 'Layanan Kilat',
          name: 'Cuci Kering',
          description:
              'Layanan cuci bersih dan pengeringan mesin. Pakaian siap lipat.',
          price: 'Rp 7.000',
          unit: '/kg',
          onEdit: () => _openEdit(context),
        ),
        const SizedBox(height: 28),
        _LaundryProductCard(
          imageUrl:
              'https://images.unsplash.com/photo-1521656693074-0ef32e80a5d5?w=900',
          tag: '',
          name: 'Setrika Saja',
          description:
              'Penyetrikaan uap profesional untuk hasil rapi tanpa kerut.',
          price: 'Rp 5.000',
          unit: '/kg',
          onEdit: () => _openEdit(context),
        ),
        const SizedBox(height: 28),
        _LaundryProductCard(
          imageUrl:
              'https://images.unsplash.com/photo-1593030761757-71fae45fa0e7?w=900',
          tag: 'Premium',
          name: 'Laundry Satuan',
          description:
              'Perawatan khusus untuk jas, gaun, boneka, dan tekstil premium.',
          price: 'Rp 15k+',
          unit: '/pcs',
          onEdit: () => _openEdit(context),
        ),
        const SizedBox(height: 30),
        _AddProductCard(onTap: () => _openEdit(context)),
        const MerchantBottomSpacer(),
      ],
    );
  }

  static void _openEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MerchantEditProductPage(isLaundry: true),
      ),
    );
  }
}

class _LaundryProductCard extends StatelessWidget {
  const _LaundryProductCard({
    required this.imageUrl,
    required this.tag,
    required this.name,
    required this.description,
    required this.price,
    required this.unit,
    required this.onEdit,
  });

  final String imageUrl;
  final String tag;
  final String name;
  final String description;
  final String price;
  final String unit;
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
                icon: Icons.local_laundry_service_outlined,
                width: double.infinity,
                height: 172,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              if (tag.isNotEmpty)
                Positioned(
                  top: 12,
                  left: 16,
                  child: MerchantStatusPill(
                    label: tag,
                    color: Colors.white,
                    background: MerchantPalette.primary.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: MerchantPalette.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      price,
                      style: const TextStyle(
                        color: MerchantPalette.primary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      unit,
                      style: const TextStyle(
                        color: MerchantPalette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: MerchantPalette.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: MerchantPalette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddProductCard extends StatelessWidget {
  const _AddProductCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 260,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFC5D0DE),
            style: BorderStyle.solid,
            width: 1.4,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFE3E6EC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: MerchantPalette.muted,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Tambah Layanan Baru',
              style: TextStyle(
                color: MerchantPalette.muted,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
