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
  final String? kosName;
  final String? kosAccessCode;
  final String? roomNumber;
  final String? roomType;
  final DateTime? activeUntil;

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
    this.kosName,
    this.kosAccessCode,
    this.roomNumber,
    this.roomType,
    this.activeUntil,
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
      kosName: json['kosName'] as String?,
      kosAccessCode: json['kosAccessCode'] as String?,
      roomNumber: json['roomNumber'] as String?,
      roomType: json['roomType'] as String?,
      activeUntil: DateTime.tryParse(json['activeUntil'] as String? ?? ''),
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
      'kosName': kosName,
      'kosAccessCode': kosAccessCode,
      'roomNumber': roomNumber,
      'roomType': roomType,
      'activeUntil': activeUntil?.toIso8601String(),
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
    String? kosName,
    String? kosAccessCode,
    String? roomNumber,
    String? roomType,
    DateTime? activeUntil,
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
      kosName: kosName ?? this.kosName,
      kosAccessCode: kosAccessCode ?? this.kosAccessCode,
      roomNumber: roomNumber ?? this.roomNumber,
      roomType: roomType ?? this.roomType,
      activeUntil: activeUntil ?? this.activeUntil,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
