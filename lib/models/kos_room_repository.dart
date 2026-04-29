import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../models/kos_room.dart'; // lib/screens/owner/pages/ → lib/models/

class OwnerRoomsPage extends StatefulWidget {
  const OwnerRoomsPage({
    super.key,
    required this.kosId,
    required this.kosTitle,
  });

  final String kosId;
  final String kosTitle;

  @override
  State<OwnerRoomsPage> createState() => _OwnerRoomsPageState();
}

class _OwnerRoomsPageState extends State<OwnerRoomsPage> {
  List<KosRoom> _rooms = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _query = '';
  RoomStatus? _statusFilter;
  String _sortBy = 'room_number_asc';

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await KosRoomRepository.getRooms(
      widget.kosId,
      statusFilter: _statusFilter?.dbValue,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() { _rooms = result.data!; _isLoading = false; });
    } else {
      setState(() { _errorMessage = result.error; _isLoading = false; });
    }
  }

  Future<bool> _createRoom({
    required String roomNumber,
    required String roomType,
    required int pricePerMonth,
    required int maxOccupant,
    required RoomStatus status,
    String? description,
  }) async {
    final result = await KosRoomRepository.createRoom(
      kosId:         widget.kosId,
      roomNumber:    roomNumber,
      roomType:      roomType,
      pricePerMonth: pricePerMonth,
      maxOccupant:   maxOccupant,
      status:        status,
      description:   description,
    );

    if (!mounted) return false;

    if (result.isSuccess) {
      setState(() => _rooms.insert(0, result.data!));
      _showSnack('Kamar $roomNumber berhasil ditambahkan');
      return true;
    } else {
      _showSnack(result.error!, isError: true);
      return false;
    }
  }

  Future<void> _updateRoom(String roomId, Map<String, dynamic> fields) async {
    final result = await KosRoomRepository.updateRoom(roomId, fields);
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        final idx = _rooms.indexWhere((r) => r.id == roomId);
        if (idx != -1) _rooms[idx] = result.data!;
      });
      _showSnack('Kamar berhasil diperbarui');
    } else {
      _showSnack(result.error!, isError: true);
    }
  }

  Future<void> _deleteRoom(KosRoom room) async {
    final result = await KosRoomRepository.deleteRoom(room.id);
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _rooms.removeWhere((r) => r.id == room.id));
      _showSnack('Kamar ${room.roomNumber} berhasil dihapus');
    } else {
      _showSnack(result.error!, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : AppTheme.primaryGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _formatPrice(int price) =>
      'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  List<KosRoom> get _filtered {
    var result = _rooms.where((r) {
      if (_statusFilter != null && r.status != _statusFilter) return false;
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      return r.roomNumber.toLowerCase().contains(q) ||
          r.roomType.toLowerCase().contains(q);
    }).toList();

    switch (_sortBy) {
      case 'room_number_asc':  result.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
      case 'room_number_desc': result.sort((a, b) => b.roomNumber.compareTo(a.roomNumber));
      case 'price_asc':        result.sort((a, b) => a.pricePerMonth.compareTo(b.pricePerMonth));
      case 'price_desc':       result.sort((a, b) => b.pricePerMonth.compareTo(a.pricePerMonth));
      case 'type_asc':         result.sort((a, b) => a.roomType.compareTo(b.roomType));
      case 'type_desc':        result.sort((a, b) => b.roomType.compareTo(a.roomType));
    }
    return result;
  }

  void _openAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddRoomSheet(onSave: _createRoom),
    );
  }

  void _showEditDialog(KosRoom room) {
    final numberCtrl = TextEditingController(text: room.roomNumber);
    final typeCtrl   = TextEditingController(text: room.roomType);
    final priceCtrl  = TextEditingController(text: room.pricePerMonth.toString());
    final occCtrl    = TextEditingController(text: room.maxOccupant.toString());
    final descCtrl   = TextEditingController(text: room.description ?? '');
    RoomStatus selectedStatus = room.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Edit Kamar ${room.roomNumber}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _outlinedField(numberCtrl, 'Nomor Kamar', hint: 'A01, B02...'),
              const SizedBox(height: 14),
              _outlinedField(typeCtrl, 'Tipe Kamar'),
              const SizedBox(height: 14),
              _outlinedField(priceCtrl, 'Harga per Bulan (Rp)',
                  keyboard: TextInputType.number, prefix: 'Rp '),
              const SizedBox(height: 14),
              _outlinedField(occCtrl, 'Kapasitas',
                  keyboard: TextInputType.number, suffix: 'orang'),
              const SizedBox(height: 14),
              DropdownButtonFormField<RoomStatus>(
                value: selectedStatus,
                decoration: const InputDecoration(
                    labelText: 'Status', border: OutlineInputBorder()),
                items: RoomStatus.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                    .toList(),
                onChanged: (v) => setDialog(() => selectedStatus = v!),
              ),
              const SizedBox(height: 14),
              _outlinedField(descCtrl, 'Catatan (Opsional)', maxLines: 2),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateRoom(room.id, {
                  'room_number':     numberCtrl.text.trim(),
                  'room_type':       typeCtrl.text.trim(),
                  'price_per_month': int.tryParse(priceCtrl.text) ?? room.pricePerMonth,
                  'max_occupant':    int.tryParse(occCtrl.text) ?? room.maxOccupant,
                  'status':          selectedStatus.dbValue,
                  'description':     descCtrl.text.trim(),
                });
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(KosRoom room) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('Lihat Detail'),
            onTap: () { Navigator.pop(ctx); _showDetail(room); },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Riwayat Penyewa'),
            onTap: () { Navigator.pop(ctx); _showSnack('Coming soon!'); },
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Riwayat Pembayaran'),
            onTap: () { Navigator.pop(ctx); _showSnack('Coming soon!'); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Hapus Kamar',
                style: TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(ctx); _showDeleteConfirm(room); },
          ),
        ]),
      ),
    );
  }

  void _showDetail(KosRoom room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55, minChildSize: 0.3, maxChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 20),
            Text('Detail Kamar ${room.roomNumber}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            Text(room.kosTitle,
                style: TextStyle(color: Colors.grey.shade600)),
            const Divider(height: 24),
            _DetailRow(label: 'room_number',     value: room.roomNumber),
            _DetailRow(label: 'room_type',       value: room.roomType),
            _DetailRow(label: 'price_per_month', value: _formatPrice(room.pricePerMonth)),
            _DetailRow(label: 'rental_type', value: room.rentalType.label),
            _DetailRow(label: 'max_occupant',    value: '${room.maxOccupant} orang'),
            _DetailRow(label: 'status',          value: room.status.dbValue),
            if (room.description != null && room.description!.isNotEmpty)
              _DetailRow(label: 'description', value: room.description!),
            if (room.updatedAt != null)
              _DetailRow(label: 'updated_at', value: room.updatedAt!),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(context); _showEditDialog(room); },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Kamar'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showDeleteConfirm(KosRoom room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kamar?'),
        content: Text(
          'Kamar ${room.roomNumber} akan dihapus beserta seluruh data '
          'registrasi dan pembayaran terkait.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { Navigator.pop(ctx); _deleteRoom(room); },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(
        title: Text(widget.kosTitle),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadRooms,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kamar'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_errorMessage!, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadRooms,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ]),
        ),
      );
    }

    final items       = _filtered;
    final occupied    = _rooms.where((r) => r.status == RoomStatus.occupied).length;
    final available   = _rooms.where((r) => r.status == RoomStatus.available).length;
    final maintenance = _rooms.where((r) => r.status == RoomStatus.maintenance).length;

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Text(
            'Total ${_rooms.length} kamar  •  Terisi: $occupied  •  Kosong: $available  •  Maintenance: $maintenance',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Cari nomor atau tipe kamar...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final v = await showModalBottomSheet<RoomStatus?>(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => _StatusSheet(selected: _statusFilter),
                  );
                  if (v != _statusFilter) {
                    setState(() => _statusFilter = v);
                    _loadRooms();
                  }
                },
                icon: const Icon(Icons.filter_list_rounded),
                label: Text(_statusFilter == null
                    ? 'Filter'
                    : 'Filter: ${_statusFilter!.label}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final v = await showModalBottomSheet<String>(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => _SortSheet(selected: _sortBy),
                  );
                  if (v != null) setState(() => _sortBy = v);
                },
                icon: const Icon(Icons.swap_vert_rounded),
                label: Text(_sortBy == 'room_number_asc'
                    ? 'Urutkan'
                    : 'Urut: ${_sortBy.replaceAll('_', ' ')}'),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(children: [
                  Icon(Icons.meeting_room_outlined,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    _statusFilter != null
                        ? 'Tidak ada kamar "${_statusFilter!.label}"'
                        : 'Belum ada kamar.\nTap tombol + untuk menambah.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ]),
              ),
            )
          else
            ...items.map((r) => _RoomCard(
                  room: r,
                  formatPrice: _formatPrice,
                  onEdit: () => _showEditDialog(r),
                  onMore: () => _showMoreOptions(r),
                )),
        ],
      ),
    );
  }

  static Widget _outlinedField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? prefix,
    String? suffix,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          prefixText: prefix,
          suffixText: suffix,
        ),
      );
}

class _AddRoomSheet extends StatefulWidget {
  const _AddRoomSheet({required this.onSave});

  final Future<bool> Function({
    required String roomNumber,
    required String roomType,
    required int pricePerMonth,
    required int maxOccupant,
    required RoomStatus status,
    String? description,
  }) onSave;

  @override
  State<_AddRoomSheet> createState() => _AddRoomSheetState();
}

class _AddRoomSheetState extends State<_AddRoomSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _priceCtrl  = TextEditingController();
  final _occCtrl    = TextEditingController(text: '1');
  final _descCtrl   = TextEditingController();

  String _selectedType       = 'Standard Single';
  RoomStatus _selectedStatus = RoomStatus.available;
  bool _isSaving             = false;

  final _roomTypes = const [
    'Standard Single', 'Standard Double',
    'Deluxe Single',   'Deluxe Double',
    'Deluxe Balcony',  'Suite King', 'Suite Queen',
  ];

  @override
  void dispose() {
    _numberCtrl.dispose();
    _priceCtrl.dispose();
    _occCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final success = await widget.onSave(
      roomNumber:    _numberCtrl.text.trim(),
      roomType:      _selectedType,
      pricePerMonth: int.parse(_priceCtrl.text.replaceAll('.', '')),
      maxOccupant:   int.parse(_occCtrl.text),
      status:        _selectedStatus,
      description:   _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              Text('Tambah Kamar Baru',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
              const SizedBox(height: 20),
              TextFormField(
                controller: _numberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nomor Kamar',
                  hintText: 'Contoh: A01, B02, 101',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Nomor kamar wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipe Kamar',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _roomTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga per Bulan',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Harga wajib diisi';
                  if ((int.tryParse(v.replaceAll('.', '')) ?? 0) <= 0) {
                    return 'Harga harus angka valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _occCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kapasitas',
                  prefixIcon: Icon(Icons.people_outline),
                  suffixText: 'orang',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Kapasitas wajib diisi';
                  if ((int.tryParse(v) ?? 0) <= 0) return 'Masukkan angka valid';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<RoomStatus>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: RoomStatus.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStatus = v!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  hintText: 'Lantai, kondisi khusus, dll...',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan Kamar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.formatPrice,
    required this.onEdit,
    required this.onMore,
  });

  final KosRoom room;
  final String Function(int) formatPrice;
  final VoidCallback onEdit;
  final VoidCallback onMore;

  Color get _badgeBg {
    switch (room.status) {
      case RoomStatus.occupied:    return const Color(0xFFE8F5E9);
      case RoomStatus.available:   return const Color(0xFFE3F2FD);
      case RoomStatus.maintenance: return const Color(0xFFFFF3E0);
    }
  }

  Color get _badgeFg {
    switch (room.status) {
      case RoomStatus.occupied:    return AppTheme.primaryGreen;
      case RoomStatus.available:   return const Color(0xFF1565C0);
      case RoomStatus.maintenance: return const Color(0xFFEF6C00);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: AppTheme.surfaceTint,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(room.roomNumber,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(room.roomType,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(room.status.label,
                      style: TextStyle(
                          color: _badgeFg,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 4),
              Text('${formatPrice(room.pricePerMonth)}${room.rentalType.priceSuffix}',
                  style: TextStyle(
                      color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
              Text('Kapasitas: ${room.maxOccupant} orang',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              if (room.description != null && room.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(room.description!,
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
              const SizedBox(height: 10),
              Row(children: [
                const Spacer(),
                IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit'),
                IconButton(
                    onPressed: onMore,
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Lainnya'),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontFamily: 'monospace')),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _StatusSheet extends StatelessWidget {
  const _StatusSheet({required this.selected});

  final RoomStatus? selected;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const ListTile(
              title: Text('Filter Status',
                  style: TextStyle(fontWeight: FontWeight.w800))),
          RadioListTile<RoomStatus?>(
            value: null,
            groupValue: selected,
            onChanged: (v) => Navigator.of(context).pop(v),
            title: const Text('Semua'),
          ),
          ...RoomStatus.values.map((s) => RadioListTile<RoomStatus?>(
                value: s,
                groupValue: selected,
                onChanged: (v) => Navigator.of(context).pop(v),
                title: Text(s.label),
              )),
        ]),
      );
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('room_number_asc',  'Nomor Kamar (A-Z)'),
      ('room_number_desc', 'Nomor Kamar (Z-A)'),
      ('price_asc',        'Harga (Terendah)'),
      ('price_desc',       'Harga (Tertinggi)'),
      ('type_asc',         'Tipe (A-Z)'),
      ('type_desc',        'Tipe (Z-A)'),
    ];

    return SafeArea(
      child: ListView(shrinkWrap: true, children: [
        const ListTile(
            title: Text('Urutkan Kamar',
                style: TextStyle(fontWeight: FontWeight.w800))),
        ...options.map((o) => RadioListTile<String>(
              value: o.$1,
              groupValue: selected,
              onChanged: (v) => Navigator.of(context).pop(v),
              title: Text(o.$2),
            )),
      ]),
    );
  }
}