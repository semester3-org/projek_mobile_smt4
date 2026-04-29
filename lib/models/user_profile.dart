/// Model untuk profil user lengkap
class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? phone;
  final String? address;
  final String role;
  final String? photoUrl;
  final String? kosName;
  final String? kosAccessCode;
  final String? roomNumber;
  final String? roomType;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.phone,
    this.address,
    required this.role,
    this.photoUrl,
    this.kosName,
    this.kosAccessCode,
    this.roomNumber,
    this.roomType,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      role: json['role'] as String? ?? 'user',
      photoUrl: json['photoUrl'] as String?,
      kosName: json['kosName'] as String?,
      kosAccessCode: json['kosAccessCode'] as String?,
      roomNumber: json['roomNumber'] as String?,
      roomType: json['roomType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'phone': phone,
      'address': address,
      'role': role,
      'photoUrl': photoUrl,
      'kosName': kosName,
      'kosAccessCode': kosAccessCode,
      'roomNumber': roomNumber,
      'roomType': roomType,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phone,
    String? address,
    String? role,
    String? photoUrl,
    String? kosName,
    String? kosAccessCode,
    String? roomNumber,
    String? roomType,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      kosName: kosName ?? this.kosName,
      kosAccessCode: kosAccessCode ?? this.kosAccessCode,
      roomNumber: roomNumber ?? this.roomNumber,
      roomType: roomType ?? this.roomType,
    );
  }
}
