import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/api_service.dart';
class OwnerTenantsPage extends StatefulWidget {
  const OwnerTenantsPage({super.key});

  @override
  State<OwnerTenantsPage> createState() => _OwnerTenantsPageState();
}

class _OwnerTenantsPageState extends State<OwnerTenantsPage> {
  List<OwnerTenant> _tenants = [];
  final Set<String> _updatingIds = <String>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await ApiService.get('api/owner_tenants');
    if (!mounted) return;

    if (!res.success) {
      setState(() {
        _loading = false;
        _error = res.message ?? 'Gagal memuat penghuni';
      });
      return;
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => OwnerTenant.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _tenants = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Gagal membaca data penghuni';
      });
    }
  }

  Future<bool> _updateTenantStatus(
    OwnerTenant tenant,
    String newStatus,
  ) async {
    if (_updatingIds.contains(tenant.registrationId)) return false;
    setState(() => _updatingIds.add(tenant.registrationId));

    final res = await ApiService.put(
      'api/owner_tenants',
      {
        'registrationId': tenant.registrationId,
        'status': newStatus,
      },
    );

    if (!mounted) return false;
    setState(() => _updatingIds.remove(tenant.registrationId));

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Gagal memperbarui status penghuni'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    setState(() {
      _tenants = _tenants.map((item) {
        if (item.registrationId != tenant.registrationId) return item;
        return item.copyWith(
          status: newStatus,
          startDate: newStatus == 'approved'
              ? (item.startDate ?? DateTime.now().toIso8601String())
              : item.startDate,
        );
      }).toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus == 'approved'
              ? 'Pengajuan kamar disetujui'
              : 'Pengajuan kamar ditolak',
        ),
      ),
    );
    return true;
  }

  void _showDetail(OwnerTenant tenant) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(name: tenant.name, radius: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenant.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tenant.email,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _KosBadge(tenant: tenant),
                const SizedBox(height: 18),
                _DetailRow(label: 'Nama Kos', value: tenant.kosName),
                _DetailRow(label: 'Kode Kos', value: tenant.kosAccessCode),
                _DetailRow(label: 'Nomor Kamar', value: tenant.roomNumber),
                _DetailRow(label: 'Tipe Kamar', value: tenant.roomType),
                _DetailRow(label: 'Status', value: tenant.statusLabel),
                _DetailRow(label: 'Harga Kamar', value: _formatPrice(tenant.roomPrice)),
                if (tenant.startDate != null)
                  _DetailRow(label: 'Mulai Sewa', value: tenant.startDate!),
                if (tenant.status == 'pending') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _updatingIds.contains(tenant.registrationId)
                              ? null
                              : () async {
                                  final ok = await _updateTenantStatus(
                                    tenant,
                                    'rejected',
                                  );
                                  if (ok && mounted) Navigator.of(context).pop();
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                          ),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _updatingIds.contains(tenant.registrationId)
                              ? null
                              : () async {
                                  final ok = await _updateTenantStatus(
                                    tenant,
                                    'approved',
                                  );
                                  if (ok && mounted) Navigator.of(context).pop();
                                },
                          child: const Text('Setujui'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(title: const Text('Penghuni')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryGreen,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 80),
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_tenants.isEmpty)
                        const _EmptyTenants()
                      else
                        ..._tenants.map(
                          (tenant) => _TenantTile(
                            tenant: tenant,
                            isUpdating: _updatingIds.contains(
                              tenant.registrationId,
                            ),
                            onTap: () => _showDetail(tenant),
                            onApprove: () => _updateTenantStatus(
                              tenant,
                              'approved',
                            ),
                            onReject: () => _updateTenantStatus(
                              tenant,
                              'rejected',
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class OwnerTenant {
  const OwnerTenant({
    required this.registrationId,
    required this.userId,
    required this.name,
    required this.email,
    required this.kosId,
    required this.kosName,
    required this.kosAccessCode,
    required this.roomNumber,
    required this.roomType,
    required this.roomPrice,
    required this.status,
    this.startDate,
  });

  final String registrationId;
  final String userId;
  final String name;
  final String email;
  final String kosId;
  final String kosName;
  final String kosAccessCode;
  final String roomNumber;
  final String roomType;
  final double roomPrice;
  final String status;
  final String? startDate;

  factory OwnerTenant.fromJson(Map<String, dynamic> json) {
    return OwnerTenant(
      registrationId: json['registrationId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? 'User',
      email: json['email'] as String? ?? '',
      kosId: json['kosId'] as String? ?? '',
      kosName: json['kosName'] as String? ?? '',
      kosAccessCode: json['kosAccessCode'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? '',
      roomType: json['roomType'] as String? ?? '',
      roomPrice: (json['roomPrice'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'active',
      startDate: json['startDate'] as String?,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'approved':
        return 'Disetujui';
      case 'pending':
        return 'Menunggu';
      case 'rejected':
        return 'Ditolak';
      case 'ended':
        return 'Selesai';
      default:
        return status;
    }
  }

  OwnerTenant copyWith({
    String? status,
    String? startDate,
  }) {
    return OwnerTenant(
      registrationId: registrationId,
      userId: userId,
      name: name,
      email: email,
      kosId: kosId,
      kosName: kosName,
      kosAccessCode: kosAccessCode,
      roomNumber: roomNumber,
      roomType: roomType,
      roomPrice: roomPrice,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
    );
  }
}

class _TenantTile extends StatelessWidget {
  const _TenantTile({
    required this.tenant,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    this.isUpdating = false,
  });

  final OwnerTenant tenant;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    final canAction = tenant.status == 'pending' && !isUpdating;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Avatar(name: tenant.name),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kamar ${tenant.roomNumber} - ${tenant.statusLabel}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    _KosBadge(tenant: tenant, compact: true),
                    if (tenant.status == 'pending') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: canAction ? onReject : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                              ),
                              child: const Text('Tolak'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: canAction ? onApprove : null,
                              child: isUpdating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Setujui'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _KosBadge extends StatelessWidget {
  const _KosBadge({required this.tenant, this.compact = false});

  final OwnerTenant tenant;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 9,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.home_work_outlined, size: 16, color: AppTheme.primaryGreen),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              compact
                  ? tenant.kosName
                  : '${tenant.kosName} - ${tenant.kosAccessCode}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.radius = 22});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.surfaceTint,
      child: Text(
        name.trim().isEmpty ? 'U' : name.trim()[0].toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primaryGreen,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTenants extends StatelessWidget {
  const _EmptyTenants();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 54, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          const Text(
            'Belum ada penghuni terhubung.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Bagikan kode kos ke user agar mereka bisa tersambung.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

String _formatPrice(double value) {
  final text = value.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = text.length - 1, group = 0; i >= 0; i--, group++) {
    if (group > 0 && group % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(text[i]);
  }
  return 'Rp ${buffer.toString().split('').reversed.join()}';
}
