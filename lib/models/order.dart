/// Model untuk item dalam pesanan
class OrderItem {
  final String name;
  final int quantity;
  final double price;
  final double subtotal;

  OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
    };
  }
}

/// Model untuk pesanan (order) user
class Order {
  final String id;
  final String? databaseId;
  final String merchantName;
  final String service; // 'laundry', 'catering', 'kos'
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final double totalAmount;
  final String
      status; // 'pending', 'confirmed', 'in_progress', 'completed', 'cancelled'
  final List<OrderItem> items;
  final String? notes;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? paymentStatusLabel;
  final String? deliveryAddress;
  final String? estimatedTime;
  final bool canCancel;

  Order({
    required this.id,
    this.databaseId,
    required this.merchantName,
    required this.service,
    required this.orderDate,
    this.deliveryDate,
    required this.totalAmount,
    required this.status,
    required this.items,
    this.notes,
    this.paymentMethod,
    this.paymentStatus,
    this.paymentStatusLabel,
    this.deliveryAddress,
    this.estimatedTime,
    this.canCancel = true,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? [];
    final items = itemsRaw
        .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return Order(
      id: json['id'] as String? ?? '',
      databaseId: json['databaseId'] as String?,
      merchantName: json['merchantName'] as String? ?? '',
      service: json['service'] as String? ?? '',
      orderDate: DateTime.tryParse(json['orderDate'] as String? ?? '') ??
          DateTime.now(),
      deliveryDate: DateTime.tryParse(json['deliveryDate'] as String? ?? ''),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      items: items,
      notes: json['notes'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      paymentStatus: json['paymentStatus'] as String?,
      paymentStatusLabel: json['paymentStatusLabel'] as String?,
      deliveryAddress: json['deliveryAddress'] as String?,
      estimatedTime: json['estimatedTime'] as String?,
      canCancel: json['canCancel'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'databaseId': databaseId,
      'merchantName': merchantName,
      'service': service,
      'orderDate': orderDate.toIso8601String(),
      'deliveryDate': deliveryDate?.toIso8601String(),
      'totalAmount': totalAmount,
      'status': status,
      'items': items.map((e) => e.toJson()).toList(),
      'notes': notes,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'paymentStatusLabel': paymentStatusLabel,
      'deliveryAddress': deliveryAddress,
      'estimatedTime': estimatedTime,
      'canCancel': canCancel,
    };
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'in_progress':
        return 'Diproses';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  bool get needsPaymentConfirmation {
    final method = (paymentMethod ?? '').toLowerCase();
    final payment = (paymentStatus ?? '').toLowerCase();
    final isCod = method.contains('cod') || method.contains('cash');
    return !isCod &&
        (status == 'pending' || status == 'confirmed') &&
        (payment.isEmpty || payment == 'waiting_payment' || payment == 'unpaid');
  }
}
