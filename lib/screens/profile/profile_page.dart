import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../auth/roles.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/user_profile.dart';
import '../user/user_theme.dart';
import '../user/user_widgets.dart';
import 'billing_list_page.dart';
import 'favorite_merchants_page.dart';
import 'notification_list_page.dart';
import 'order_history_page.dart';
import 'user_profile_detail_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _codeCtrl = TextEditingController();
  final _roomCodeCtrl = TextEditingController();
  UserProfile? _profile;
  bool _loading = true;
  bool _connecting = false;
  bool _didLoad = false;
  StreamSubscription<void>? _profileRefreshSub;

  @override
  void initState() {
    super.initState();
    _profileRefreshSub = UserRepository.profileRefreshRequests.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  @override
  void dispose() {
    _profileRefreshSub?.cancel();
    _codeCtrl.dispose();
    _roomCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = AuthScope.of(context).session;
    final result = await UserRepository.getProfile(
      displayName: session?.displayName ?? 'User',
      email: session?.email ?? '',
      role: session?.role.label ?? 'User',
    );
    if (!mounted) return;
    setState(() {
      _profile = result.data;
      _codeCtrl.text = _profile?.kosAccessCode ?? '';
      _roomCodeCtrl.text = _profile?.roomNumber ?? '';
      _loading = false;
    });
  }

  Future<void> _connectCode() async {
    final accessCode = _codeCtrl.text.trim();
    final roomCode = _roomCodeCtrl.text.trim();
    if (accessCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan kode unik kos terlebih dahulu')),
      );
      return;
    }

    if (roomCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan kode unik kamar terlebih dahulu')),
      );
      return;
    }

    final profile = _profile;
    final isChangingKos = (profile?.kosAccessCode ?? '').isNotEmpty &&
        (profile?.kosAccessCode ?? '').toUpperCase() !=
            accessCode.toUpperCase();
    final isChangingRoom = (profile?.roomNumber ?? '').isNotEmpty &&
        (profile?.roomNumber ?? '').toUpperCase() != roomCode.toUpperCase();
    final activeUntil = profile?.activeUntil;
    final hasPreviousRoom = (profile?.kosAccessCode ?? '').isNotEmpty ||
        (profile?.roomNumber ?? '').isNotEmpty;
    final isReturningToOwnedActiveRoom = _hasActiveRentForRoom(
      profile,
      accessCode,
      roomCode,
    );

    var confirmStopPreviousRent = false;
    if ((isChangingKos || isChangingRoom) && hasPreviousRoom) {
      final activeUntilText = activeUntil == null
          ? 'Jika masih ada tagihan aktif, tagihan kamar lama akan dibuat tidak diperpanjang.'
          : 'Masa aktif tetap berjalan sampai ${formatShortDate(activeUntil)} lalu kamar lama akan dilepas.';
      final message = isReturningToOwnedActiveRoom
          ? 'Kamar tujuan masih memiliki masa sewa aktif milik Anda. Anda bisa kembali tanpa persetujuan owner ulang. $activeUntilText'
          : 'Kamar sebelumnya tidak akan diperpanjang otomatis. $activeUntilText Lanjutkan perpindahan kamar?';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ganti Kos/Kamar?'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Lanjutkan'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      confirmStopPreviousRent = true;
    }

    setState(() => _connecting = true);
    final result = await UserRepository.connectKosCode(
      accessCode,
      roomCode,
      confirmStopPreviousRent,
    );
    if (!mounted) return;
    setState(() => _connecting = false);

    if (result.isSuccess) {
      setState(() {
        _profile = result.data;
        _roomCodeCtrl.text = _profile?.roomNumber ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isReturningToOwnedActiveRoom
                ? 'Berhasil kembali ke kamar yang masa sewanya masih aktif'
                : (isChangingKos || isChangingRoom)
                    ? 'Pengajuan perpindahan kamar dikirim dan menunggu verifikasi owner'
                : 'Kode kos berhasil disambungkan',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Kode kos tidak valid')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final session = auth.session;

    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Profil',
          style: TextStyle(
            color: UserTheme.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          UserNotificationIconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationListPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: UserTheme.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  _ProfileHeader(
                    profile: _profile,
                    sessionName: session?.displayName,
                    onTap: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) => const UserProfileDetailPage(),
                          ),
                        )
                        .then((_) => _load()),
                  ),
                  if (_profile != null) ...[
                    const SizedBox(height: 14),
                    _ActiveRentBanner(profile: _profile!),
                    const SizedBox(height: 14),
                    _RentHistorySection(profile: _profile!),
                  ],
                  const SizedBox(height: 18),
                  _KosCodeCard(
                    accessCodeController: _codeCtrl,
                    roomCodeController: _roomCodeCtrl,
                    isConnecting: _connecting,
                    onConnect: _connectCode,
                  ),
                  const SizedBox(height: 24),
                  _InfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: _profile?.email.isNotEmpty == true
                        ? _profile!.email
                        : session?.email ?? '-',
                  ),
                  _InfoTile(
                    icon: Icons.home_work_outlined,
                    label: 'Nama Kos',
                    value: _profile?.kosName ?? 'Belum tersambung',
                  ),
                  _InfoTile(
                    icon: Icons.vpn_key_outlined,
                    label: 'Kode Unik Kos',
                    value: _profile?.kosAccessCode ?? 'Belum tersambung',
                  ),
                  _InfoTile(
                    icon: Icons.key_rounded,
                    label: 'Kode Unik Kamar',
                    value: _profile?.roomNumber ?? 'Belum tersambung',
                  ),
                  _InfoTile(
                    icon: Icons.meeting_room_outlined,
                    label: 'Kamar',
                    value: _roomLabel(_profile),
                  ),
                  const SizedBox(height: 18),
                  _ActionTile(
                    icon: Icons.favorite_border_rounded,
                    label: 'Favorite',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FavoriteMerchantsPage(),
                      ),
                    ),
                  ),
                  _ActionTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Tagihan Kos & Pembayaran Kos',
                    onTap: () {
                      Navigator.of(context)
                          .push<bool>(
                            MaterialPageRoute<bool>(
                              builder: (_) => const BillingListPage(),
                            ),
                          )
                          .then((changed) {
                        if (changed == true) _load();
                      });
                    },
                  ),
                  _ActionTile(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Riwayat Pesanan Merchant',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OrderHistoryPage(),
                      ),
                    ),
                  ),
                  _ActionTile(
                    icon: Icons.logout_rounded,
                    label: 'Keluar',
                    danger: true,
                    onTap: () {
                      auth.logout();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                  const UserBottomSpacer(),
                ],
              ),
            ),
    );
  }

  String _roomLabel(UserProfile? profile) {
    final number = profile?.roomNumber;
    final type = profile?.roomType;
    if ((number == null || number.isEmpty) && (type == null || type.isEmpty)) {
      return 'Belum ada kamar aktif';
    }
    return [
      if (number != null && number.isNotEmpty) 'No. $number',
      if (type != null && type.isNotEmpty) type,
    ].join(' - ');
  }

  bool _hasActiveRentForRoom(
    UserProfile? profile,
    String accessCode,
    String roomCode,
  ) {
    if (profile == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return profile.activeRentHistory.any((item) {
      if (item.status == 'pending') return false;
      if (item.kosAccessCode.toUpperCase() != accessCode.toUpperCase()) {
        return false;
      }
      if (item.roomNumber.toUpperCase() != roomCode.toUpperCase()) {
        return false;
      }
      final activeUntil = item.activeUntil;
      if (activeUntil == null) return false;
      final until = DateTime(activeUntil.year, activeUntil.month, activeUntil.day);
      return !until.isBefore(today);
    });
  }

}

class _ActiveRentBanner extends StatelessWidget {
  const _ActiveRentBanner({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final activeItems = _activeRentItems(profile);

    if (activeItems.isEmpty) {
      final hasRoom = (profile.roomNumber ?? '').isNotEmpty ||
          (profile.kosAccessCode ?? '').isNotEmpty;
      if (!hasRoom) return const SizedBox.shrink();
      return const _RentBannerShell(
        backgroundColor: Color(0xFFF3F4F6),
        iconColor: UserTheme.muted,
        icon: Icons.calendar_today_rounded,
        title: 'Belum ada masa sewa aktif',
        subtitle: 'Menunggu pembayaran atau persetujuan owner.',
        badge: 'Belum aktif',
      );
    }

    return Column(
      children: [
        for (var i = 0; i < activeItems.length; i++) ...[
          _bannerForRent(activeItems[i]),
          if (i != activeItems.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  List<ActiveRentHistory> _activeRentItems(UserProfile profile) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = profile.activeRentHistory.where((item) {
      if (item.status == 'pending') return true;
      final activeUntil = item.activeUntil;
      if (activeUntil == null) return false;
      final until = DateTime(activeUntil.year, activeUntil.month, activeUntil.day);
      return !until.isBefore(today);
    }).toList();

    items.sort((a, b) {
      if (a.status == 'pending' && b.status != 'pending') return -1;
      if (a.status != 'pending' && b.status == 'pending') return 1;
      final aDate = a.activeUntil ?? DateTime(9999);
      final bDate = b.activeUntil ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return items;
  }

  Widget _bannerForRent(ActiveRentHistory rent) {
    if (rent.status == 'pending') {
      return _RentBannerShell(
        backgroundColor: const Color(0xFFF3F4F6),
        iconColor: UserTheme.muted,
        icon: Icons.hourglass_top_rounded,
        title: 'Pengajuan kamar menunggu',
        subtitle: '${_rentLabel(rent)}\nBelum ada nominal tagihan sampai owner menyetujui.',
        badge: 'Pending',
      );
    }

    final activeUntil = rent.activeUntil;
    if (activeUntil == null) {
      return _RentBannerShell(
        backgroundColor: const Color(0xFFF3F4F6),
        iconColor: UserTheme.muted,
        icon: Icons.calendar_today_rounded,
        title: 'Belum ada masa sewa aktif',
        subtitle: _rentLabel(rent),
        badge: 'Belum aktif',
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final until = DateTime(activeUntil.year, activeUntil.month, activeUntil.day);
    final remainingDays = until.difference(today).inDays;
    final isExpired = remainingDays < 0;
    final isNearEnd = remainingDays >= 0 && remainingDays <= 7;

    final iconColor = isExpired
        ? UserTheme.danger
        : isNearEnd
            ? const Color(0xFFE66000)
            : UserTheme.primary;
    final backgroundColor = isExpired
        ? const Color(0xFFFFEBEB)
        : isNearEnd
            ? const Color(0xFFFFF4E5)
            : const Color(0xFFE8F5FF);

    return _RentBannerShell(
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      icon: isExpired
          ? Icons.warning_amber_rounded
          : isNearEnd
              ? Icons.timer_outlined
              : Icons.home_rounded,
      title: isExpired
          ? 'Masa sewa telah berakhir'
          : isNearEnd
              ? 'Masa sewa segera berakhir'
              : 'Masa sewa aktif',
      subtitle: 'Aktif sampai ${formatShortDate(activeUntil)}\n${_rentLabel(rent)}',
      badge: isExpired
          ? '${remainingDays.abs()} hari lalu'
          : remainingDays == 0
              ? 'Hari ini'
              : '$remainingDays hari lagi',
    );
  }

  String _rentLabel(ActiveRentHistory rent) {
    final parts = <String>[
      if (rent.kosName.trim().isNotEmpty) rent.kosName.trim(),
      if (rent.kosAccessCode.trim().isNotEmpty)
        'Kode kos: ${rent.kosAccessCode.trim()}',
      if (rent.roomNumber.trim().isNotEmpty)
        'Kode kamar: ${rent.roomNumber.trim()}',
    ];
    return parts.isEmpty ? 'Kos/kamar belum lengkap' : parts.join(' - ');
  }
}

class _RentBannerShell extends StatelessWidget {
  const _RentBannerShell({
    required this.backgroundColor,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  final Color backgroundColor;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: UserTheme.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RentHistorySection extends StatelessWidget {
  const _RentHistorySection({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final histories = _historyItems(profile.activeRentHistory);
    if (histories.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [UserTheme.softShadow(opacity: 0.05)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Masa Aktif Kos',
            style: TextStyle(
              color: UserTheme.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...histories.map((history) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          history.kosName.isEmpty
                              ? 'Kos'
                              : history.kosName,
                          style: const TextStyle(
                            color: UserTheme.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      'Kode kos: ${history.kosAccessCode}',
                      'Kamar: ${history.roomNumber}',
                      if (history.roomType.isNotEmpty) history.roomType,
                    ].join(' - '),
                    style: const TextStyle(
                      color: UserTheme.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    history.activeUntil == null
                        ? 'Belum ada masa aktif'
                        : 'Aktif sampai ${formatShortDate(history.activeUntil!)}',
                    style: const TextStyle(
                      color: UserTheme.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<ActiveRentHistory> _historyItems(List<ActiveRentHistory> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return items.where((item) {
      if (item.status == 'pending') return false;
      final activeUntil = item.activeUntil;
      if (activeUntil == null) return true;
      final until = DateTime(activeUntil.year, activeUntil.month, activeUntil.day);
      return until.isBefore(today);
    }).toList();
  }

}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.sessionName,
    required this.onTap,
  });

  final UserProfile? profile;
  final String? sessionName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayName ?? sessionName ?? 'User';
    final image = _profileImage(profile?.photoUrl);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [UserTheme.softShadow(opacity: 0.05)],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: UserTheme.softBlue,
                backgroundImage: image,
                child: image == null
                    ? Text(
                        name.isEmpty ? 'U' : name[0].toUpperCase(),
                        style: const TextStyle(
                          color: UserTheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: UserTheme.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile?.kosAccessCode ?? 'Kode kos belum tersambung',
                      style: const TextStyle(color: UserTheme.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: UserTheme.muted),
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider? _profileImage(String? photoUrl) {
    final value = photoUrl?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('data:image')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex == -1) return null;
      try {
        return MemoryImage(base64Decode(value.substring(commaIndex + 1)));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(value);
  }

}

class _KosCodeCard extends StatelessWidget {
  const _KosCodeCard({
    required this.accessCodeController,
    required this.roomCodeController,
    required this.isConnecting,
    required this.onConnect,
  });

  final TextEditingController accessCodeController;
  final TextEditingController roomCodeController;
  final bool isConnecting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [UserTheme.softShadow(opacity: 0.05)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kode Unik Kos',
            style: TextStyle(
              color: UserTheme.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: accessCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Masukkan kode kos',
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: roomCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Masukkan kode unik kamar (opsional)',
              labelText: 'Kode Unik Kamar',
              prefixIcon: const Icon(Icons.meeting_room_outlined),
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isConnecting ? null : onConnect,
              style: FilledButton.styleFrom(
                backgroundColor: UserTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(isConnecting ? 'Menyambungkan...' : 'Sambungkan Kos'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: UserTheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: UserTheme.muted)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: UserTheme.text,
                    fontWeight: FontWeight.w800,
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? UserTheme.danger : UserTheme.primaryDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(
            label,
            style: TextStyle(color: danger ? color : UserTheme.text),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
