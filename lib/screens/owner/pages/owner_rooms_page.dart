// lib/screens/owner/pages/owner_rooms_page.dart
//
// Perubahan dari versi dummy:
//   - KosListingRepository.getMyListings() → GET /api/kos_listings (JWT)
//   - KosRoomRepository.*                  → GET/POST/PUT/DELETE /api/kos_rooms (JWT)
//
// Tidak ada perubahan UI sama sekali — hanya lapisan data yang diganti.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_theme.dart';
import '../../../core/api_service.dart';
import '../../../models/kos_room.dart';
import '../../../models/kos_listing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Repository: KosListing milik owner
// ─────────────────────────────────────────────────────────────────────────────

class _RepoResult<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;
  const _RepoResult.ok(this.data) : error = null;
  const _RepoResult.fail(this.error) : data = null;
}

class KosListingRepository {
  KosListingRepository._();

  static Future<_RepoResult<List<KosListing>>> getMyListings() async {
    final res = await ApiService.get('api/kos_listings');

    if (!res.success) {
      return _RepoResult.fail(res.message ?? 'Gagal memuat daftar kos');
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => KosListing.fromJson(e as Map<String, dynamic>))
          .toList();
      return _RepoResult.ok(list);
    } catch (e) {
      return _RepoResult.fail('Gagal memproses data: $e');
    }
  }

  static Future<_RepoResult<KosListing>> createListing({
    required String title,
    required String location,
    required String description,
    required int pricePerMonth,
    required String ownerContact,
  }) async {
    final res = await ApiService.post('api/kos_listings', {
      'title': title,
      'location': location,
      'description': description,
      'price_per_month': pricePerMonth,
      'owner_contact': ownerContact,
    });

    if (!res.success) {
      return _RepoResult.fail(res.message ?? 'Gagal menambah kos');
    }

    try {
      final item = KosListing.fromJson(res.data!['data'] as Map<String, dynamic>);
      return _RepoResult.ok(item);
    } catch (e) {
      return _RepoResult.fail('Gagal memproses data: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Repository: KosRoom
// ─────────────────────────────────────────────────────────────────────────────

class FacilityOption {
  const FacilityOption({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory FacilityOption.fromJson(Map<String, dynamic> json) => FacilityOption(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
      );
}

class RoomFacilityRepository {
  RoomFacilityRepository._();

  static Future<_RepoResult<List<FacilityOption>>> getAllFacilities() async {
    final res = await ApiService.get('api/facilities');
    if (!res.success) {
      return _RepoResult.fail(res.message ?? 'Gagal memuat fasilitas');
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => FacilityOption.fromJson(e as Map<String, dynamic>))
          .toList();
      return _RepoResult.ok(list);
    } catch (e) {
      return _RepoResult.fail('Gagal memproses data fasilitas: $e');
    }
  }
}

class KosRoomRepository {
  KosRoomRepository._();

  // GET /api/kos_rooms?kos_id=xxx[&status=available]
  static Future<_RepoResult<List<KosRoom>>> getRooms(
    String kosId, {
    String? statusFilter,
  }) async {
    final params = <String, String>{'kos_id': kosId};
    if (statusFilter != null) params['status'] = statusFilter;

    final res = await ApiService.get('api/kos_rooms', queryParams: params);

    if (!res.success) {
      return _RepoResult.fail(res.message ?? 'Gagal memuat kamar');
    }

    try {
      final list = (res.data!['data'] as List)
          .map((e) => KosRoom.fromJson(e as Map<String, dynamic>))
          .toList();
      return _RepoResult.ok(list);
    } catch (e) {
      return _RepoResult.fail('Gagal memproses data: $e');
    }
  }

  // POST /api/kos_rooms
  static Future<_RepoResult<KosRoom>> createRoom({
    required String kosId,
    required String roomNumber,
    required String roomType,
    required int pricePerMonth,
    required int maxOccupant,
    required RoomStatus status,
    List<int> facilityIds = const [],
    String? description,
  }) async {
    final res = await ApiService.post('api/kos_rooms', {
      'kos_id':         kosId,
      'room_number':    roomNumber,
      'room_type':      roomType,
      'price_per_month': pricePerMonth,
      'max_occupant':   maxOccupant,
      'status':         status.dbValue,
      'facility_ids':   facilityIds,
      if (description != null && description.isNotEmpty)
        'description': description,
    });

    if (!res.success) {
      return _RepoResult.fail(res.message ?? 'Gagal menambah kamar');
    }

    try {
      final room = KosRoom.fromJson(res.data!['data'] as Map<String, dynamic>);
      return _RepoResult.ok(room);
    } catch (e) {
      return _RepoResult.fail('Gagal memproses data: $e');
    }
  }

  // PUT /api/kos_rooms?id=xxx
  static Future<_RepoResult<KosRoom>> updateRoom(
    String roomId,
    Map<String, dynamic> fields,
  ) async {
    final res = await ApiService.put(
      'api/kos_rooms',
      fields,
      queryParams: {'id': roomId},
    );

    if (!res.success) {
      return _RepoResult.fail(res.message ?? 'Gagal memperbarui kamar');
    }

    try {
      final room = KosRoom.fromJson(res.data!['data'] as Map<String, dynamic>);
      return _RepoResult.ok(room);
    } catch (e) {
      return _RepoResult.fail('Gagal memproses data: $e');
    }
  }

  // DELETE /api/kos_rooms?id=xxx
  static Future<_RepoResult<void>> deleteRoom(String roomId) async {
    final res = await ApiService.delete(
      'api/kos_rooms',
      queryParams: {'id': roomId},
    );

    if (!res.success) {
      return _RepoResult.fail(res.message ?? 'Gagal menghapus kamar');
    }
    return const _RepoResult.ok(null);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class OwnerRoomsPage extends StatefulWidget {
  const OwnerRoomsPage({super.key});

  @override
  State<OwnerRoomsPage> createState() => _OwnerRoomsPageState();
}

class _OwnerRoomsPageState extends State<OwnerRoomsPage> {
  List<KosRoom>    _rooms       = [];
  List<KosListing> _kosListings = [];
  List<FacilityOption> _availableFacilities = [];
  String?          _selectedKosId;
  bool             _isLoading    = false;
  bool             _isLoadingKos = true;
  String?          _errorMessage;

  String      _query        = '';
  RoomStatus? _statusFilter;
  String      _sortBy       = 'room_number_asc';

  @override
  void initState() {
    super.initState();
    _loadKosListings();
  }

  // ── Load daftar kos owner ─────────────────────────────────────────────────

  Future<void> _loadKosListings() async {
    setState(() { _isLoadingKos = true; _errorMessage = null; });

    final result = await KosListingRepository.getMyListings();
    if (!mounted) return;

    if (result.isSuccess && result.data!.isNotEmpty) {
      setState(() {
        _kosListings   = result.data!;
        _selectedKosId = result.data!.first.id;
        _isLoadingKos  = false;
      });
      await _loadRooms();
    } else if (result.isSuccess && result.data!.isEmpty) {
      setState(() {
        _kosListings  = [];
        _isLoadingKos = false;
        _errorMessage = 'Anda belum memiliki kos. Tambah kos terlebih dahulu.';
      });
    } else {
      setState(() {
        _isLoadingKos = false;
        _errorMessage = result.error ?? 'Gagal memuat daftar kos';
      });
    }
  }

  // ── Load kamar kos terpilih ───────────────────────────────────────────────

  Future<void> _loadRooms() async {
    if (_selectedKosId == null) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await KosRoomRepository.getRooms(
      _selectedKosId!,
      statusFilter: _statusFilter?.dbValue,
    );
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() { _rooms = result.data!; _isLoading = false; });
    } else {
      setState(() { _errorMessage = result.error; _isLoading = false; });
    }
  }

  Future<void> _loadFacilityOptions() async {
    final result = await RoomFacilityRepository.getAllFacilities();
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _availableFacilities = result.data!);
    } else {
      _showSnack(result.error ?? 'Gagal memuat fasilitas', isError: true);
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<bool> _createRoom({
    required String kosId,
    required String roomNumber,
    required String roomType,
    required int pricePerMonth,
    required int maxOccupant,
    required RoomStatus status,
    required List<int> facilityIds,
    String? description,
  }) async {
    final result = await KosRoomRepository.createRoom(
      kosId:         kosId,
      roomNumber:    roomNumber,
      roomType:      roomType,
      pricePerMonth: pricePerMonth,
      maxOccupant:   maxOccupant,
      status:        status,
      facilityIds:   facilityIds,
      description:   description,
    );
    if (!mounted) return false;

    if (result.isSuccess) {
      if (kosId == _selectedKosId) {
        setState(() => _rooms.insert(0, result.data!));
      }
      _showSnack('Kamar ${result.data!.roomNumber} berhasil ditambahkan');
      return true;
    } else {
      _showSnack(result.error!, isError: true);
      return false;
    }
  }

  Future<bool> _createKos({
    required String title,
    required String location,
    required String description,
    required int pricePerMonth,
    required String ownerContact,
  }) async {
    final result = await KosListingRepository.createListing(
      title: title,
      location: location,
      description: description,
      pricePerMonth: pricePerMonth,
      ownerContact: ownerContact,
    );
    if (!mounted) return false;

    if (result.isSuccess) {
      setState(() {
        _kosListings.insert(0, result.data!);
        _selectedKosId = result.data!.id;
        _rooms = [];
        _errorMessage = null;
      });
      await _loadRooms();
      _showSnack('Kos ${result.data!.title} berhasil ditambahkan');
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? Colors.red : AppTheme.primaryGreen,
      behavior:        SnackBarBehavior.floating,
    ));
  }

  String _formatPrice(int price) =>
      'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  KosListing? get _selectedKos =>
      _kosListings.where((k) => k.id == _selectedKosId).firstOrNull;

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

  // ── Sheet tambah kamar ────────────────────────────────────────────────────

  Future<void> _openAddSheet() async {
    if (_kosListings.isEmpty) {
      _showSnack('Tambah kos terlebih dahulu', isError: true);
      return;
    }
    if (_availableFacilities.isEmpty) {
      await _loadFacilityOptions();
      if (!mounted) return;
    }
    showModalBottomSheet<void>(
      context:         context,
      isScrollControlled: true,
      useSafeArea:     true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddRoomSheet(
        kosListings:   _kosListings,
        defaultKosId:  _selectedKosId,
        existingRooms: _rooms,
        facilities:    _availableFacilities,
        onSave:        _createRoom,
      ),
    );
  }

  void _openAddKosSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddKosSheet(onSave: _createKos),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showEditDialog(KosRoom room) async {
    if (_availableFacilities.isEmpty) {
      await _loadFacilityOptions();
      if (!mounted) return;
    }

    final numberCtrl = TextEditingController(text: room.roomNumber);
    final typeCtrl   = TextEditingController(text: room.roomType);
    final priceCtrl  = TextEditingController(text: room.pricePerMonth.toString());
    final occCtrl    = TextEditingController(text: room.maxOccupant.toString());
    final descCtrl   = TextEditingController(text: room.description ?? '');
    RoomStatus selectedStatus = room.status;
    final selectedFacilityIds = room.facilities.map((f) => f.id).toSet();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Edit Kamar ${room.roomNumber}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _outlinedField(numberCtrl, 'Nomor Kamar'),
              const SizedBox(height: 14),
              _outlinedField(typeCtrl, 'Tipe Kamar'),
              const SizedBox(height: 14),
              _outlinedField(priceCtrl, 'Harga per Bulan',
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Fasilitas Kamar',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              if (_availableFacilities.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text('Belum ada data fasilitas kamar.'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableFacilities.map((facility) {
                    final selected = selectedFacilityIds.contains(facility.id);
                    return FilterChip(
                      label: Text(facility.name),
                      selected: selected,
                      onSelected: (value) {
                        setDialog(() {
                          if (value) {
                            selectedFacilityIds.add(facility.id);
                          } else {
                            selectedFacilityIds.remove(facility.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 14),
              _outlinedField(descCtrl, 'Catatan (Opsional)', maxLines: 2),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateRoom(room.id, {
                  'room_number':     numberCtrl.text.trim(),
                  'room_type':       typeCtrl.text.trim(),
                  'price_per_month': int.tryParse(priceCtrl.text) ?? room.pricePerMonth,
                  'max_occupant':    int.tryParse(occCtrl.text) ?? room.maxOccupant,
                  'status':          selectedStatus.dbValue,
                  'facility_ids':    selectedFacilityIds.toList(),
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
            title:   const Text('Lihat Detail'),
            onTap:   () { Navigator.pop(ctx); _showDetail(room); },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title:   const Text('Riwayat Penyewa'),
            onTap:   () { Navigator.pop(ctx); _showSnack('Coming soon!'); },
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title:   const Text('Riwayat Pembayaran'),
            onTap:   () { Navigator.pop(ctx); _showSnack('Coming soon!'); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Hapus Kamar', style: TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(ctx); _showDeleteConfirm(room); },
          ),
        ]),
      ),
    );
  }

  void _showDetail(KosRoom room) {
    showModalBottomSheet(
      context:         context,
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
                color:        Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 20),
            Text('Detail Kamar ${room.roomNumber}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            Text(room.kosTitle, style: TextStyle(color: Colors.grey.shade600)),
            const Divider(height: 24),
            _DetailRow(label: 'Kos',         value: room.kosTitle),
            _DetailRow(label: 'Kode Kos',    value: _selectedKos?.accessCode ?? '-'),
            _DetailRow(label: 'Nomor Kamar', value: room.roomNumber),
            _DetailRow(label: 'Tipe',        value: room.roomType),
            _DetailRow(label: 'Harga/Bulan', value: _formatPrice(room.pricePerMonth)),
            _DetailRow(label: 'Kapasitas',   value: '${room.maxOccupant} orang'),
            _DetailRow(label: 'Status',      value: room.status.label),
            if (room.facilities.isNotEmpty)
              _DetailRow(
                label: 'Fasilitas',
                value: room.facilities.map((f) => f.name).join(', '),
              ),
            if (room.description != null && room.description!.isNotEmpty)
              _DetailRow(label: 'Catatan', value: room.description!),
            if (room.updatedAt != null)
              _DetailRow(label: 'Diperbarui', value: room.updatedAt!),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(context); _showEditDialog(room); },
                icon:  const Icon(Icons.edit),
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
        title:   const Text('Hapus Kamar?'),
        content: Text(
          'Kamar ${room.roomNumber} di ${room.kosTitle} akan dihapus beserta '
          'seluruh data registrasi dan pembayaran terkait.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style:     FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { Navigator.pop(ctx); _deleteRoom(room); },
            child:     const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(
        title: const Text('Kelola Kamar'),
        actions: [
          IconButton(
            tooltip:  'Refresh',
            icon:     const Icon(Icons.refresh),
            onPressed: _loadRooms,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_kos_fab',
            onPressed: _openAddKosSheet,
            icon: const Icon(Icons.home_work_outlined),
            label: const Text('Tambah Kos'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add_room_fab',
            onPressed: _openAddSheet,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Kamar'),
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: _isLoadingKos
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_kosListings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.home_work_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Belum ada kos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Tambahkan kos terlebih dahulu di halaman Properti.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openAddKosSheet,
              icon: const Icon(Icons.home_work_outlined),
              label: const Text('Tambah Kos'),
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
          // ── Dropdown kos ──────────────────────────────────────────────
          DropdownButtonFormField<String>(
            value: _selectedKosId,
            decoration: InputDecoration(
              labelText: 'Pilih Kos',
              prefixIcon: const Icon(Icons.home_work_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled:    true,
              fillColor: Colors.white,
            ),
            items: _kosListings
                .map((k) => DropdownMenuItem(value: k.id, child: Text(k.title)))
                .toList(),
            onChanged: (v) {
              if (v != null && v != _selectedKosId) {
                setState(() {
                  _selectedKosId = v;
                  _rooms         = [];
                  _statusFilter  = null;
                });
                _loadRooms();
              }
            },
          ),
          const SizedBox(height: 12),
          if (_selectedKos != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded, size: 18, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kode Kos: ${_selectedKos!.accessCode}',
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Salin kode kos',
                    icon: const Icon(Icons.copy_rounded, color: AppTheme.primaryGreen, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _selectedKos!.accessCode));
                      _showSnack('Kode kos disalin');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Ringkasan ──────────────────────────────────────────────────
          Text(
            'Total ${_rooms.length} kamar  •  Terisi: $occupied  •  Kosong: $available  •  Maintenance: $maintenance',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),

          // ── Search ────────────────────────────────────────────────────
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText:   'Cari nomor atau tipe kamar...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),

          // ── Filter & sort ─────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final v = await showModalBottomSheet<RoomStatus?>(
                    context:       context,
                    showDragHandle: true,
                    builder: (_) => _StatusSheet(selected: _statusFilter),
                  );
                  if (v != _statusFilter) {
                    setState(() => _statusFilter = v);
                    _loadRooms();
                  }
                },
                icon:  const Icon(Icons.filter_list_rounded),
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
                    context:       context,
                    showDragHandle: true,
                    builder: (_) => _SortSheet(selected: _sortBy),
                  );
                  if (v != null) setState(() => _sortBy = v);
                },
                icon:  const Icon(Icons.swap_vert_rounded),
                label: Text(_sortBy == 'room_number_asc'
                    ? 'Urutkan'
                    : 'Urut: ${_sortBy.replaceAll('_', ' ')}'),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // ── List / loading / error ────────────────────────────────────
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child:   CircularProgressIndicator(),
            ))
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadRooms,
                    icon:  const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                  ),
                ]),
              ),
            )
          else if (items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(children: [
                  Icon(Icons.meeting_room_outlined, size: 48, color: Colors.grey.shade400),
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
                  room:        r,
                  kosAccessCode: _selectedKos?.accessCode,
                  formatPrice: _formatPrice,
                  onEdit:      () => _showEditDialog(r),
                  onMore:      () => _showMoreOptions(r),
                )),
        ],
      ),
    );
  }

  static Widget _outlinedField(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? prefix,
    String? suffix,
  }) =>
      TextField(
        controller:  ctrl,
        keyboardType: keyboard,
        maxLines:    maxLines,
        decoration:  InputDecoration(
          labelText:  label,
          border:     const OutlineInputBorder(),
          prefixText: prefix,
          suffixText: suffix,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _AddKosSheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddKosSheet extends StatefulWidget {
  const _AddKosSheet({required this.onSave});

  final Future<bool> Function({
    required String title,
    required String location,
    required String description,
    required int pricePerMonth,
    required String ownerContact,
  }) onSave;

  @override
  State<_AddKosSheet> createState() => _AddKosSheetState();
}

class _AddKosSheetState extends State<_AddKosSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final success = await widget.onSave(
      title: _titleCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      pricePerMonth: int.parse(_priceCtrl.text.replaceAll('.', '').replaceAll(',', '')),
      ownerContact: _contactCtrl.text.trim(),
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
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Tambah Kos Baru',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Kos',
                  prefixIcon: Icon(Icons.home_work_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama kos wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alamat / Lokasi',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Lokasi wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga Mulai per Bulan',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Harga wajib diisi';
                  final parsed = int.tryParse(v.replaceAll('.', '').replaceAll(',', ''));
                  if (parsed == null || parsed <= 0) return 'Harga harus angka valid';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contactCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Kontak Pemilik',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Kontak wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  hintText: 'Deskripsi singkat kos',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Deskripsi wajib diisi' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan Kos'),
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

// ─────────────────────────────────────────────────────────────────────────────
// _AddRoomSheet — identik dengan versi sebelumnya, tidak ada perubahan UI
// ─────────────────────────────────────────────────────────────────────────────

class _AddRoomSheet extends StatefulWidget {
  const _AddRoomSheet({
    required this.kosListings,
    required this.defaultKosId,
    required this.existingRooms,
    required this.facilities,
    required this.onSave,
  });

  final List<KosListing> kosListings;
  final String? defaultKosId;
  final List<KosRoom> existingRooms;
  final List<FacilityOption> facilities;
  final Future<bool> Function({
    required String kosId,
    required String roomNumber,
    required String roomType,
    required int pricePerMonth,
    required int maxOccupant,
    required RoomStatus status,
    required List<int> facilityIds,
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

  late String _selectedKosId;
  String     _selectedType   = 'Standard Single';
  RoomStatus _selectedStatus = RoomStatus.available;
  bool       _isSaving       = false;
  bool       _isGeneratingCode = false;
  final Set<int> _selectedFacilityIds = <int>{};

  final _roomTypes = const [
    'Standard Single', 'Standard Double',
    'Deluxe Single',   'Deluxe Double',
    'Deluxe Balcony',  'Suite King', 'Suite Queen',
  ];

  @override
  void initState() {
    super.initState();
    _selectedKosId = widget.defaultKosId ?? widget.kosListings.first.id;
    _generateRoomCode();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _priceCtrl.dispose();
    _occCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _generateRoomCode() {
    _generateRoomCodeFromServer();
  }

  Future<void> _generateRoomCodeFromServer() async {
    setState(() => _isGeneratingCode = true);

    final existing = <String>{};

    final serverRooms = await KosRoomRepository.getRooms(_selectedKosId);
    if (serverRooms.isSuccess && serverRooms.data != null) {
      existing.addAll(
        serverRooms.data!
            .map((r) => r.roomNumber.trim().toUpperCase()),
      );
    } else {
      existing.addAll(
        widget.existingRooms
            .where((r) => r.kosId == _selectedKosId)
            .map((r) => r.roomNumber.trim().toUpperCase()),
      );
    }

    const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    String generated = '';

    outer:
    for (final letter in letters) {
      for (int i = 1; i <= 99; i++) {
        final code = '$letter${i.toString().padLeft(2, '0')}';
        if (!existing.contains(code)) { generated = code; break outer; }
      }
    }

    if (!mounted) return;
    setState(() {
      _numberCtrl.text = generated.isEmpty ? 'A01' : generated;
      _isGeneratingCode = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final success = await widget.onSave(
      kosId:         _selectedKosId,
      roomNumber:    _numberCtrl.text.trim(),
      roomType:      _selectedType,
      pricePerMonth: int.parse(_priceCtrl.text.replaceAll('.', '').replaceAll(',', '')),
      maxOccupant:   int.parse(_occCtrl.text),
      status:        _selectedStatus,
      facilityIds:   _selectedFacilityIds.toList(),
      description:   _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedKos =
        widget.kosListings.firstWhere((k) => k.id == _selectedKosId);

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize:       MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color:        Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              Text('Tambah Kamar Baru',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),

              // Pilih Kos
              DropdownButtonFormField<String>(
                value: _selectedKosId,
                decoration: const InputDecoration(
                  labelText:  'Nama Kos',
                  prefixIcon: Icon(Icons.home_work_outlined),
                  border:     OutlineInputBorder(),
                ),
                items: widget.kosListings
                    .map((k) => DropdownMenuItem(
                          value: k.id,
                          child: Text(k.title, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedKosId = v);
                    _generateRoomCode();
                  }
                },
                validator: (v) => v == null ? 'Pilih kos terlebih dahulu' : null,
              ),
              const SizedBox(height: 14),

              // Kode akses kos
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color:  Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.vpn_key_rounded, size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Text(
                    'Kode Akses: ${selectedKos.accessCode}',
                    style: const TextStyle(
                      fontWeight:    FontWeight.w700,
                      color:         AppTheme.primaryGreen,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: selectedKos.accessCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:  Text('Kode disalin!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.primaryGreen),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // Kode kamar (auto-generate)
              TextFormField(
                controller: _numberCtrl,
                enabled: false,
                decoration: InputDecoration(
                  labelText:  'Kode Kamar',
                  hintText:   'Auto generate',
                  prefixIcon: const Icon(Icons.meeting_room_outlined),
                  suffixIcon: _isGeneratingCode
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Kode kamar wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              // Tipe
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText:  'Tipe Kamar',
                  prefixIcon: Icon(Icons.category_outlined),
                  border:     OutlineInputBorder(),
                ),
                items: _roomTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 14),

              // Harga
              TextFormField(
                controller:  _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText:  'Harga per Bulan',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  prefixText: 'Rp ',
                  border:     OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Harga wajib diisi';
                  if ((int.tryParse(v.replaceAll('.', '').replaceAll(',', '')) ?? 0) <= 0) {
                    return 'Harga harus angka valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Kapasitas
              TextFormField(
                controller:  _occCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText:  'Kapasitas',
                  prefixIcon: Icon(Icons.people_outline),
                  suffixText: 'orang',
                  border:     OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Kapasitas wajib diisi';
                  if ((int.tryParse(v) ?? 0) <= 0) return 'Masukkan angka valid';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Status
              DropdownButtonFormField<RoomStatus>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText:  'Status',
                  prefixIcon: Icon(Icons.info_outline),
                  border:     OutlineInputBorder(),
                ),
                items: RoomStatus.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStatus = v!),
              ),
              const SizedBox(height: 14),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Fasilitas Kamar',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.facilities.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    'Belum ada fasilitas kamar. Admin perlu menambahkan data fasilitas terlebih dahulu.',
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.facilities.map((facility) {
                    final selected = _selectedFacilityIds.contains(facility.id);
                    return FilterChip(
                      label: Text(facility.name),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedFacilityIds.add(facility.id);
                          } else {
                            _selectedFacilityIds.remove(facility.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 14),

              // Catatan
              TextFormField(
                controller: _descCtrl,
                maxLines:   2,
                decoration: const InputDecoration(
                  labelText:  'Catatan (Opsional)',
                  hintText:   'Lantai, kondisi khusus, dll...',
                  prefixIcon: Icon(Icons.notes_outlined),
                  border:     OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan Kamar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child:     const Text('Batal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    this.kosAccessCode,
    required this.formatPrice,
    required this.onEdit,
    required this.onMore,
  });

  final KosRoom room;
  final String? kosAccessCode;
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
              color:        AppTheme.surfaceTint,
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
                    color:        _badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(room.status.label,
                      style: TextStyle(
                          color: _badgeFg, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(room.kosTitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              if (kosAccessCode != null && kosAccessCode!.isNotEmpty)
                Text(
                  'Kode Kos: $kosAccessCode • Kode Kamar: ${room.roomNumber}',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              Text('${formatPrice(room.pricePerMonth)}/bln',
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
              Text('Kapasitas: ${room.maxOccupant} orang',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              if (room.facilities.isNotEmpty)
                Text(
                  'Fasilitas: ${room.facilities.map((f) => f.name).join(', ')}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              if (room.description != null && room.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(room.description!, style: TextStyle(color: Colors.grey.shade600)),
              ],
              const SizedBox(height: 10),
              Row(children: [
                const Spacer(),
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit'),
                IconButton(onPressed: onMore, icon: const Icon(Icons.more_vert), tooltip: 'Lainnya'),
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
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
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
          const ListTile(title: Text('Filter Status',
              style: TextStyle(fontWeight: FontWeight.w800))),
          RadioListTile<RoomStatus?>(
            value: null, groupValue: selected,
            onChanged: (v) => Navigator.of(context).pop(v),
            title: const Text('Semua'),
          ),
          ...RoomStatus.values.map((s) => RadioListTile<RoomStatus?>(
                value: s, groupValue: selected,
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
        const ListTile(title: Text('Urutkan Kamar',
            style: TextStyle(fontWeight: FontWeight.w800))),
        ...options.map((o) => RadioListTile<String>(
              value: o.$1, groupValue: selected,
              onChanged: (v) => Navigator.of(context).pop(v),
              title: Text(o.$2),
            )),
      ]),
    );
  }
}
