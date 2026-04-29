import '../core/api_service.dart'; // lib/models/ → lib/core/


// ─────────────────────────────────────────────────────────────────────────────
// Enum tipe sewa
// ─────────────────────────────────────────────────────────────────────────────

enum RentalType { daily, monthly, yearly }

extension RentalTypeExt on RentalType {
  String get label {
    switch (this) {
      case RentalType.daily:   return 'Harian';
      case RentalType.monthly: return 'Bulanan';
      case RentalType.yearly:  return 'Tahunan';
    }
  }

  String get priceSuffix {
    switch (this) {
      case RentalType.daily:   return '/hari';
      case RentalType.monthly: return '/bulan';
      case RentalType.yearly:  return '/tahun';
    }
  }

  String get priceLabel {
    switch (this) {
      case RentalType.daily:   return 'Harga per Hari';
      case RentalType.monthly: return 'Harga per Bulan';
      case RentalType.yearly:  return 'Harga per Tahun';
    }
  }

  String get dbValue {
    switch (this) {
      case RentalType.daily:   return 'daily';
      case RentalType.monthly: return 'monthly';
      case RentalType.yearly:  return 'yearly';
    }
  }

  static RentalType fromDb(String? value) {
    switch (value) {
      case 'daily':  return RentalType.daily;
      case 'yearly': return RentalType.yearly;
      default:       return RentalType.monthly;
    }
  }
}

enum RoomStatus { available, occupied, maintenance }

extension RoomStatusExt on RoomStatus {
  String get label {
    switch (this) {
      case RoomStatus.available:
        return 'Kosong';
      case RoomStatus.occupied:
        return 'Terisi';
      case RoomStatus.maintenance:
        return 'Maintenance';
    }
  }

  String get dbValue {
    switch (this) {
      case RoomStatus.available:
        return 'available';
      case RoomStatus.occupied:
        return 'occupied';
      case RoomStatus.maintenance:
        return 'maintenance';
    }
  }

  static RoomStatus fromDb(String value) {
    switch (value) {
      case 'occupied':
        return RoomStatus.occupied;
      case 'maintenance':
        return RoomStatus.maintenance;
      default:
        return RoomStatus.available;
    }
  }
}

// ── Model ──────────────────────────────────────────────────────────────────────

class KosRoom {
  const KosRoom({
    required this.id,
    required this.kosId,
    required this.kosTitle,
    required this.roomNumber,
    required this.roomType,
    required this.pricePerMonth,
    required this.status,
    required this.maxOccupant,
    required this.rentalType,           
    this.facilities = const [],
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String kosId;
  final String kosTitle;
  final String roomNumber;
  final String roomType;
  final int pricePerMonth;
  final RoomStatus status;
  final int maxOccupant;
  final RentalType rentalType;
  final List<RoomFacility> facilities;
  final String? description;
  final String? createdAt;
  final String? updatedAt;

  factory KosRoom.fromJson(Map<String, dynamic> json) => KosRoom(
        id:            json['id'] as String,
        kosId:         json['kosId'] as String,
        kosTitle:      json['kosTitle'] as String? ?? '',
        roomNumber:    json['roomNumber'] as String,
        roomType:      json['roomType'] as String,
        pricePerMonth: json['pricePerMonth'] as int,
        status:        RoomStatusExt.fromDb(json['status'] as String),
        maxOccupant:   json['maxOccupant'] as int,
        rentalType: RentalTypeExt.fromDb(json['rental_type'] as String? ?? 'monthly'), 
        facilities: ((json['facilities'] as List?) ?? const [])
            .map((e) => RoomFacility.fromJson(e as Map<String, dynamic>))
            .toList(),
        description:   json['description'] as String?,
        createdAt:     json['createdAt'] as String?,
        updatedAt:     json['updatedAt'] as String?,
      );
}

class RoomFacility {
  const RoomFacility({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory RoomFacility.fromJson(Map<String, dynamic> json) => RoomFacility(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
      );
}

// ── Result wrapper ─────────────────────────────────────────────────────────────

class RoomResult<T> {
  const RoomResult.success(this.data) : error = null;
  const RoomResult.failure(this.error) : data = null;

  final T? data;
  final String? error;

  bool get isSuccess => error == null;
}

// ── Repository ────────────────────────────────────────────────────────────────

class KosRoomRepository {
  static const _endpoint = 'api/kos_rooms.php';

  static Future<RoomResult<List<KosRoom>>> getRooms(
    String kosId, {
    String? statusFilter,
  }) async {
    final params = <String, String>{'kos_id': kosId};
    if (statusFilter != null) params['status'] = statusFilter;

    final res = await ApiService.get(_endpoint, queryParams: params);
    if (!res.success) {
      return RoomResult.failure(res.message ?? 'Gagal memuat kamar');
    }

    final list = (res.data!['data'] as List)
        .map((e) => KosRoom.fromJson(e as Map<String, dynamic>))
        .toList();

    return RoomResult.success(list);
  }

  static Future<RoomResult<KosRoom>> createRoom({
    required String kosId,
    required String roomNumber,
    required String roomType,
    required int pricePerMonth,
    required int maxOccupant,
    RoomStatus status = RoomStatus.available,
    RentalType rentalType = RentalType.monthly,
    String? description,
  }) async {
    final res = await ApiService.post(_endpoint, {
      'kos_id':          kosId,
      'room_number':     roomNumber,
      'room_type':       roomType,
      'price_per_month': pricePerMonth,
      'max_occupant':    maxOccupant,
      'status':          status.dbValue,
      'rental_type':     rentalType.dbValue,
      'description':     description,
    });

    if (!res.success) {
      return RoomResult.failure(res.message ?? 'Gagal menambah kamar');
    }

    final room = KosRoom.fromJson(res.data!['data'] as Map<String, dynamic>);
    return RoomResult.success(room);
  }

  static Future<RoomResult<KosRoom>> updateRoom(
    String roomId,
    Map<String, dynamic> fields,
  ) async {
    final res = await ApiService.put(
      _endpoint,
      fields,
      queryParams: {'id': roomId},
    );

    if (!res.success) {
      return RoomResult.failure(res.message ?? 'Gagal memperbarui kamar');
    }

    final room = KosRoom.fromJson(res.data!['data'] as Map<String, dynamic>);
    return RoomResult.success(room);
  }

  static Future<RoomResult<bool>> deleteRoom(String roomId) async {
    final res = await ApiService.delete(
      _endpoint,
      queryParams: {'id': roomId},
    );

    if (!res.success) {
      return RoomResult.failure(res.message ?? 'Gagal menghapus kamar');
    }

    return const RoomResult.success(true);
  }
}
