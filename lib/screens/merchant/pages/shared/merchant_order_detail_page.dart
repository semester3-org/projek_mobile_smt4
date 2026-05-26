import 'package:flutter/material.dart';

import '../../../../core/payment_methods.dart';
import '../../../../core/realtime_service.dart';
import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/merchant_models.dart';
import '../../merchant_ui.dart';

class MerchantOrderDetailPage extends StatefulWidget {
  const MerchantOrderDetailPage({
    super.key,
    required this.isLaundry,
    required this.orderId,
  });

  final bool isLaundry;
  final String orderId;

  @override
  State<MerchantOrderDetailPage> createState() =>
      _MerchantOrderDetailPageState();
}

class _MerchantOrderDetailPageState extends State<MerchantOrderDetailPage> {
  final _estimateCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _laundryTotalCtrl = TextEditingController();
  MerchantOrder? _order;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _status = 'pending';

  static const _laundryStatuses = [
    ('pending', 'Pending'),
    ('accepted', 'Diterima'),
    ('processing', 'Diproses'),
    ('delivered', 'Pengiriman'),
    ('done', 'Selesai'),
  ];

  static const _cateringStatuses = [
    ('pending', 'Pending'),
    ('accepted', 'Disetujui'),
    ('done', 'Selesai'),
  ];

  List<(String, String)> get _statuses =>
      widget.isLaundry ? _laundryStatuses : _cateringStatuses;

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeService().addEventListener('merchant_order_updated', _silentRefresh);
    RealtimeService().startMerchantOrdersPolling();
  }

  @override
  void dispose() {
    RealtimeService().removeEventListener('merchant_order_updated', _silentRefresh);
    _estimateCtrl.dispose();
    _weightCtrl.dispose();
    _laundryTotalCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final result = await MerchantRepository.getOrderDetail(widget.orderId);
    if (!mounted) return;
    final order = result.data;
    setState(() {
      _order = order;
      _status = order?.status ?? 'pending';
      _estimateCtrl.text = order?.estimatedTime ?? '';
      if (!silent) _error = result.error;
      _loading = false;
    });
  }

  void _silentRefresh() => _load(silent: true);

  Future<void> _saveLaundryTotal() async {
    final order = _order;
    if (order == null) return;
    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    final total = double.tryParse(_laundryTotalCtrl.text.replaceAll(',', '.'));
    if (weight == null || weight <= 0 || total == null || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi berat (kg) dan total bayar dengan benar')),
      );
      return;
    }
    setState(() => _saving = true);
    final result = await MerchantRepository.updateOrder(
      id: order.id,
      laundryWeightKg: weight,
      laundryTotalAmount: total,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result.data != null) _order = result.data;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Total laundry disimpan. User dapat melanjutkan pembayaran.'
              : result.error ?? 'Gagal menyimpan total',
        ),
      ),
    );
  }

  Future<void> _save() async {
    final order = _order;
    if (order == null) return;
    setState(() => _saving = true);
    final result = await MerchantRepository.updateOrder(
      id: order.id,
      status: _status,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result.data != null) {
        _order = result.data;
        _status = result.data!.status;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isSuccess
            ? 'Pesanan berhasil diperbarui'
            : result.error ?? 'Gagal memperbarui pesanan'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return MerchantPage(
      topBar: MerchantTopBar(
        title: 'Detail Pesanan',
        showAvatar: false,
        showBack: true,
        actionLabel: _saving ? 'Menyimpan...' : 'Simpan',
        onAction: _saving || order == null ? null : _save,
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 120),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          MerchantCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_error!,
                    style: const TextStyle(color: MerchantPalette.danger)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Muat Ulang')),
              ],
            ),
          )
        else if (order != null) ...[
          _OrderHeaderCard(order: order),
          const SizedBox(height: 20),
          MerchantCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardTitle(
                  icon: Icons.tune_rounded,
                  title: 'Kontrol Pesanan',
                ),
                const SizedBox(height: 18),
                const _TinyLabel(label: 'STATUS PESANAN'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  items: _statuses
                      .map((item) => DropdownMenuItem(
                            value: item.$1,
                            child: Text(item.$2),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                  decoration: _inputDecoration(),
                ),
                if (widget.isLaundry) ...[
                  const SizedBox(height: 18),
                  _MerchantLaundryProgressBar(status: _status),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _InfoCard(
            icon: Icons.person_rounded,
            title: 'Pelanggan',
            children: [
              Text(
                order.customerName,
                style: const TextStyle(
                  color: MerchantPalette.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (order.customerPhone.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  order.customerPhone,
                  style: const TextStyle(
                    color: MerchantPalette.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _AddressCard(
            address: order.deliveryAddress,
            latitude: order.deliveryLatitude,
            longitude: order.deliveryLongitude,
          ),
          const SizedBox(height: 20),
          _ItemsCard(order: order, isLaundry: widget.isLaundry),
          if (widget.isLaundry &&
              (order.paymentStatus.toLowerCase() == 'awaiting_weighing' ||
                  order.totalAmount <= 0)) ...[
            const SizedBox(height: 20),
            MerchantCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CardTitle(
                    icon: Icons.scale_rounded,
                    title: 'Timbang & Total Bayar',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Setelah cucian selesai, masukkan berat aktual (kg) dan total yang harus dibayar user.',
                    style: TextStyle(
                      color: MerchantPalette.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _TinyLabel(label: 'BERAT (KG)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration(hint: 'Contoh: 3.5'),
                  ),
                  const SizedBox(height: 14),
                  const _TinyLabel(label: 'TOTAL BAYAR (RP)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _laundryTotalCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration(hint: 'Contoh: 52500'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveLaundryTotal,
                      child: Text(_saving ? 'Menyimpan...' : 'Simpan Total'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.isCateringSubscription) ...[
            const SizedBox(height: 20),
            _SubscriptionCard(order: order),
          ],
          const SizedBox(height: 20),
          _PaymentCard(order: order),
          const MerchantBottomSpacer(),
        ],
      ],
    );
  }
}

class _OrderHeaderCard extends StatelessWidget {
  const _OrderHeaderCard({required this.order});

  final MerchantOrder order;

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
                const _TinyLabel(label: 'KODE UNIK PESANAN'),
                const SizedBox(height: 6),
                Text(
                  order.code,
                  style: const TextStyle(
                    color: MerchantPalette.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatDateTime(order.createdAt),
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
            label: order.statusLabel,
            color: _statusColor(order.statusGroup),
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
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String address;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.location_on_rounded,
            title: 'Alamat Tujuan',
          ),
          const SizedBox(height: 14),
          Text(
            address.isEmpty ? 'Alamat belum diisi' : address,
            style: const TextStyle(
              color: MerchantPalette.muted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 12),
            Text(
              'Koordinat: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
              style: const TextStyle(
                color: MerchantPalette.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order, required this.isLaundry});

  final MerchantOrder order;
  final bool isLaundry;

  @override
  Widget build(BuildContext context) {
    return MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: isLaundry
                ? Icons.local_laundry_service_outlined
                : Icons.restaurant_rounded,
            title: isLaundry ? 'Detail Layanan' : 'Daftar Pesanan',
          ),
          const SizedBox(height: 18),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _PriceLine(
                title: item.name,
                subtitle:
                    '${item.quantity} x ${formatMerchantCurrency(item.price)}',
                price: formatMerchantCurrency(item.subtotal),
              ),
            ),
          ),
          const Divider(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Pembayaran',
                  style: TextStyle(
                    color: MerchantPalette.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                formatMerchantCurrency(order.totalAmount),
                style: const TextStyle(
                  color: MerchantPalette.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});

  final MerchantOrder order;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.receipt_long_rounded,
      title: 'Pembayaran',
      children: [
        _PaymentMeta(
          label: 'METODE PEMBAYARAN',
          value: PaymentMethodHelper.getDisplayName(
              order.paymentMethod.isEmpty ? null : order.paymentMethod),
        ),
        const SizedBox(height: 12),
        _PaymentMeta(
          label: 'STATUS PEMBAYARAN',
          value: order.paymentStatusLabel.isEmpty
              ? 'Menunggu pembayaran'
              : order.paymentStatusLabel,
        ),
        const SizedBox(height: 12),
        _PaymentNotice(canApprove: order.canApprove),
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.order});

  final MerchantOrder order;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.calendar_month_outlined,
      title: 'Langganan Catering',
      children: [
        _PaymentMeta(
          label: 'DURASI',
          value: '${order.subscriptionDays ?? 0} hari',
        ),
        const SizedBox(height: 12),
        _PaymentMeta(
          label: 'PERIODE',
          value:
              '${_formatDate(order.subscriptionStartDate)} - ${_formatDate(order.subscriptionEndDate)}',
        ),
        const SizedBox(height: 12),
        _PaymentMeta(
          label: 'STATUS LANGGANAN',
          value: _subscriptionStatusLabel(order.subscriptionStatus ?? ''),
        ),
        if (order.isSubscriptionCancellationRequested) ...[
          const SizedBox(height: 12),
          const _PaymentNotice(
            canApprove: true,
            message:
                'User sudah membatalkan langganan. Layanan tetap berjalan sampai tanggal berakhir.',
          ),
        ],
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

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
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(width: 12),
        Text(
          price,
          style: const TextStyle(
            color: MerchantPalette.text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PaymentMeta extends StatelessWidget {
  const _PaymentMeta({required this.label, required this.value});

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
  const _PaymentNotice({
    required this.canApprove,
    this.message,
  });

  final bool canApprove;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
              canApprove
                  ? Icons.notifications_active_outlined
                  : Icons.hourglass_top_rounded,
              color: MerchantPalette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message ??
                  (canApprove
                      ? 'Pembayaran sudah bisa diverifikasi. Merchant dapat approve dan memproses pesanan.'
                      : 'Pesanan non-COD baru bisa di-approve setelah user mengonfirmasi pembayaran.'),
              style: const TextStyle(
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

InputDecoration _inputDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: MerchantPalette.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: MerchantPalette.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: MerchantPalette.primary, width: 1.4),
    ),
  );
}

Color _statusColor(String group) {
  switch (group) {
    case 'pending':
      return MerchantPalette.danger;
    case 'done':
      return MerchantPalette.success;
    default:
      return const Color(0xFF1D4ED8);
  }
}

String _formatDateTime(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

String _formatDate(DateTime? date) {
  if (date == null) return '-';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

class _MerchantLaundryProgressBar extends StatelessWidget {
  const _MerchantLaundryProgressBar({required this.status});

  final String status;

  static const _steps = [
    ('pending', 'Menunggu'),
    ('accepted', 'Diterima'),
    ('processing', 'Diproses'),
    ('delivered', 'Antar'),
    ('done', 'Selesai'),
  ];

  int get _index {
    switch (status) {
      case 'accepted':
        return 1;
      case 'processing':
        return 2;
      case 'delivered':
        return 3;
      case 'done':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TinyLabel(label: 'PROGRES PESANAN'),
        const SizedBox(height: 10),
        Row(
          children: List.generate(_steps.length, (index) {
            final active = current >= index;
            return Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(right: index == _steps.length - 1 ? 0 : 6),
                decoration: BoxDecoration(
                  color: active
                      ? MerchantPalette.primary
                      : const Color(0xFFE3E9F3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: _steps
              .map(
                (step) => Expanded(
                  child: Text(
                    step.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: current >= _steps.indexOf(step)
                          ? MerchantPalette.primary
                          : MerchantPalette.muted,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

String _subscriptionStatusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Aktif';
    case 'cancel_requested':
      return 'Dibatalkan, aktif sampai selesai';
    case 'ended':
      return 'Selesai';
    case 'pending_payment':
      return 'Menunggu pembayaran';
    default:
      return status.isEmpty ? '-' : status;
  }
}
