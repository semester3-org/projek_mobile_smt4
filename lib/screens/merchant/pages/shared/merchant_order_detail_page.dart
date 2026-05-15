import 'package:flutter/material.dart';

import '../../merchant_ui.dart';

class MerchantOrderDetailPage extends StatelessWidget {
  const MerchantOrderDetailPage({
    super.key,
    required this.isLaundry,
  });

  final bool isLaundry;

  @override
  Widget build(BuildContext context) {
    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'Detail Pesanan',
        showAvatar: false,
        showBack: true,
        actionIcon: isLaundry ? Icons.more_vert_rounded : Icons.blur_on,
        onAction: () {},
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      bottomBar: _OrderActionBar(isLaundry: isLaundry),
      children: isLaundry ? _laundryContent() : _cateringContent(),
    );
  }

  List<Widget> _laundryContent() {
    return const [
      _OrderHeaderCard(
        orderId: '#LND-202394',
        date: '24 Okt 2023 - 14:20 WIB',
        status: 'Menunggu Verifikasi',
      ),
      SizedBox(height: 24),
      _InfoCard(
        icon: Icons.person_rounded,
        title: 'Pelanggan',
        children: [
          Text(
            'Andi Pratama',
            style: TextStyle(
              color: MerchantPalette.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '+62 812 3456 7890',
            style: TextStyle(
              color: MerchantPalette.muted,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      SizedBox(height: 24),
      _AddressCard(
        title: 'Alamat Penjemputan',
        address:
            'Jl. Kemang Raya No. 12, Mampang Prapatan, Jakarta Selatan, 12730',
      ),
      SizedBox(height: 24),
      _LaundryServiceDetailCard(),
      SizedBox(height: 24),
      _PaymentProofCard(),
      MerchantBottomSpacer(),
    ];
  }

  List<Widget> _cateringContent() {
    return const [
      _OrderHeaderCard(
        orderId: '#ORD-202394',
        date: '24 Okt 2023, 10:30 WIB',
        status: 'Menunggu Verifikasi',
      ),
      SizedBox(height: 24),
      _InfoCard(
        icon: Icons.person_outline_rounded,
        title: 'Informasi Pelanggan',
        children: [
          _TinyLabel(label: 'NAMA'),
          SizedBox(height: 4),
          Text(
            'Andi Pratama',
            style: TextStyle(
              color: MerchantPalette.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 14),
          _TinyLabel(label: 'TELEPON'),
          SizedBox(height: 4),
          Text(
            '+62 812 3456 7890',
            style: TextStyle(
              color: MerchantPalette.muted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      SizedBox(height: 24),
      _AddressCard(
        title: 'Alamat Pengiriman',
        address: 'Jl. Senopati No. 45, Kebayoran Baru, Jakarta Selatan, 12110.',
      ),
      SizedBox(height: 24),
      _CateringOrderItemsCard(),
      SizedBox(height: 24),
      _PaymentProofCard(),
      MerchantBottomSpacer(),
    ];
  }
}

class _OrderHeaderCard extends StatelessWidget {
  const _OrderHeaderCard({
    required this.orderId,
    required this.date,
    required this.status,
  });

  final String orderId;
  final String date;
  final String status;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TinyLabel(label: 'ID PESANAN'),
                const SizedBox(height: 6),
                Text(
                  orderId,
                  style: const TextStyle(
                    color: MerchantPalette.primary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  date,
                  style: const TextStyle(
                    color: MerchantPalette.muted,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          MerchantStatusPill(
            label: status,
            color: MerchantPalette.warning,
            background: const Color(0xFFFFF2E6),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: icon, title: title),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.title,
    required this.address,
  });

  final String title;
  final String address;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.location_on_rounded, title: title),
          const SizedBox(height: 18),
          Text(
            address,
            style: const TextStyle(
              color: MerchantPalette.muted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          const _MapPreview(),
        ],
      ),
    );
  }
}

class _LaundryServiceDetailCard extends StatelessWidget {
  const _LaundryServiceDetailCard();

  @override
  Widget build(BuildContext context) {
    return const MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.local_laundry_service_outlined,
            title: 'Detail Layanan',
          ),
          SizedBox(height: 22),
          _PriceLine(
            title: 'Cuci Lipat Reguler',
            subtitle: '5kg @ Rp 8.000',
            price: 'Rp 40.000',
          ),
          Divider(height: 28),
          _PriceLine(
            title: 'Cuci Bedcover Large',
            subtitle: '1 unit @ Rp 35.000',
            price: 'Rp 35.000',
          ),
          Divider(height: 34),
          _TotalLine(total: 'Rp 75.000'),
        ],
      ),
    );
  }
}

class _CateringOrderItemsCard extends StatelessWidget {
  const _CateringOrderItemsCard();

  @override
  Widget build(BuildContext context) {
    return const MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.restaurant_rounded, title: 'Daftar Pesanan'),
          SizedBox(height: 22),
          _FoodItemLine(
            name: 'Nasi Box Ayam Bakar Madu',
            subtitle: '25x @ Rp 45.000',
            price: 'Rp 1.125.000',
            imageUrl:
                'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=300',
          ),
          Divider(height: 28),
          _FoodItemLine(
            name: 'Es Teh Manis Segar',
            subtitle: '25x @ Rp 10.000',
            price: 'Rp 250.000',
            imageUrl:
                'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=300',
          ),
          Divider(height: 34),
          _TotalLine(total: 'Rp 1.375.000'),
        ],
      ),
    );
  }
}

class _PaymentProofCard extends StatelessWidget {
  const _PaymentProofCard();

  @override
  Widget build(BuildContext context) {
    return const MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.receipt_long_rounded,
            title: 'Bukti Pembayaran',
          ),
          SizedBox(height: 22),
          _ReceiptPreview(),
          SizedBox(height: 22),
          _PaymentMeta(label: 'METODE PEMBAYARAN', value: 'Bank Transfer BCA'),
          SizedBox(height: 14),
          _PaymentMeta(label: 'NAMA PENGIRIM', value: 'Andi Pratama'),
          SizedBox(height: 18),
          _PaymentNotice(),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: MerchantPalette.primary, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: MerchantPalette.text,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _TinyLabel extends StatelessWidget {
  const _TinyLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: MerchantPalette.muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFDDF0F8),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MapPatternPainter()),
          ),
          const Center(
            child: Icon(
              Icons.location_pin,
              color: MerchantPalette.primaryLight,
              size: 58,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 86,
        height: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [MerchantPalette.shadow(opacity: 0.12)],
        ),
        child: Column(
          children: [
            Container(width: 52, height: 7, color: const Color(0xFFDDE3EB)),
            const SizedBox(height: 8),
            for (var i = 0; i < 8; i++) ...[
              Container(
                width: i.isEven ? 58 : 42,
                height: 4,
                color: const Color(0xFFE4E8EE),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.title,
    required this.subtitle,
    required this.price,
  });

  final String title;
  final String subtitle;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: MerchantPalette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: MerchantPalette.muted),
              ),
            ],
          ),
        ),
        Text(
          price,
          style: const TextStyle(
            color: MerchantPalette.text,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _FoodItemLine extends StatelessWidget {
  const _FoodItemLine({
    required this.name,
    required this.subtitle,
    required this.price,
    required this.imageUrl,
  });

  final String name;
  final String subtitle;
  final String price;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MerchantImage(
          url: imageUrl,
          icon: Icons.restaurant_rounded,
          width: 68,
          height: 68,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MerchantPalette.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: MerchantPalette.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          price,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: MerchantPalette.primary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.total});

  final String total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Total\nPembayaran',
            style: TextStyle(
              color: MerchantPalette.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
        Text(
          total,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: MerchantPalette.primary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _PaymentMeta extends StatelessWidget {
  const _PaymentMeta({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TinyLabel(label: label),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: MerchantPalette.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentNotice extends StatelessWidget {
  const _PaymentNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_outlined, color: MerchantPalette.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nominal transfer sesuai dengan tagihan',
              style: TextStyle(
                color: MerchantPalette.primary,
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

class _OrderActionBar extends StatelessWidget {
  const _OrderActionBar({required this.isLaundry});

  final bool isLaundry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFECEFF5))),
          boxShadow: [MerchantPalette.shadow(opacity: 0.08)],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: MerchantPalette.primary,
                  side: const BorderSide(
                    color: MerchantPalette.primary,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Verifikasi Order'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: MerchantPalette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(isLaundry ? 'Proses Pesanan' : 'Proses Pesanan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final thinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var i = -2; i < 6; i++) {
      final y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 54), thinPaint);
    }
    canvas.drawLine(
      Offset(-10, size.height * 0.7),
      Offset(size.width + 12, size.height * 0.22),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, -10),
      Offset(size.width * 0.74, size.height + 12),
      roadPaint,
    );
    canvas.drawLine(
      Offset(-10, size.height * 0.28),
      Offset(size.width + 10, size.height * 0.82),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
