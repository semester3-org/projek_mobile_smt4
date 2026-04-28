import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class OwnerNotificationsPage extends StatefulWidget {
  const OwnerNotificationsPage({super.key});

  @override
  State<OwnerNotificationsPage> createState() => _OwnerNotificationsPageState();
}

class _OwnerNotificationsPageState extends State<OwnerNotificationsPage> {
  int _tab = 0;

  // Sample notification data
  final List<_NotificationData> _allNotifications = [
    _NotificationData(
      title: 'Pembayaran Baru',
      subtitle: 'Andi Saputra telah mengirimkan bukti transfer untuk Kamar A-12 sebesar Rp 1.500.000.',
      time: 'Baru saja',
      icon: Icons.payments_rounded,
      badge: 'BARU',
      category: 'pembayaran',
      isRead: false,
    ),
    _NotificationData(
      title: 'Penghuni Baru',
      subtitle: 'Verifikasi identitas Rizky Pratama telah disetujui. Siap untuk check-in ke Kamar C-01.',
      time: '2 jam lalu',
      icon: Icons.person_add_alt_1_rounded,
      category: 'penghuni',
      isRead: false,
    ),
    _NotificationData(
      title: 'Pembayaran Berhasil',
      subtitle: 'Pembayaran bulanan dari Budi Santoso untuk Kamar A-01 sebesar Rp 1.500.000 telah dikonfirmasi.',
      time: '1 jam lalu',
      icon: Icons.check_circle_outline_rounded,
      category: 'pembayaran',
      isRead: true,
    ),
    _NotificationData(
      title: 'Laporan Selesai',
      subtitle: 'Perbaikan keran air di Kamar D-04 telah diselesaikan oleh teknisi.',
      time: 'Kemarin 22:15',
      icon: Icons.check_circle_rounded,
      badge: 'SELESAI',
      category: 'laporan',
      isRead: true,
    ),
    _NotificationData(
      title: 'Pembayaran Tertunda',
      subtitle: 'Pembayaran dari Siti Aminah untuk Kamar B-05 belum dikonfirmasi.',
      time: 'Kemarin 18:30',
      icon: Icons.warning_amber_rounded,
      category: 'pembayaran',
      isRead: true,
    ),
    _NotificationData(
      title: 'Permintaan Check-out',
      subtitle: 'Dian Sastro mengajukan check-out untuk Kamar A-12.',
      time: 'Kemarin 14:00',
      icon: Icons.exit_to_app_rounded,
      category: 'penghuni',
      isRead: true,
    ),
  ];

  List<_NotificationData> get _filteredNotifications {
    switch (_tab) {
      case 1: // Belum Dibaca
        return _allNotifications.where((n) => !n.isRead).toList();
      case 2: // Pembayaran
        return _allNotifications.where((n) => n.category == 'pembayaran').toList();
      default: // Semua
        return _allNotifications;
    }
  }

  void _showNotificationDetail(_NotificationData notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(notification.icon, color: AppTheme.primaryGreen, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.time,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    if (notification.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          notification.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Detail Pesan',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  notification.subtitle,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                ),
                const SizedBox(height: 24),
                if (!notification.isRead)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: const Text('Tandai Sudah Dibaca'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(title: const Text('Pusat Notifikasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          Text(
            'Kelola pembaruan aktivitas kos Anda hari ini.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => setState(() => _tab = 0),
                      style: FilledButton.styleFrom(
                        backgroundColor: _tab == 0
                            ? AppTheme.primaryGreen.withOpacity(0.14)
                            : Colors.transparent,
                        foregroundColor:
                            _tab == 0 ? AppTheme.primaryGreen : Colors.grey.shade700,
                      ),
                      child: const Text('Semua'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => setState(() => _tab = 1),
                      style: FilledButton.styleFrom(
                        backgroundColor: _tab == 1
                            ? AppTheme.primaryGreen.withOpacity(0.14)
                            : Colors.transparent,
                        foregroundColor:
                            _tab == 1 ? AppTheme.primaryGreen : Colors.grey.shade700,
                      ),
                      child: const Text('Belum Dibaca'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => setState(() => _tab = 2),
                      style: FilledButton.styleFrom(
                        backgroundColor: _tab == 2
                            ? AppTheme.primaryGreen.withOpacity(0.14)
                            : Colors.transparent,
                        foregroundColor:
                            _tab == 2 ? AppTheme.primaryGreen : Colors.grey.shade700,
                      ),
                      child: const Text('Pembayaran'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_filteredNotifications.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Tidak ada notifikasi',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._filteredNotifications.map(
              (notif) => _NotifCard(
                title: notif.title,
                subtitle: notif.subtitle,
                time: notif.time,
                icon: notif.icon,
                badge: notif.badge,
                isRead: notif.isRead,
                onTap: () => _showNotificationDetail(notif),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationData {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final String? badge;
  final String category;
  final bool isRead;

  const _NotificationData({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    this.badge,
    required this.category,
    required this.isRead,
  });
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    this.badge,
    this.isRead = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final String? badge;
  final bool isRead;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isRead ? Colors.grey.shade200 : AppTheme.surfaceTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isRead ? Colors.grey : AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(time, style: TextStyle(color: Colors.grey.shade600)),
                        const Spacer(),
                        if (onTap != null)
                          TextButton(
                            onPressed: onTap,
                            child: const Text('Lihat Detail →'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}