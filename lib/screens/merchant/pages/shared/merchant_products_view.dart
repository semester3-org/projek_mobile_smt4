import 'package:flutter/material.dart';

import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/merchant_models.dart';
import '../../merchant_ui.dart';
import '../../widgets/merchant_laundry_estimates_panel.dart';
import 'merchant_edit_product_page.dart';
import 'merchant_notifications_page.dart';

class MerchantProductsView extends StatefulWidget {
  const MerchantProductsView({
    super.key,
    required this.isLaundry,
  });

  final bool isLaundry;

  @override
  State<MerchantProductsView> createState() => _MerchantProductsViewState();
}

class _MerchantProductsViewState extends State<MerchantProductsView> {
  List<MerchantProduct> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await MerchantRepository.getProducts();
    if (!mounted) return;
    setState(() {
      _products = result.data ?? [];
      _error = result.error;
      _loading = false;
    });
  }

  Future<void> _openEdit([MerchantProduct? product]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MerchantEditProductPage(
          isLaundry: widget.isLaundry,
          product: product,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isLaundry ? 'Kelola Layanan' : 'Kelola Paket Menu';
    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'MerchantHub',
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MerchantNotificationsPage()),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: MerchantPalette.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openEdit(),
        child: const Icon(Icons.add_rounded),
      ),
      children: [
        Text(
          title,
          style: const TextStyle(
            color: MerchantPalette.text,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isLaundry
              ? 'Nama, deskripsi, harga, foto, dan jam operasional merchant akan tampil ke user.'
              : 'Atur paket bulanan, pilihan menu, deskripsi lauk, harga, dan foto untuk user.',
          style: const TextStyle(
            color: MerchantPalette.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        if (widget.isLaundry)
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: MerchantLaundryEstimatesPanel(),
          ),
        MerchantCard(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Row(
            children: [
              Text(
                widget.isLaundry ? 'TOTAL LAYANAN' : 'TOTAL PAKET',
                style: const TextStyle(
                  color: MerchantPalette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _products.length.toString(),
                style: const TextStyle(
                  color: MerchantPalette.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.isLaundry ? 'Layanan' : 'Paket',
                style: const TextStyle(
                  color: MerchantPalette.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          MerchantCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_error!,
                    style: const TextStyle(color: MerchantPalette.danger)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Muat Ulang')),
              ],
            ),
          )
        else if (_products.isEmpty)
          _AddProductCard(
            label: widget.isLaundry
                ? 'Tambah Layanan Baru'
                : 'Tambah Paket Menu Baru',
            onTap: () => _openEdit(),
          )
        else ...[
          ..._products.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: _ProductCard(
                product: product,
                isLaundry: widget.isLaundry,
                onEdit: () => _openEdit(product),
              ),
            ),
          ),
          _AddProductCard(
            label: widget.isLaundry
                ? 'Tambah Layanan Baru'
                : 'Tambah Paket Menu Baru',
            onTap: () => _openEdit(),
          ),
        ],
        const MerchantBottomSpacer(),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isLaundry,
    required this.onEdit,
  });

  final MerchantProduct product;
  final bool isLaundry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasWeekdayPackage =
        !isLaundry && product.price20Days != null && product.price20Days! > 0;

    return MerchantCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              MerchantImage(
                url: product.imageUrl,
                icon: isLaundry
                    ? Icons.local_laundry_service_outlined
                    : Icons.restaurant_rounded,
                width: double.infinity,
                height: 178,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                child: MerchantStatusPill(
                  label: product.category.isEmpty
                      ? (isLaundry ? 'Layanan' : 'Paket')
                      : product.category,
                  color: Colors.white,
                  background: MerchantPalette.primary.withValues(alpha: 0.8),
                ),
              ),
              if (hasWeekdayPackage)
                Positioned(
                  top: 12,
                  right: 16,
                  child: MerchantStatusPill(
                    label: 'Weekday 30 hari tersedia',
                    color: MerchantPalette.text,
                    background: Colors.white.withValues(alpha: 0.92),
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
                        product.name,
                        style: const TextStyle(
                          color: MerchantPalette.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isLaundry)
                      Row(
                        children: [
                          Text(
                            formatMerchantCurrency(product.price),
                            style: const TextStyle(
                              color: MerchantPalette.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            product.unit,
                            style: const TextStyle(
                              color: MerchantPalette.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _ProductRatingTag(product: product),
                if (!isLaundry) ...[
                  const SizedBox(height: 10),
                  _PackagePriceTag(
                    icon: Icons.calendar_month_rounded,
                    text:
                        'Full Day 30 hari ${formatMerchantCurrency(product.price)} - dikirim setiap hari',
                    color: MerchantPalette.primary,
                    background: const Color(0xFFF3F6FF),
                    border: const Color(0xFFD8E1FF),
                  ),
                  if (hasWeekdayPackage) ...[
                    const SizedBox(height: 8),
                    _PackagePriceTag(
                      icon: Icons.event_busy_rounded,
                      text:
                          'Weekday 30 hari ${formatMerchantCurrency(product.price20Days!)} - Sabtu/Minggu libur',
                      color: const Color(0xFF2F7D4E),
                      background: const Color(0xFFF2F7F4),
                      border: const Color(0xFFCDE3D5),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _PackagePriceTag(
                    icon: Icons.delivery_dining_rounded,
                    text: product.mealDeliveryCount >= 2
                        ? 'Pengantaran 2x per hari: ${product.deliveryTime1} dan ${product.deliveryTime2 ?? '15:00'}'
                        : 'Pengantaran 1x per hari: ${product.deliveryTime1}',
                    color: const Color(0xFF7C3AED),
                    background: const Color(0xFFF6F1FF),
                    border: const Color(0xFFE4D7FF),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  product.description,
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

class _ProductRatingTag extends StatelessWidget {
  const _ProductRatingTag({required this.product});

  final MerchantProduct product;

  @override
  Widget build(BuildContext context) {
    final hasReviews = product.reviewCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E5),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFFFE3A3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 17, color: Color(0xFFFFB300)),
          const SizedBox(width: 6),
          Text(
            hasReviews
                ? '${product.rating.toStringAsFixed(1)} (${product.reviewCount} ulasan)'
                : 'Belum ada rating',
            style: const TextStyle(
              color: MerchantPalette.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddProductCard extends StatelessWidget {
  const _AddProductCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC5D0DE), width: 1.4),
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
            Text(
              label,
              style: const TextStyle(
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

class _PackagePriceTag extends StatelessWidget {
  const _PackagePriceTag({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
    required this.border,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
