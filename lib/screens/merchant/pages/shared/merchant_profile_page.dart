import 'package:flutter/material.dart';

import '../../../../auth/auth_scope.dart';
import '../../../../auth/roles.dart';
import '../../merchant_ui.dart';

class MerchantProfilePage extends StatelessWidget {
  const MerchantProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final session = auth.session;
    final merchantType = session?.merchantType ?? MerchantType.laundry;
    final isLaundry = merchantType == MerchantType.laundry;
    final name = (session?.displayName.trim().isNotEmpty ?? false)
        ? session!.displayName.trim()
        : isLaundry
            ? 'Laundry Jaya'
            : 'Sentra Catering';

    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'Edit Profil Merchant',
        showAvatar: false,
        actionLabel: 'Simpan',
        onAction: () {},
      ),
      children: [
        Center(
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 126,
                    height: 126,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isLaundry
                            ? const [Color(0xFFD7F3F5), Color(0xFFB4D4E8)]
                            : const [Color(0xFFF3D7A8), Color(0xFF443019)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [MerchantPalette.shadow(opacity: 0.12)],
                    ),
                    child: Icon(
                      isLaundry
                          ? Icons.local_laundry_service_outlined
                          : Icons.restaurant_rounded,
                      color: isLaundry ? MerchantPalette.primary : Colors.white,
                      size: 48,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: 8,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: MerchantPalette.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MerchantPalette.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'ID Merchant: M-88210',
                style: TextStyle(
                  color: MerchantPalette.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 34),
        const MerchantCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: MerchantPalette.primary,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Performa Merchant',
                    style: TextStyle(
                      color: MerchantPalette.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _PerformanceBox(value: '4.8', label: 'RATING TOKO'),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child:
                        _PerformanceBox(value: '1,240', label: 'TOTAL ULASAN'),
                  ),
                ],
              ),
              SizedBox(height: 18),
              Text(
                'Data rating dan ulasan dikelola secara otomatis oleh sistem dan tidak dapat diubah secara manual.',
                style: TextStyle(
                  color: MerchantPalette.muted,
                  fontSize: 12,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _ProfileInput(
          icon: Icons.store_mall_directory_outlined,
          label: 'Nama Merchant',
          initialValue: name,
        ),
        const SizedBox(height: 26),
        _ProfileInput(
          icon: Icons.description_outlined,
          label: 'Deskripsi & Bio',
          initialValue: isLaundry
              ? 'Laundry profesional dengan layanan cuci kiloan, setrika, dan antar jemput untuk penghuni sekitar.'
              : 'Penyedia jasa catering premium untuk apartemen dan kost eksklusif. Menyajikan masakan rumah berkualitas dengan bahan organik pilihan.',
          maxLines: 4,
        ),
        const SizedBox(height: 26),
        _ProfileInput(
          icon: Icons.location_on_outlined,
          label: 'Lokasi Pusat Operasional',
          initialValue: isLaundry
              ? 'Jl. Melati No. 12, Jakarta Selatan'
              : 'Jl. Sudirman No. 45, Jakarta Selatan',
          suffix: Icons.my_location_rounded,
        ),
        const SizedBox(height: 26),
        _CategorySection(isLaundry: isLaundry),
        const SizedBox(height: 34),
        const Divider(height: 1),
        const SizedBox(height: 34),
        const _CloseMerchantCard(),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Keluar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: MerchantPalette.primary,
              side: const BorderSide(color: MerchantPalette.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const MerchantBottomSpacer(),
      ],
    );
  }
}

class _PerformanceBox extends StatelessWidget {
  const _PerformanceBox({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MerchantPalette.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: MerchantPalette.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: MerchantPalette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInput extends StatelessWidget {
  const _ProfileInput({
    required this.icon,
    required this.label,
    required this.initialValue,
    this.maxLines = 1,
    this.suffix,
  });

  final IconData icon;
  final String label;
  final String initialValue;
  final int maxLines;
  final IconData? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: MerchantPalette.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: MerchantPalette.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: initialValue,
          maxLines: maxLines,
          style: const TextStyle(
            color: MerchantPalette.text,
            fontSize: 16,
            height: 1.38,
          ),
          decoration: InputDecoration(
            suffixIcon: suffix == null
                ? null
                : Icon(suffix, color: MerchantPalette.primary),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC9D3E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC9D3E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: MerchantPalette.primary, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.isLaundry});

  final bool isLaundry;

  @override
  Widget build(BuildContext context) {
    final first = isLaundry ? 'Laundry Kiloan' : 'Makanan & Minuman';
    final second = isLaundry ? 'Antar Jemput' : 'Langganan';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.category_outlined,
              color: MerchantPalette.primary,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Kategori Layanan',
              style: TextStyle(
                color: MerchantPalette.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _CategoryChip(label: '$first x'),
            _CategoryChip(label: '$second x'),
            const _AddCategoryChip(),
          ],
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: MerchantPalette.primaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AddCategoryChip extends StatelessWidget {
  const _AddCategoryChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFC9D3E1)),
      ),
      child: const Text(
        '+ Tambah Kategori',
        style: TextStyle(
          color: MerchantPalette.muted,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CloseMerchantCard extends StatelessWidget {
  const _CloseMerchantCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: MerchantPalette.danger.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MerchantPalette.danger.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tutup Merchant',
                  style: TextStyle(
                    color: MerchantPalette.danger,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Menonaktifkan layanan Anda sementara dari aplikasi.',
                  style: TextStyle(
                    color: MerchantPalette.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: MerchantPalette.danger,
              side: const BorderSide(color: MerchantPalette.danger),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
  }
}
