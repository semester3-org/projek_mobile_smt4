import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/payment_methods.dart';
import '../../../../core/realtime_service.dart';
import '../../../../data/repositories/merchant_repository.dart';
import '../../../../models/merchant_models.dart';
import '../../merchant_ui.dart';

enum MerchantOrderDetailFocus { weighing }

class MerchantOrderDetailPage extends StatefulWidget {
  const MerchantOrderDetailPage({
    super.key,
    required this.isLaundry,
    required this.orderId,
    this.initialFocus,
  });

  final bool isLaundry;
  final String orderId;
  final MerchantOrderDetailFocus? initialFocus;

  @override
  State<MerchantOrderDetailPage> createState() =>
      _MerchantOrderDetailPageState();
}

class _MerchantOrderDetailPageState extends State<MerchantOrderDetailPage> {
  final _estimateCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _weighingKey = GlobalKey();
  MerchantOrder? _order;
  bool _loading = true;
  bool _loadingRequest = false;
  bool _saving = false;
  bool _previewing = false;
  bool _didApplyInitialFocus = false;
  String? _error;
  Timer? _previewDebounce;
  int _previewSerial = 0;
  final Set<String> _selectedAddonIds = {};
  double _laundrySubtotal = 0;
  double _laundryDiscount = 0;
  double _laundryFinalTotal = 0;
  String _laundryPromoName = '';

  @override
  void initState() {
    super.initState();
    _weightCtrl.addListener(_queueLaundryPreview);
    _load();
    RealtimeService()
        .addEventListener('merchant_order_updated', _silentRefresh);
    RealtimeService().startMerchantOrdersPolling();
  }

  @override
  void dispose() {
    RealtimeService()
        .removeEventListener('merchant_order_updated', _silentRefresh);
    RealtimeService().stopMerchantOrdersPolling();
    _previewDebounce?.cancel();
    _estimateCtrl.dispose();
    _weightCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_loadingRequest) return;
    _loadingRequest = true;
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
      _estimateCtrl.text = order?.estimatedTime ?? '';
      if (!silent) _error = result.error;
      _loading = false;
      _loadingRequest = false;
    });
    if (order != null && widget.isLaundry && !silent) {
      _syncLaundryDraft(order);
      _applyInitialFocus();
    }
  }

  void _silentRefresh() => _load(silent: true);

  void _applyInitialFocus() {
    if (_didApplyInitialFocus || widget.initialFocus == null) return;
    _didApplyInitialFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = switch (widget.initialFocus) {
        MerchantOrderDetailFocus.weighing => _weighingKey.currentContext,
        null => null,
      };
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  void _syncLaundryDraft(MerchantOrder order) {
    if (order.actualWeight != null && order.actualWeight! > 0) {
      _weightCtrl.text = _formatDecimal(order.actualWeight!);
    }
    _selectedAddonIds
      ..clear()
      ..addAll(order.selectedAddons.map((addon) => addon.id));
    _recalculateLaundryPreview(order, fetchPromo: false);
    _queueLaundryPreview();
  }

  void _queueLaundryPreview() {
    if (!widget.isLaundry || _order == null) return;
    _previewDebounce?.cancel();
    _previewDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _recalculateLaundryPreview(_order!, fetchPromo: true),
    );
  }

  Future<void> _recalculateLaundryPreview(
    MerchantOrder order, {
    required bool fetchPromo,
  }) async {
    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ?? 0;
    final subtotal = _calculateLaundrySubtotal(order, weight);
    final localTotal = subtotal;
    if (!mounted) return;
    setState(() {
      _laundrySubtotal = subtotal;
      _laundryDiscount = 0;
      _laundryFinalTotal = localTotal;
      _laundryPromoName = '';
      if (!fetchPromo || subtotal <= 0) _previewing = false;
    });
    final mainItem = _mainLaundryItem(order);
    final productId =
        mainItem == null ? null : int.tryParse(mainItem.productId);
    if (!fetchPromo || subtotal <= 0 || productId == null || productId <= 0) {
      return;
    }
    final serial = ++_previewSerial;
    setState(() => _previewing = true);
    final result = await MerchantRepository.previewPromo(
      subtotal: subtotal,
      productIds: [productId.toString()],
      userId: order.customerUserId,
    );
    if (!mounted || serial != _previewSerial) return;
    final data = result.data;
    setState(() {
      _previewing = false;
      if (result.isSuccess && data != null) {
        _laundryDiscount = (data['discountAmount'] as num?)?.toDouble() ?? 0;
        _laundryFinalTotal = (data['total'] as num?)?.toDouble() ?? subtotal;
        final promo = data['promo'];
        _laundryPromoName = promo is Map<String, dynamic>
            ? (promo['name'] as String? ?? '')
            : '';
      } else {
        _laundryFinalTotal = subtotal;
      }
    });
  }

  double _calculateLaundrySubtotal(MerchantOrder order, double weight) {
    if (weight <= 0) return 0;
    final main = _mainLaundryItem(order);
    if (main == null) return 0;
    var subtotal = _lineTotal(main.price, main.pricingType, weight);
    for (final addon in _selectedLaundryAddons(order)) {
      subtotal += _lineTotal(addon.price, addon.pricingType, weight);
    }
    return subtotal;
  }

  Iterable<MerchantLaundryAddon> _selectedLaundryAddons(MerchantOrder order) {
    final selectedIds = _selectedAddonIds.isNotEmpty
        ? _selectedAddonIds
        : order.selectedAddons.map((addon) => addon.id).toSet();
    final byId = {
      for (final addon in order.availableAddons) addon.id: addon,
    };
    final emitted = <String>{};
    final selected = <MerchantLaundryAddon>[];
    for (final id in selectedIds) {
      final addon = byId[id];
      if (addon == null) continue;
      selected.add(addon);
      emitted.add(id);
    }
    for (final addon in order.selectedAddons) {
      if (!selectedIds.contains(addon.id) || emitted.contains(addon.id)) {
        continue;
      }
      selected.add(addon);
    }
    return selected;
  }

  double _lineTotal(double price, String pricingType, double weight) {
    final qty = pricingType == 'per_kg' ? weight : 1.0;
    return price * qty;
  }

  MerchantOrderItem? _mainLaundryItem(MerchantOrder order) {
    for (final item in order.items) {
      if (!item.isAddon) return item;
    }
    return order.items.isEmpty ? null : order.items.first;
  }

  Future<void> _saveLaundryTotal() async {
    final order = _order;
    if (order == null) return;
    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    if (order.status == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terima pesanan terlebih dahulu')),
      );
      return;
    }
    if (weight == null || weight <= 0 || _laundryFinalTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi berat aktual agar total bisa dihitung'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final result = await MerchantRepository.updateOrder(
      id: order.id,
      laundryWeightKg: weight,
      laundryTotalAmount: _laundryFinalTotal,
      laundryAddonIds: _selectedAddonIds.toList(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result.data != null) _order = result.data;
    });
    if (result.data != null) {
      _syncLaundryDraft(result.data!);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Total pembayaran disimpan. User dapat melanjutkan pembayaran.'
              : result.error ?? 'Gagal menyimpan total',
        ),
      ),
    );
  }

  Future<void> _advanceLaundryOrder() async {
    final order = _order;
    if (order == null) return;
    final action = _laundryNextAction(order);
    if (action == null) return;
    if (!action.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action.helper)),
      );
      return;
    }
    setState(() => _saving = true);
    final result = await MerchantRepository.updateOrder(
      id: order.id,
      nextStatus: true,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result.data != null) _order = result.data;
    });
    if (result.data != null) _syncLaundryDraft(result.data!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isSuccess
            ? 'Pesanan ${order.code} diperbarui'
            : result.error ?? 'Gagal memperbarui pesanan'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return MerchantPage(
      topBar: const MerchantTopBar(
        title: 'Detail Pesanan',
        showAvatar: false,
        showBack: true,
      ),
      scrollController: _scrollCtrl,
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
          if (widget.isLaundry) ...[
            _LaundryOrderControlCard(
              order: order,
              saving: _saving,
              onAction: _advanceLaundryOrder,
            ),
            const SizedBox(height: 20),
            Container(
              key: _weighingKey,
              child: _LaundryWeighingCard(
                order: order,
                weightController: _weightCtrl,
                selectedAddonIds: _selectedAddonIds,
                subtotal: _laundrySubtotal,
                discount: _laundryDiscount,
                finalTotal: _laundryFinalTotal,
                promoName: _laundryPromoName,
                previewing: _previewing,
                saving: _saving,
                onConfirmTotal: _saveLaundryTotal,
              ),
            ),
            const SizedBox(height: 20),
            _PaymentCard(order: order),
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
          ] else ...[
            _CateringOperationalSummary(order: order),
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
          ],
          const MerchantBottomSpacer(),
        ],
      ],
    );
  }
}

class _LaundryOrderControlCard extends StatelessWidget {
  const _LaundryOrderControlCard({
    required this.order,
    required this.saving,
    required this.onAction,
  });

  final MerchantOrder order;
  final bool saving;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final action = _laundryNextAction(order);
    return MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.playlist_add_check_rounded,
            title: 'Kontrol Pesanan',
          ),
          const SizedBox(height: 18),
          _MerchantLaundryProgressBar(
            status: order.status,
            paymentStatus: order.paymentStatus,
            totalAmount: order.totalAmount,
          ),
          const SizedBox(height: 18),
          _CompactInfoPill(
            icon: Icons.flag_outlined,
            label: 'Status',
            value: order.statusLabel,
          ),
          if (order.estimatedFinishAt != null) ...[
            const SizedBox(height: 10),
            _CompactInfoPill(
              icon: Icons.event_available_outlined,
              label: 'Estimasi Selesai',
              value: _formatDateTime(order.estimatedFinishAt!),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            Text(
              action.helper,
              style: const TextStyle(
                color: MerchantPalette.muted,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving || !action.enabled ? null : onAction,
                child: Text(saving ? 'Memproses...' : action.label),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LaundryWeighingCard extends StatelessWidget {
  const _LaundryWeighingCard({
    required this.order,
    required this.weightController,
    required this.selectedAddonIds,
    required this.subtotal,
    required this.discount,
    required this.finalTotal,
    required this.promoName,
    required this.previewing,
    required this.saving,
    required this.onConfirmTotal,
  });

  final MerchantOrder order;
  final TextEditingController weightController;
  final Set<String> selectedAddonIds;
  final double subtotal;
  final double discount;
  final double finalTotal;
  final String promoName;
  final bool previewing;
  final bool saving;
  final VoidCallback onConfirmTotal;

  bool get _canEdit {
    final payment = order.paymentStatus.toLowerCase();
    return order.status != 'pending' &&
        order.statusGroup != 'cancelled' &&
        order.statusGroup != 'done' &&
        (payment == 'awaiting_weighing' || order.totalAmount <= 0);
  }

  bool get _hasFinalTotal {
    return order.totalAmount > 0 &&
        order.paymentStatus.toLowerCase() != 'awaiting_weighing';
  }

  @override
  Widget build(BuildContext context) {
    final mainItem = _firstServiceItem(order);
    final effectiveSubtotal = _hasFinalTotal
        ? (order.subtotalAmount > 0 ? order.subtotalAmount : order.totalAmount)
        : subtotal;
    final effectiveDiscount =
        _hasFinalTotal ? order.promoDiscountAmount : discount;
    final effectiveTotal = _hasFinalTotal ? order.totalAmount : finalTotal;
    final effectivePromoName = _hasFinalTotal ? order.promoName : promoName;
    final selectedFinalAddons =
        (_hasFinalTotal || order.selectedAddons.isNotEmpty)
            ? order.selectedAddons
            : order.availableAddons
                .where((addon) => selectedAddonIds.contains(addon.id))
                .toList();
    final actualWeight =
        double.tryParse(weightController.text.replaceAll(',', '.')) ??
            order.actualWeight ??
            0;
    final serviceSubtotal = mainItem == null
        ? 0.0
        : _hasFinalTotal && mainItem.subtotal > 0
            ? mainItem.subtotal
            : _pricingLineTotal(
                mainItem.price, mainItem.pricingType, actualWeight);
    final showPromoLine = effectiveDiscount > 0 ||
        previewing ||
        (!_hasFinalTotal && effectiveSubtotal > 0);
    final promoTitle =
        effectivePromoName.isEmpty ? 'Promo' : effectivePromoName;
    final promoSubtitle = effectiveDiscount > 0
        ? 'Potongan otomatis'
        : previewing
            ? 'Menghitung promo aktif...'
            : 'Belum ada promo yang memenuhi syarat';
    final promoPrice = effectiveDiscount > 0
        ? '- ${formatMerchantCurrency(effectiveDiscount)}'
        : '';

    return MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.scale_rounded,
            title: 'Penimbangan & Total Laundry',
          ),
          const SizedBox(height: 8),
          Text(
            _hasFinalTotal
                ? 'Total pembayaran telah ditentukan dan dikirim ke user.'
                : order.status == 'pending'
                    ? 'Terima pesanan terlebih dahulu sebelum input berat aktual.'
                    : 'Input berat aktual, lalu sistem menghitung subtotal, promo, dan total akhir.',
            style: const TextStyle(
              color: MerchantPalette.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (mainItem != null) ...[
            const SizedBox(height: 16),
            _PriceLine(
              title: mainItem.name,
              subtitle:
                  '${mainItem.pricingTypeLabel} - ${_itemPriceLabel(mainItem)}',
              price: _hasFinalTotal || serviceSubtotal > 0
                  ? formatMerchantCurrency(serviceSubtotal)
                  : '',
            ),
            if (selectedFinalAddons.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _TinyLabel(label: 'TAMBAHAN LAYANAN'),
              const SizedBox(height: 4),
              ...selectedFinalAddons.map(_AddonPriceLine.new),
            ],
          ],
          if (showPromoLine) ...[
            const SizedBox(height: 14),
            _PriceLine(
              title: promoTitle,
              subtitle: promoSubtitle,
              price: promoPrice,
            ),
          ],
          const SizedBox(height: 16),
          const _TinyLabel(label: 'BERAT AKTUAL'),
          const SizedBox(height: 8),
          TextField(
            controller: weightController,
            enabled: _canEdit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(hint: 'Contoh: 3.2 kg').copyWith(
              suffixText: 'kg',
            ),
          ),
          const Divider(height: 30),
          _PriceLine(
            title: 'Subtotal',
            subtitle: previewing ? 'Menghitung promo...' : 'Layanan + tambahan',
            price: effectiveSubtotal > 0
                ? formatMerchantCurrency(effectiveSubtotal)
                : 'Menunggu penimbangan',
          ),
          const Divider(height: 30),
          LayoutBuilder(
            builder: (context, constraints) {
              final value = effectiveTotal > 0
                  ? formatMerchantCurrency(effectiveTotal)
                  : 'Belum ditentukan';
              final tight = constraints.maxWidth < 330 || value.length > 18;
              const label = Text(
                'Total Akhir',
                style: TextStyle(
                  color: MerchantPalette.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              );
              final amount = Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: MerchantPalette.primary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              );
              if (tight) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerRight, child: amount),
                  ],
                );
              }
              return Row(
                children: [
                  const Expanded(child: label),
                  const SizedBox(width: 12),
                  amount,
                ],
              );
            },
          ),
          if (_canEdit) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving || finalTotal <= 0 ? null : onConfirmTotal,
                child: Text(
                  saving ? 'Menyimpan...' : 'Konfirmasi Total Laundry',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddonPriceLine extends StatelessWidget {
  const _AddonPriceLine(this.addon);

  final MerchantLaundryAddon addon;

  @override
  Widget build(BuildContext context) {
    final hasFinalSubtotal = addon.subtotal > 0;
    final title = hasFinalSubtotal
        ? addon.name
        : '${addon.name} (+${_addonPriceLabel(addon)})';
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8, right: 10),
            decoration: const BoxDecoration(
              color: MerchantPalette.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MerchantPalette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (hasFinalSubtotal) ...[
                  const SizedBox(height: 2),
                  Text(
                    _addonPriceLabel(addon),
                    style: const TextStyle(
                      color: MerchantPalette.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasFinalSubtotal) ...[
            const SizedBox(width: 10),
            Text(
              formatMerchantCurrency(addon.subtotal),
              style: const TextStyle(
                color: MerchantPalette.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _addonPriceLabel(MerchantLaundryAddon addon) {
  final unit = addon.unit.trim();
  if (addon.pricingType == 'flat' || unit == 'fixed' || unit.isEmpty) {
    return formatMerchantCurrency(addon.price);
  }
  return '${formatMerchantCurrency(addon.price)}$unit';
}

String _itemPriceLabel(MerchantOrderItem item) {
  final unit = item.unit.trim();
  if (item.pricingType == 'flat' || unit == 'fixed' || unit.isEmpty) {
    return formatMerchantCurrency(item.price);
  }
  return '${formatMerchantCurrency(item.price)}$unit';
}

class _LaundryAction {
  const _LaundryAction({
    required this.label,
    required this.helper,
    required this.enabled,
  });

  final String label;
  final String helper;
  final bool enabled;
}

_LaundryAction? _laundryNextAction(MerchantOrder order) {
  final payment = order.paymentStatus.toLowerCase();
  if (order.statusGroup == 'done' || order.statusGroup == 'cancelled') {
    return null;
  }
  if (order.status == 'pending') {
    return const _LaundryAction(
      label: 'Terima Pesanan',
      helper:
          'Konfirmasi bahwa pesanan diterima. Setelah itu lanjut ke penimbangan.',
      enabled: true,
    );
  }
  if (order.status == 'accepted' &&
      (payment == 'awaiting_weighing' || order.totalAmount <= 0)) {
    return const _LaundryAction(
      label: 'Isi Penimbangan',
      helper:
          'Lengkapi berat aktual dan total laundry pada section penimbangan.',
      enabled: false,
    );
  }
  if (order.status == 'accepted' &&
      (payment == 'waiting_payment' || payment == 'unpaid')) {
    return const _LaundryAction(
      label: 'Menunggu Pembayaran',
      helper:
          'Total akhir sudah dikirim. Tunggu user menyelesaikan pembayaran.',
      enabled: false,
    );
  }
  if (order.status == 'accepted' &&
      ['paid', 'payment_submitted', 'cod'].contains(payment)) {
    return const _LaundryAction(
      label: 'Mulai Proses Laundry',
      helper: 'Pembayaran sudah siap. Lanjutkan pesanan ke proses laundry.',
      enabled: true,
    );
  }
  if (order.status == 'processing') {
    return const _LaundryAction(
      label: 'Tandai Siap Diantar',
      helper: 'Gunakan setelah laundry selesai diproses dan siap dikirim.',
      enabled: true,
    );
  }
  if (order.status == 'delivered') {
    return const _LaundryAction(
      label: 'Tandai Selesai',
      helper: 'Gunakan setelah pesanan sudah diterima pelanggan.',
      enabled: true,
    );
  }
  return const _LaundryAction(
    label: 'Kelola Pesanan',
    helper: 'Ikuti langkah operasional berikutnya sesuai status pesanan.',
    enabled: true,
  );
}

MerchantOrderItem? _firstServiceItem(MerchantOrder order) {
  for (final item in order.items) {
    if (!item.isAddon) return item;
  }
  return order.items.isEmpty ? null : order.items.first;
}

double _pricingLineTotal(double price, String pricingType, double weight) {
  if (weight <= 0) return 0;
  return price * (pricingType == 'per_kg' ? weight : 1.0);
}

String _formatDecimal(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed
      .replaceFirst(RegExp(r'\.00$'), '')
      .replaceFirst(RegExp(r'0$'), '');
}

class _CateringOperationalSummary extends StatelessWidget {
  const _CateringOperationalSummary({required this.order});

  final MerchantOrder order;

  @override
  Widget build(BuildContext context) {
    final period =
        '${_formatDate(order.subscriptionStartDate)} - ${_formatDate(order.subscriptionEndDate)}';
    return MerchantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.restaurant_menu_rounded,
            title: 'Ringkasan Operasional',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CompactInfoPill(
                icon: Icons.flag_outlined,
                label: 'Pesanan',
                value: order.statusLabel,
              ),
              _CompactInfoPill(
                icon: Icons.payments_outlined,
                label: 'Pembayaran',
                value: order.paymentStatusLabel.isEmpty
                    ? 'Menunggu pembayaran'
                    : order.paymentStatusLabel,
              ),
              _CompactInfoPill(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Metode',
                value: PaymentMethodHelper.getDisplayName(
                  order.paymentMethod.isEmpty ? null : order.paymentMethod,
                ),
              ),
              if (order.isCateringSubscription) ...[
                _CompactInfoPill(
                  icon: Icons.calendar_month_outlined,
                  label: 'Durasi',
                  value: '${order.subscriptionDays ?? 0} hari',
                ),
                _CompactInfoPill(
                  icon: Icons.event_available_outlined,
                  label: 'Periode',
                  value: period,
                ),
                _CompactInfoPill(
                  icon: Icons.verified_outlined,
                  label: 'Langganan',
                  value: _subscriptionStatusLabel(
                    order.subscriptionStatus ?? '',
                  ),
                ),
              ],
            ],
          ),
          if (!order.canApprove ||
              order.isSubscriptionCancellationRequested) ...[
            const SizedBox(height: 14),
            _PaymentNotice(
              canApprove: order.canApprove,
              message: order.isSubscriptionCancellationRequested
                  ? 'User sudah membatalkan langganan. Layanan tetap berjalan sampai tanggal berakhir.'
                  : null,
            ),
          ],
        ],
      ),
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
            OutlinedButton.icon(
              onPressed: () => _openMap(latitude!, longitude!),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Lihat di Peta'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
        if (order.paymentStatus.toLowerCase() == 'paid' &&
            order.paidAt != null) ...[
          const SizedBox(height: 12),
          _PaymentMeta(
            label: 'DIBAYAR PADA',
            value: _formatDateTime(order.paidAt!),
          ),
        ],
        if (order.midtransOrderId != null &&
            order.midtransOrderId!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _PaymentMeta(
            label: 'REFERENSI MIDTRANS',
            value: order.midtransOrderId!,
          ),
        ],
        const SizedBox(height: 12),
        _PaymentNotice(
          canApprove: order.canApprove,
          message: order.serviceType == 'laundry'
              ? _laundryPaymentNotice(order)
              : null,
        ),
      ],
    );
  }
}

Future<void> _openMap(double latitude, double longitude) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _laundryPaymentNotice(MerchantOrder order) {
  final payment = order.paymentStatus.toLowerCase();
  if (payment == 'awaiting_weighing' || order.totalAmount <= 0) {
    return 'Pembayaran menunggu total akhir dari penimbangan laundry.';
  }
  if (payment == 'waiting_payment' || payment == 'unpaid') {
    return 'Total akhir sudah dikirim. User perlu menyelesaikan pembayaran.';
  }
  if (payment == 'cod') {
    return 'Metode COD. Status pembayaran tetap belum dibayar sampai diterima pelanggan.';
  }
  return 'Pembayaran sudah masuk. Pesanan dapat diproses sesuai workflow laundry.';
}

class _CompactInfoPill extends StatelessWidget {
  const _CompactInfoPill({
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
      constraints: const BoxConstraints(minWidth: 128),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EAF3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: MerchantPalette.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPalette.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPalette.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
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

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: MerchantPalette.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: MerchantPalette.text,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.2,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: MerchantPalette.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: MerchantPalette.muted,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ],
        );

        if (price.isEmpty) return titleColumn;

        final priceText = Text(
          price,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: MerchantPalette.text,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        );

        if (constraints.maxWidth < 330 || price.length > 16) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: priceText),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleColumn),
            const SizedBox(width: 12),
            priceText,
          ],
        );
      },
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
  const _MerchantLaundryProgressBar({
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
  });

  final String status;
  final String paymentStatus;
  final double totalAmount;

  static const _steps = [
    ('pending', 'Konfirmasi'),
    ('accepted', 'Diterima'),
    ('weighing', 'Timbang'),
    ('payment', 'Bayar'),
    ('processing', 'Proses'),
    ('delivered', 'Antar'),
    ('done', 'Selesai'),
  ];

  int get _index {
    final payment = paymentStatus.toLowerCase();
    switch (status) {
      case 'accepted':
        if (payment == 'awaiting_weighing' || totalAmount <= 0) return 2;
        if (payment == 'waiting_payment' || payment == 'unpaid') return 3;
        return 3;
      case 'processing':
        return 4;
      case 'delivered':
        return 5;
      case 'done':
        return 6;
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
                margin:
                    EdgeInsets.only(right: index == _steps.length - 1 ? 0 : 6),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        step.$2,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: current >= _steps.indexOf(step)
                              ? MerchantPalette.primary
                              : MerchantPalette.muted,
                        ),
                      ),
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
