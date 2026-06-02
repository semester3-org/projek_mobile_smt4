/// Model untuk profil user lengkap
class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String role;
  final String? photoUrl;
  final String? ktpPhoto;
  final String? kosName;
  final String? kosAccessCode;
  final String? roomNumber;
  final String? roomType;
  final DateTime? activeUntil;
  final List<ActiveRentHistory> activeRentHistory;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
    required this.role,
    this.photoUrl,
    this.ktpPhoto,
    this.kosName,
    this.kosAccessCode,
    this.roomNumber,
    this.roomType,
    this.activeUntil,
    this.activeRentHistory = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      role: json['role'] as String? ?? 'user',
      photoUrl: json['photoUrl'] as String?,
      ktpPhoto: json['ktpPhoto'] as String?,
      kosName: json['kosName'] as String?,
      kosAccessCode: json['kosAccessCode'] as String?,
      roomNumber: json['roomNumber'] as String?,
      roomType: json['roomType'] as String?,
      activeUntil: DateTime.tryParse(json['activeUntil'] as String? ?? ''),
      activeRentHistory: (json['activeRentHistory'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ActiveRentHistory.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'phone': phone,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'role': role,
      'photoUrl': photoUrl,
      'ktpPhoto': ktpPhoto,
      'kosName': kosName,
      'kosAccessCode': kosAccessCode,
      'roomNumber': roomNumber,
      'roomType': roomType,
      'activeUntil': activeUntil?.toIso8601String(),
      'activeRentHistory': activeRentHistory.map((e) => e.toJson()).toList(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    String? role,
    String? photoUrl,
    String? ktpPhoto,
    String? kosName,
    String? kosAccessCode,
    String? roomNumber,
    String? roomType,
    DateTime? activeUntil,
    List<ActiveRentHistory>? activeRentHistory,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      ktpPhoto: ktpPhoto ?? this.ktpPhoto,
      kosName: kosName ?? this.kosName,
      kosAccessCode: kosAccessCode ?? this.kosAccessCode,
      roomNumber: roomNumber ?? this.roomNumber,
      roomType: roomType ?? this.roomType,
      activeUntil: activeUntil ?? this.activeUntil,
      activeRentHistory: activeRentHistory ?? this.activeRentHistory,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class ActiveRentHistory {
  const ActiveRentHistory({
    required this.registrationId,
    required this.kosName,
    required this.kosAccessCode,
    required this.roomNumber,
    required this.roomType,
    required this.activeUntil,
    required this.paidPeriods,
    this.rentalType,
    this.startDate,
    this.endDate,
    this.status,
  });

  final String registrationId;
  final String kosName;
  final String kosAccessCode;
  final String roomNumber;
  final String roomType;
  final String? rentalType;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? activeUntil;
  final int paidPeriods;
  final String? status;

  factory ActiveRentHistory.fromJson(Map<String, dynamic> json) {
    return ActiveRentHistory(
      registrationId: json['registrationId'] as String? ?? '',
      kosName: json['kosName'] as String? ?? '',
      kosAccessCode: json['kosAccessCode'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? '',
      roomType: json['roomType'] as String? ?? '',
      rentalType: json['rentalType'] as String?,
      startDate: DateTime.tryParse(json['startDate'] as String? ?? ''),
      endDate: DateTime.tryParse(json['endDate'] as String? ?? ''),
      activeUntil: DateTime.tryParse(json['activeUntil'] as String? ?? ''),
      paidPeriods: _toInt(json['paidPeriods']),
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registrationId': registrationId,
      'kosName': kosName,
      'kosAccessCode': kosAccessCode,
      'roomNumber': roomNumber,
      'roomType': roomType,
      'rentalType': rentalType,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'activeUntil': activeUntil?.toIso8601String(),
      'paidPeriods': paidPeriods,
      'status': status,
    };
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
