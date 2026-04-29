import 'package:flutter/material.dart';

import '../../data/repositories/user_repository.dart';
import '../../models/billing_record.dart';
import '../user/user_theme.dart';
import '../user/user_widgets.dart';
import 'billing_detail_page.dart';

class BillingListPage extends StatefulWidget {
  const BillingListPage({super.key});

  @override
  State<BillingListPage> createState() => _BillingListPageState();
}

class _BillingListPageState extends State<BillingListPage> {
  List<BillingRecord> _billings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await UserRepository.getBillings();
    if (!mounted) return;
    setState(() {
      _billings = result.data ?? [];
      _error = result.error;
      _loading = false;
    });
  }

  BillingRecord? get _activeBill {
    for (final billing in _billings) {
      if (billing.status != 'lunas') return billing;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final activeBill = _activeBill;

    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Tagihan Anda',
          style: TextStyle(
            color: UserTheme.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: CircleAvatar(
              backgroundColor: UserTheme.primaryDark,
              child: Icon(Icons.person, color: Colors.white),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: UserTheme.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 32),
                children: [
                  if (_error != null) ...[
                    _InfoMessage(message: _error!),
                    const SizedBox(height: 18),
                  ],
                  if (activeBill != null) _ActiveBillingCard(billing: activeBill),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Text(
                        'Riwayat Tagihan',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: UserTheme.text,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.filter_list_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_billings.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Belum ada tagihan.',
                          style: TextStyle(color: UserTheme.muted),
                        ),
                      ),
                    )
                  else
                    ..._billings.map(
                      (billing) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _BillingHistoryCard(billing: billing),
                      ),
                    ),
                  const SizedBox(height: 14),
                  const _HelpCard(),
                  const UserBottomSpacer(),
                ],
              ),
      ),
    );
  }
}

class _ActiveBillingCard extends StatelessWidget {
  const _ActiveBillingCard({required this.billing});

  final BillingRecord billing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B63B6), Color(0xFF004B86)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [UserTheme.softShadow(opacity: 0.14)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Tagihan Aktif',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white.withOpacity(0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatUserCurrency(billing.amount),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 22),
          if ((billing.kosName ?? '').isNotEmpty) ...[
            Text(
              billing.kosName!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if ((billing.kosAccessCode ?? '').isNotEmpty)
                  billing.kosAccessCode!,
                if ((billing.roomNumber ?? '').isNotEmpty)
                  'Kamar ${billing.roomNumber}',
                if ((billing.roomType ?? '').isNotEmpty) billing.roomType!,
              ].join(' - '),
              style: TextStyle(color: Colors.white.withOpacity(0.76)),
            ),
            const SizedBox(height: 18),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Jatuh tempo: ${formatShortDate(billing.dueDate)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BillingDetailPage(billing: billing),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Bayar Sekarang'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: UserTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingHistoryCard extends StatelessWidget {
  const _BillingHistoryCard({required this.billing});

  final BillingRecord billing;

  @override
  Widget build(BuildContext context) {
    final paid = billing.status == 'lunas';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BillingDetailPage(billing: billing),
            ),
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [UserTheme.softShadow(opacity: 0.04)],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      paid ? const Color(0xFFE6FAEF) : const Color(0xFFFFF1E4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  paid ? Icons.check_circle : Icons.error,
                  color: paid ? UserTheme.success : const Color(0xFFE66000),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      billing.itemDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: UserTheme.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if ((billing.kosName ?? '').isNotEmpty)
                          billing.kosName!,
                        if ((billing.roomNumber ?? '').isNotEmpty)
                          'Kamar ${billing.roomNumber}',
                        if ((billing.roomType ?? '').isNotEmpty)
                          billing.roomType!,
                      ].join(' - '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: UserTheme.muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatUserCurrency(billing.amount),
                    style: const TextStyle(
                      color: UserTheme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: paid
                          ? const Color(0xFFD9F9E7)
                          : const Color(0xFFFFEBD1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      paid ? 'Lunas' : 'Belum Bayar',
                      style: TextStyle(
                        color: paid ? UserTheme.success : const Color(0xFFE66000),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD9A6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFE66000)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: UserTheme.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD5E6FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline_rounded, color: UserTheme.accent),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Butuh Bantuan?',
                  style: TextStyle(
                    color: UserTheme.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Hubungi admin jika terdapat ketidaksesuaian pada rincian tagihan Anda.',
                  style: TextStyle(
                    color: Color(0xFF6078D8),
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'Ajukan Komplain >',
                  style: TextStyle(
                    color: UserTheme.accent,
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
