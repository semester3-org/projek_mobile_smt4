import 'package:flutter/material.dart';

import '../../merchant_ui.dart';

class MerchantPromoPage extends StatelessWidget {
  const MerchantPromoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'Promo Merchant',
        actionIcon: Icons.add_circle_outline_rounded,
        onAction: () {},
      ),
      children: const [
        SizedBox(height: 6),
        _PromoMetric(
          icon: Icons.campaign_outlined,
          title: 'Promo Aktif',
          value: '12',
        ),
        SizedBox(height: 18),
        _PromoMetric(
          icon: Icons.analytics_outlined,
          title: 'Total Penggunaan',
          value: '1,248',
        ),
        SizedBox(height: 28),
        _LargePromoCta(),
        SizedBox(height: 34),
        MerchantSectionHeader(
          title: 'Kelola Promo',
          trailing: MerchantStatusPill(
            label: '12 Aktif',
            color: MerchantPalette.primary,
            background: MerchantPalette.softBlue,
          ),
        ),
        SizedBox(height: 18),
        _PromoCard(
          status: 'AKTIF',
          statusColor: MerchantPalette.success,
          title: 'Diskon Kilat 20%',
          date: '01 Jan - 15 Jan 2024',
          usage: '452',
        ),
        SizedBox(height: 22),
        _PromoCard(
          status: 'DRAFT',
          statusColor: MerchantPalette.warning,
          title: 'Promo Catering Wedding',
          date: 'Belum Diatur',
          usage: '0',
          draft: true,
        ),
        SizedBox(height: 22),
        _PromoCard(
          status: 'AKTIF',
          statusColor: MerchantPalette.success,
          title: 'Bundling Cuci Karpet',
          date: '20 Des - 31 Jan 2024',
          usage: '89',
        ),
        SizedBox(height: 22),
        _PromoCard(
          status: 'BERAKHIR',
          statusColor: MerchantPalette.muted,
          title: 'Gratis Ongkir Akhir Tahun',
          date: 'Expired 31 Des 2023',
          usage: '707',
          expired: true,
        ),
        MerchantBottomSpacer(),
      ],
    );
  }
}

class _PromoMetric extends StatelessWidget {
  const _PromoMetric({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: MerchantPalette.softBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: MerchantPalette.primary, size: 28),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: MerchantPalette.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: MerchantPalette.text,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LargePromoCta extends StatelessWidget {
  const _LargePromoCta();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [MerchantPalette.primary, Color(0xFF74B8CB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tingkatkan Omzet\nSekarang',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Buat promo menarik untuk menarik lebih banyak pelanggan setia.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: MerchantPalette.primary,
              minimumSize: const Size(226, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Buat Promo Baru',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.status,
    required this.statusColor,
    required this.title,
    required this.date,
    required this.usage,
    this.draft = false,
    this.expired = false,
  });

  final String status;
  final Color statusColor;
  final String title;
  final String date;
  final String usage;
  final bool draft;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final contentColor =
        expired ? const Color(0xFF757D8A) : MerchantPalette.text;
    final mutedColor =
        expired ? const Color(0xFF8D95A1) : MerchantPalette.muted;

    return MerchantCard(
      color: expired ? const Color(0xFFE3E5EA) : Colors.white,
      child: Opacity(
        opacity: expired ? 0.86 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MerchantStatusPill(label: status, color: statusColor),
                const Spacer(),
                const Icon(Icons.more_vert_rounded,
                    color: MerchantPalette.muted),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: contentColor,
                fontSize: 20,
                decoration: expired ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 17, color: mutedColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date,
                    style: TextStyle(color: mutedColor, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              expired ? 'Total\nPenggunaan\n' : 'Penggunaan\n',
                          style: TextStyle(
                            color: mutedColor,
                            height: 1.4,
                          ),
                        ),
                        TextSpan(
                          text: usage,
                          style: TextStyle(
                            color:
                                expired ? mutedColor : MerchantPalette.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (expired)
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD8E6FF),
                      foregroundColor: MerchantPalette.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Aktifkan\nKembali'),
                  )
                else
                  Row(
                    children: [
                      const _PromoIconButton(icon: Icons.edit_rounded),
                      const SizedBox(width: 10),
                      _PromoIconButton(
                        icon:
                            draft ? Icons.upload_rounded : Icons.pause_rounded,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoIconButton extends StatelessWidget {
  const _PromoIconButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: MerchantPalette.muted, size: 21),
    );
  }
}
