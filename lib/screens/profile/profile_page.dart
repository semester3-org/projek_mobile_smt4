import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../auth/roles.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/user_profile.dart';
import '../user/user_theme.dart';
import '../user/user_widgets.dart';
import 'billing_list_page.dart';
import 'notification_list_page.dart';
import 'order_history_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _codeCtrl = TextEditingController();
  UserProfile? _profile;
  bool _loading = true;
  bool _connecting = false;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
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
      _loading = false;
    });
  }

  Future<void> _connectCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan kode unik kos terlebih dahulu')),
      );
      return;
    }

    setState(() => _connecting = true);
    final result = await UserRepository.connectKosCode(code);
    if (!mounted) return;
    setState(() => _connecting = false);

    if (result.isSuccess) {
      setState(() => _profile = result.data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode kos berhasil disambungkan')),
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
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationListPage(),
                ),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded),
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
                  ),
                  const SizedBox(height: 18),
                  _KosCodeCard(
                    controller: _codeCtrl,
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
                    icon: Icons.meeting_room_outlined,
                    label: 'Kamar',
                    value: _roomLabel(_profile),
                  ),
                  const SizedBox(height: 18),
                  _ActionTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Tagihan & Pembayaran',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BillingListPage(),
                      ),
                    ),
                  ),
                  _ActionTile(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Riwayat Pesanan',
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
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.sessionName});

  final UserProfile? profile;
  final String? sessionName;

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayName ?? sessionName ?? 'User';
    final photoUrl = profile?.photoUrl;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [UserTheme.softShadow(opacity: 0.05)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: UserTheme.softBlue,
            backgroundImage: photoUrl == null || photoUrl.isEmpty
                ? null
                : NetworkImage(photoUrl),
            child: photoUrl == null || photoUrl.isEmpty
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
        ],
      ),
    );
  }
}

class _KosCodeCard extends StatelessWidget {
  const _KosCodeCard({
    required this.controller,
    required this.isConnecting,
    required this.onConnect,
  });

  final TextEditingController controller;
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
            controller: controller,
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
