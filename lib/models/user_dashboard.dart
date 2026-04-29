import 'user_merchant.dart';

class UserDashboard {
  const UserDashboard({
    required this.displayName,
    required this.activeBillAmount,
    required this.activeBillLabel,
    required this.dueDateText,
    required this.billProgress,
    required this.announcementTitle,
    required this.announcementSubtitle,
    required this.recommendations,
  });

  final String displayName;
  final double activeBillAmount;
  final String activeBillLabel;
  final String dueDateText;
  final double billProgress;
  final String announcementTitle;
  final String announcementSubtitle;
  final List<MerchantMenuItem> recommendations;

  factory UserDashboard.fromJson(Map<String, dynamic> json) {
    final recommendationsRaw =
        json['recommendations'] as List<dynamic>? ?? const [];

    return UserDashboard(
      displayName: json['displayName'] as String? ?? 'User',
      activeBillAmount: (json['activeBillAmount'] as num?)?.toDouble() ?? 0,
      activeBillLabel: json['activeBillLabel'] as String? ?? 'Tagihan Aktif',
      dueDateText: json['dueDateText'] as String? ?? '-',
      billProgress: (json['billProgress'] as num?)?.toDouble() ?? 0,
      announcementTitle: json['announcementTitle'] as String? ?? '',
      announcementSubtitle: json['announcementSubtitle'] as String? ?? '',
      recommendations: recommendationsRaw
          .map((e) => MerchantMenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory UserDashboard.fallback(String displayName) {
    return UserDashboard(
      displayName: displayName,
      activeBillAmount: 0,
      activeBillLabel: 'Belum ada tagihan aktif',
      dueDateText: '-',
      billProgress: 0,
      announcementTitle: 'Pembersihan AC Terjadwal',
      announcementSubtitle: 'Besok, pukul 10:00 WIB',
      recommendations: const [
        MerchantMenuItem(
          id: 'rec-1',
          name: 'Salad Sehat Ayam Bakar',
          description: 'Menu harian',
          price: 25000,
          imageUrl:
              'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800',
        ),
        MerchantMenuItem(
          id: 'rec-2',
          name: 'Signature Coffee',
          description: 'Kopi favorit',
          price: 18000,
          imageUrl:
              'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
        ),
      ],
    );
  }
}
