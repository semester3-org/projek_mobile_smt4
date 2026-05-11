import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../auth/roles.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/user_profile.dart';
import '../user/user_theme.dart';

class UserProfileDetailPage extends StatefulWidget {
  const UserProfileDetailPage({super.key});

  @override
  State<UserProfileDetailPage> createState() => _UserProfileDetailPageState();
}

class _UserProfileDetailPageState extends State<UserProfileDetailPage> {
  UserProfile? _profile;
  bool _loading = true;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final session = AuthScope.of(context).session;
    final result = await UserRepository.getProfile(
      displayName: session?.displayName ?? 'User',
      email: session?.email ?? '',
      role: session?.role.label ?? 'User',
    );

    if (!mounted) return;
    setState(() {
      _profile = result.data ??
          UserProfile(
            id: '',
            email: session?.email ?? '',
            displayName: session?.displayName ?? 'User',
            role: session?.role.label ?? 'User',
          );
      _loading = false;
    });
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature akan segera tersedia')),
    );
  }

  String _roomLabel(UserProfile? profile) {
    final rooms = [
      if ((profile?.roomNumber ?? '').isNotEmpty) 'No ${profile!.roomNumber}',
      if ((profile?.roomType ?? '').isNotEmpty) profile!.roomType!,
    ];
    final label = rooms.join(' - ');
    return label.isEmpty ? 'Belum diisi' : label;
  }

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed[0].toUpperCase();
  }

  Widget _buildBody() {
    final profile = _profile;
    if (profile == null) {
      return const Center(child: Text('Profil belum tersedia'));
    }

    return RefreshIndicator(
      onRefresh: _loadUserProfile,
      color: UserTheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [UserTheme.softShadow(opacity: 0.05)],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: UserTheme.softBlue,
                  backgroundImage:
                      (profile.photoUrl == null || profile.photoUrl!.isEmpty)
                          ? null
                          : NetworkImage(profile.photoUrl!),
                  child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                      ? Text(
                          _initial(profile.displayName),
                          style: const TextStyle(
                            color: UserTheme.primary,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    color: UserTheme.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  profile.email,
                  style: const TextStyle(color: UserTheme.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: UserTheme.softBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    profile.role,
                    style: const TextStyle(
                      color: UserTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Informasi Pribadi'),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: profile.email.isEmpty ? '-' : profile.email,
          ),
          _InfoTile(
            icon: Icons.home_work_outlined,
            label: 'Nama Kos',
            value: profile.kosName ?? 'Belum tersambung',
          ),
          _InfoTile(
            icon: Icons.key_outlined,
            label: 'Kode Unik Kos',
            value: profile.kosAccessCode ?? 'Belum tersedia',
          ),
          _InfoTile(
            icon: Icons.bed_outlined,
            label: 'Kamar',
            value: _roomLabel(profile),
          ),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Nomor Telepon',
            value: profile.phone ?? 'Belum diisi',
          ),
          _InfoTile(
            icon: Icons.location_on_outlined,
            label: 'Alamat',
            value: profile.address ?? 'Belum diisi',
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Pengaturan'),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.edit_outlined,
            label: 'Edit Profil',
            onTap: () => _showComingSoon('Edit profil'),
          ),
          _ActionTile(
            icon: Icons.lock_outline,
            label: 'Ubah Kata Sandi',
            onTap: () => _showComingSoon('Ubah kata sandi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Profil Saya',
          style: TextStyle(
            color: UserTheme.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: UserTheme.text,
        fontWeight: FontWeight.w900,
        fontSize: 18,
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          leading: Icon(icon, color: UserTheme.primaryDark),
          title: Text(
            label,
            style: const TextStyle(color: UserTheme.text),
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
