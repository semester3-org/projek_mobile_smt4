import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/api_service.dart';
import '../../../data/repositories/owner_repository.dart';

class OwnerNotificationsPage extends StatefulWidget {
  const OwnerNotificationsPage({super.key});

  @override
  State<OwnerNotificationsPage> createState() => _OwnerNotificationsPageState();
}

class _OwnerNotificationsPageState extends State<OwnerNotificationsPage> {
  int _tab = 0; // 0 = Semua, 1 = Belum Dibaca, 2 = Pembayaran
  bool _isLoading = true;
  String? _error;
  List<dynamic> _allNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await ApiService.get('api/owner_notifications');
    if (!mounted) return;

    if (!res.success) {
      setState(() {
        _isLoading = false;
        _error = res.message ?? 'Gagal memuat notifikasi';
      });
      return;
    }

    try {
      final list = res.data!['data'] as List<dynamic>;
      setState(() {
        _allNotifications = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Format data notifikasi tidak valid';
      });
    }
  }

  Future<void> _markAsRead(int? notifId) async {
    final res = await ApiService.put('api/owner_notifications', {
      'id': notifId ?? 0,
    });

    if (!mounted) return;

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Gagal menandai dibaca'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _allNotifications = _allNotifications.map((notification) {
        if (notifId == null || notification['id'] == notifId) {
          return {
            ...Map<String, dynamic>.from(notification as Map),
            'isRead': true,
          };
        }
        return notification;
      }).toList();
    });
    if (notifId == null) {
      OwnerRepository.setUnreadNotificationCount(0);
    } else {
      OwnerRepository.invalidateNotificationCountCache();
    }

    await _loadNotifications();
  }

  List<dynamic> get _filteredNotifications {
    switch (_tab) {
      case 1: // Belum Dibaca
        return _allNotifications.where((n) => n['isRead'] == false).toList();
      case 2: // Pembayaran
        return _allNotifications
            .where((n) => n['category'] == 'pembayaran')
            .toList();
      default: // Semua
        return _allNotifications;
    }
  }

  void _showNotificationDetail(Map<String, dynamic> notification) {
    // Tandai sudah dibaca saat diklik
    if (notification['isRead'] == false) {
      _markAsRead(notification['id'] as int);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
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
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_active_rounded,
                          color: AppTheme.primaryGreen, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification['title'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification['time'] as String,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Detail Pesan',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Text(
                  notification['subtitle'] as String,
                  style: TextStyle(
                      color: Colors.grey.shade700, height: 1.5, fontSize: 13),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
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
    final filtered = _filteredNotifications;

    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(
        title: const Text('Pusat Notifikasi'),
        actions: [
          IconButton(
            tooltip: 'Tandai Semua Dibaca',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () => _markAsRead(null),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadNotifications,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: AppTheme.primaryGreen,
                  child: ListView(
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
                                        ? AppTheme.primaryGreen
                                            .withValues(alpha: 0.14)
                                        : Colors.transparent,
                                    foregroundColor: _tab == 0
                                        ? AppTheme.primaryGreen
                                        : Colors.grey.shade700,
                                  ),
                                  child: const Text('Semua'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: () => setState(() => _tab = 1),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _tab == 1
                                        ? AppTheme.primaryGreen
                                            .withValues(alpha: 0.14)
                                        : Colors.transparent,
                                    foregroundColor: _tab == 1
                                        ? AppTheme.primaryGreen
                                        : Colors.grey.shade700,
                                  ),
                                  child: const Text('Unread'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: () => setState(() => _tab = 2),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _tab == 2
                                        ? AppTheme.primaryGreen
                                            .withValues(alpha: 0.14)
                                        : Colors.transparent,
                                    foregroundColor: _tab == 2
                                        ? AppTheme.primaryGreen
                                        : Colors.grey.shade700,
                                  ),
                                  child: const Text('Bayar'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.notifications_none_rounded,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Tidak ada notifikasi',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...filtered.map(
                          (notif) => _NotifCard(
                            title: notif['title'] as String,
                            subtitle: notif['subtitle'] as String,
                            time: notif['time'] as String,
                            isRead: notif['isRead'] as bool,
                            onTap: () => _showNotificationDetail(
                                notif as Map<String, dynamic>),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isRead,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String time;
  final bool isRead;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    IconData getIcon() {
      final t = title.toLowerCase();
      if (t.contains('bayar')) return Icons.payments_rounded;
      if (t.contains('huni') || t.contains('kamar')) {
        return Icons.person_add_rounded;
      }
      return Icons.info_outline_rounded;
    }

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
                  getIcon(),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color:
                                  isRead ? Colors.grey.shade700 : Colors.black,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isRead
                            ? Colors.grey.shade600
                            : Colors.grey.shade800,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(time,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 11)),
                        const Spacer(),
                        if (onTap != null)
                          const Text(
                            'Lihat Detail →',
                            style: TextStyle(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
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
