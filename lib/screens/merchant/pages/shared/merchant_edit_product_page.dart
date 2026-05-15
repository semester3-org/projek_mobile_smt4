import 'package:flutter/material.dart';

import '../../merchant_ui.dart';

class MerchantEditProductPage extends StatelessWidget {
  const MerchantEditProductPage({
    super.key,
    required this.isLaundry,
  });

  final bool isLaundry;

  @override
  Widget build(BuildContext context) {
    return MerchantPage(
      topBar: MerchantTopBar(
        title: isLaundry ? 'Edit Layanan' : 'Edit Menu',
        showAvatar: false,
        showBack: true,
        actionLabel: 'Simpan',
        onAction: () {},
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
      children: isLaundry ? _laundryFields() : _cateringFields(),
    );
  }

  List<Widget> _laundryFields() {
    return const [
      _EditableHeroImage(
        imageUrl:
            'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=900',
        icon: Icons.local_laundry_service_outlined,
      ),
      SizedBox(height: 28),
      _FieldLabel('Nama Layanan'),
      SizedBox(height: 8),
      _TextInput(initialValue: 'Cuci Kering'),
      SizedBox(height: 22),
      _FieldLabel('Kategori'),
      SizedBox(height: 8),
      _SelectInput(value: 'Premium'),
      SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('Harga (IDR)'),
                SizedBox(height: 8),
                _TextInput(initialValue: '15000'),
              ],
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('Per Satuan'),
                SizedBox(height: 8),
                _SelectInput(value: 'Per kg'),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: 22),
      _FieldLabel('Deskripsi Layanan'),
      SizedBox(height: 8),
      _TextInput(
        initialValue:
            'Pencucian premium menggunakan deterjen ramah lingkungan, pelembut kain khusus, dan teknik penyetrikaan uap untuk menjaga kualitas serat pakaian tetap seperti baru.',
        maxLines: 5,
      ),
      SizedBox(height: 34),
      _ManagementCard(isLaundry: true),
      SizedBox(height: 34),
      _DeleteButton(label: 'Hapus Layanan'),
    ];
  }

  List<Widget> _cateringFields() {
    return const [
      _EditableHeroImage(
        imageUrl:
            'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=900',
        icon: Icons.restaurant_rounded,
      ),
      SizedBox(height: 34),
      MerchantCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Menu',
              style: TextStyle(
                color: MerchantPalette.text,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 24),
            _FieldLabel('Nama Menu'),
            SizedBox(height: 8),
            _TextInput(initialValue: 'Salmon Quinoa Bowl'),
            SizedBox(height: 22),
            _FieldLabel('Kategori'),
            SizedBox(height: 8),
            _SelectInput(value: 'Healthy Bowl'),
            SizedBox(height: 22),
            _FieldLabel('Harga (IDR)'),
            SizedBox(height: 8),
            _TextInput(prefix: 'Rp', initialValue: '85000'),
            SizedBox(height: 22),
            _FieldLabel('Deskripsi'),
            SizedBox(height: 8),
            _TextInput(
              initialValue:
                  'Salmon panggang segar yang disajikan di atas quinoa organik, dilengkapi dengan edamame, kol ungu, dan dressing lemon zest yang menyegarkan.',
              maxLines: 5,
            ),
          ],
        ),
      ),
      SizedBox(height: 28),
      _ManagementCard(isLaundry: false),
      SizedBox(height: 34),
      _DeleteButton(label: 'Hapus Menu'),
      SizedBox(height: 12),
      Center(
        child: Text(
          'Menu yang dihapus tidak dapat dikembalikan. Pastikan Anda sudah yakin.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MerchantPalette.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ];
  }
}

class _EditableHeroImage extends StatelessWidget {
  const _EditableHeroImage({
    required this.imageUrl,
    required this.icon,
  });

  final String imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MerchantImage(
          url: imageUrl,
          icon: icon,
          width: double.infinity,
          height: 190,
          borderRadius: BorderRadius.circular(12),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: MerchantPalette.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [MerchantPalette.shadow(opacity: 0.16)],
            ),
            child: const Icon(
              Icons.edit_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: MerchantPalette.muted,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.initialValue,
    this.maxLines = 1,
    this.prefix,
  });

  final String initialValue;
  final int maxLines;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      maxLines: maxLines,
      style: const TextStyle(
        color: MerchantPalette.text,
        fontSize: 16,
        height: 1.35,
      ),
      decoration: InputDecoration(
        prefixText: prefix == null ? null : '$prefix   ',
        prefixStyle: const TextStyle(
          color: MerchantPalette.muted,
          fontSize: 16,
        ),
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
    );
  }
}

class _SelectInput extends StatelessWidget {
  const _SelectInput({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC9D3E1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: MerchantPalette.text,
                fontSize: 16,
              ),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded),
        ],
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({required this.isLaundry});

  final bool isLaundry;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isLaundry ? 'Status Layanan' : 'Manajemen Stok',
                  style: const TextStyle(
                    color: MerchantPalette.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Switch(
                value: true,
                activeThumbColor: Colors.white,
                activeTrackColor: MerchantPalette.primary,
                onChanged: (_) {},
              ),
            ],
          ),
          Text(
            isLaundry
                ? 'Tampilkan layanan di aplikasi pelanggan'
                : 'Aktifkan untuk memunculkan menu di aplikasi pelanggan.',
            style: const TextStyle(
              color: MerchantPalette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
          if (isLaundry) ...[
            const Row(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  color: MerchantPalette.primary,
                  size: 26,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Manajemen Kapasitas',
                    style: TextStyle(
                      color: MerchantPalette.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Maksimum pesanan per hari',
                    style: TextStyle(
                      color: MerchantPalette.muted,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
                _StepperControl(value: '20'),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tersedia untuk Dipesan',
                    style: TextStyle(
                      color: MerchantPalette.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Aktifkan untuk memunculkan menu di aplikasi pelanggan.',
                    style: TextStyle(
                      color: MerchantPalette.muted,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _FieldLabel('Jumlah Porsi Tersedia'),
            const SizedBox(height: 10),
            const _StepperControl(value: '24'),
          ],
        ],
      ),
    );
  }
}

class _StepperControl extends StatelessWidget {
  const _StepperControl({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _StepButton(icon: Icons.remove_rounded, muted: true),
        const SizedBox(width: 12),
        Container(
          width: 88,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC9D3E1)),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: MerchantPalette.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const _StepButton(icon: Icons.add_rounded),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    this.muted = false,
  });

  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFE0E5EC) : const Color(0xFFCFE0FF),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        icon,
        color: muted ? MerchantPalette.muted : MerchantPalette.primary,
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.delete_outline_rounded),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        foregroundColor: MerchantPalette.danger,
        side: BorderSide(
          color: MerchantPalette.danger.withValues(alpha: 0.3),
        ),
        backgroundColor: MerchantPalette.danger.withValues(alpha: 0.08),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
