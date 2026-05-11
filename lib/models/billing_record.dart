/// Model untuk data tagihan/billing
class BillingRecord {
  final String id;
  final String itemDescription;
  final double amount;
  final DateTime dueDate;
  final DateTime? activeUntil;
  final String status; // 'lunas', 'belum_bayar', 'dibatalkan'
  final String? paymentMethod;
  final DateTime? paymentDate;
  final String? notes;
  final String? kosName;
  final String? kosAccessCode;
  final String? roomNumber;
  final String? roomType;
  final String? registrationStatus;

  BillingRecord({
    required this.id,
    required this.itemDescription,
    required this.amount,
    required this.dueDate,
    this.activeUntil,
    required this.status,
    this.paymentMethod,
    this.paymentDate,
    this.notes,
    this.kosName,
    this.kosAccessCode,
    this.roomNumber,
    this.roomType,
    this.registrationStatus,
  });

  factory BillingRecord.fromJson(Map<String, dynamic> json) {
    return BillingRecord(
      id: json['id'] as String? ?? '',
      itemDescription: json['itemDescription'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate:
          DateTime.tryParse(json['dueDate'] as String? ?? '') ?? DateTime.now(),
      activeUntil: DateTime.tryParse(json['activeUntil'] as String? ?? ''),
      status: json['status'] as String? ?? '',
      paymentMethod: json['paymentMethod'] as String?,
      paymentDate: DateTime.tryParse(json['paymentDate'] as String? ?? ''),
      notes: json['notes'] as String?,
      kosName: json['kosName'] as String?,
      kosAccessCode: json['kosAccessCode'] as String?,
      roomNumber: json['roomNumber'] as String?,
      roomType: json['roomType'] as String?,
      registrationStatus: json['registrationStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemDescription': itemDescription,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'activeUntil': activeUntil?.toIso8601String(),
      'status': status,
      'paymentMethod': paymentMethod,
      'paymentDate': paymentDate?.toIso8601String(),
      'notes': notes,
      'kosName': kosName,
      'kosAccessCode': kosAccessCode,
      'roomNumber': roomNumber,
      'roomType': roomType,
      'registrationStatus': registrationStatus,
    };
  }

  BillingRecord copyWith({
    String? id,
    String? itemDescription,
    double? amount,
    DateTime? dueDate,
    DateTime? activeUntil,
    String? status,
    String? paymentMethod,
    DateTime? paymentDate,
    String? notes,
    String? kosName,
    String? kosAccessCode,
    String? roomNumber,
    String? roomType,
    String? registrationStatus,
  }) {
    return BillingRecord(
      id: id ?? this.id,
      itemDescription: itemDescription ?? this.itemDescription,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      activeUntil: activeUntil ?? this.activeUntil,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes ?? this.notes,
      kosName: kosName ?? this.kosName,
      kosAccessCode: kosAccessCode ?? this.kosAccessCode,
      roomNumber: roomNumber ?? this.roomNumber,
      roomType: roomType ?? this.roomType,
      registrationStatus: registrationStatus ?? this.registrationStatus,
    );
  }

  bool get isLate => status == 'belum_bayar' && DateTime.now().isAfter(dueDate);
  bool get isPaid => status == 'lunas';
  bool get isCancelled => status == 'dibatalkan';
  bool get canPay => !isPaid && !isCancelled;
}
