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
      dueDate: DateTime.tryParse(json['dueDate'] as String? ?? '') ?? DateTime.now(),
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

  bool get isLate => status == 'belum_bayar' && DateTime.now().isAfter(dueDate);
  bool get isPaid => status == 'lunas';
  bool get isCancelled => status == 'dibatalkan';
  bool get canPay => !isPaid && !isCancelled;
}
