import '../core/indonesia_time.dart';

/// Model untuk item dalam pesanan
class OrderItem {
  final String name;
  final int quantity;
  final double price;
  final double subtotal;
  final String? description;

  OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.description,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
      'description': description,
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
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? estimatedTime;
  final String? midtransOrderId;
  final int? subscriptionDays;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final String? subscriptionStatus;
  final DateTime? cancellationRequestedAt;
  final bool canCancel;
  final String? merchantStatus;
  final bool awaitingWeighing;
  final bool readyToPay;
  final String? displayStatusLabel;
  final String? paymentMethodLabel;
  final String? serviceEstimateLabel;
  final double subtotalAmount;
  final double promoDiscountAmount;
  final String? promoName;
  final bool hasPromo;
  final double? actualWeight;

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
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.estimatedTime,
    this.midtransOrderId,
    this.subscriptionDays,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.subscriptionStatus,
    this.cancellationRequestedAt,
    this.canCancel = true,
    this.merchantStatus,
    this.awaitingWeighing = false,
    this.readyToPay = false,
    this.displayStatusLabel,
    this.paymentMethodLabel,
    this.serviceEstimateLabel,
    this.subtotalAmount = 0,
    this.promoDiscountAmount = 0,
    this.promoName,
    this.hasPromo = false,
    this.actualWeight,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? [];
    final items = itemsRaw
        .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
        .toList();
    final deliveryAddress = json['deliveryAddress'] as String?;
    final deliveryLongitude = (json['deliveryLongitude'] as num?)?.toDouble();

    return Order(
      id: json['id'] as String? ?? '',
      databaseId: json['databaseId'] as String?,
      merchantName: json['merchantName'] as String? ?? '',
      service: json['service'] as String? ?? '',
      orderDate: IndonesiaTime.parse(
        json['orderDate'],
        address: deliveryAddress,
        longitude: deliveryLongitude,
      ),
      deliveryDate: IndonesiaTime.tryParse(
        json['deliveryDate'],
        address: deliveryAddress,
        longitude: deliveryLongitude,
      ),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      items: items,
      notes: json['notes'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      paymentStatus: json['paymentStatus'] as String?,
      paymentStatusLabel: json['paymentStatusLabel'] as String?,
      deliveryAddress: deliveryAddress,
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: deliveryLongitude,
      estimatedTime: json['estimatedTime'] as String?,
      midtransOrderId: json['midtransOrderId'] as String?,
      subscriptionDays: (json['subscriptionDays'] as num?)?.toInt(),
      subscriptionStartDate: IndonesiaTime.tryParse(
        json['subscriptionStartDate'],
        address: deliveryAddress,
        longitude: deliveryLongitude,
      ),
      subscriptionEndDate: IndonesiaTime.tryParse(
        json['subscriptionEndDate'],
        address: deliveryAddress,
        longitude: deliveryLongitude,
      ),
      subscriptionStatus: json['subscriptionStatus'] as String?,
      cancellationRequestedAt: IndonesiaTime.tryParse(
        json['cancellationRequestedAt'],
        address: deliveryAddress,
        longitude: deliveryLongitude,
      ),
      canCancel: json['canCancel'] as bool? ?? true,
      merchantStatus: json['merchantStatus'] as String?,
      awaitingWeighing: json['awaitingWeighing'] as bool? ?? false,
      readyToPay: json['readyToPay'] as bool? ?? false,
      displayStatusLabel: json['displayStatusLabel'] as String?,
      paymentMethodLabel: json['paymentMethodLabel'] as String?,
      serviceEstimateLabel: json['serviceEstimateLabel'] as String?,
      subtotalAmount: (json['subtotalAmount'] as num?)?.toDouble() ?? 0,
      promoDiscountAmount:
          (json['promoDiscountAmount'] as num?)?.toDouble() ?? 0,
      promoName: json['promoName'] as String?,
      hasPromo: json['hasPromo'] as bool? ?? false,
      actualWeight: (json['actualWeight'] as num?)?.toDouble(),
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
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'estimatedTime': estimatedTime,
      'midtransOrderId': midtransOrderId,
      'subscriptionDays': subscriptionDays,
      'subscriptionStartDate': subscriptionStartDate?.toIso8601String(),
      'subscriptionEndDate': subscriptionEndDate?.toIso8601String(),
      'subscriptionStatus': subscriptionStatus,
      'cancellationRequestedAt': cancellationRequestedAt?.toIso8601String(),
      'canCancel': canCancel,
      'subtotalAmount': subtotalAmount,
      'promoDiscountAmount': promoDiscountAmount,
      'promoName': promoName,
      'hasPromo': hasPromo,
      'actualWeight': actualWeight,
    };
  }

  String get statusLabel {
    if (displayStatusLabel != null && displayStatusLabel!.isNotEmpty) {
      return displayStatusLabel!;
    }
    switch (status) {
      case 'pending':
        return awaitingWeighing
            ? 'Menunggu penimbangan'
            : 'Menunggu konfirmasi';
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
    if (service == 'catering' &&
        (merchantStatus ?? '').toLowerCase() != 'accepted') {
      return false;
    }
    return !isCod &&
        (status == 'pending' || status == 'confirmed') &&
        (payment.isEmpty ||
            payment == 'waiting_payment' ||
            payment == 'unpaid');
  }

  bool get isCashOnDelivery {
    final method = (paymentMethod ?? '').toLowerCase();
    return method.contains('cod') || method.contains('cash');
  }

  bool get needsOnlinePayment {
    final payment = (paymentStatus ?? '').toLowerCase();
    if (service == 'catering' &&
        (merchantStatus ?? '').toLowerCase() != 'accepted') {
      return false;
    }
    return !awaitingWeighing &&
        !isCashOnDelivery &&
        payment != 'paid' &&
        payment != 'payment_submitted' &&
        payment != 'cod' &&
        payment != 'cancelled';
  }

  bool get isLaundry => service == 'laundry';

  bool get isPaid {
    final payment = (paymentStatus ?? '').toLowerCase();
    return payment == 'paid' || payment == 'payment_submitted';
  }

  bool get isCateringSubscription =>
      service == 'catering' && subscriptionDays != null;

  bool get isSubscriptionCancellationRequested =>
      (subscriptionStatus ?? '').toLowerCase() == 'cancel_requested';

  bool get shouldCancelAsSubscription =>
      isCateringSubscription &&
      isPaid &&
      (merchantStatus ?? '').toLowerCase() != 'pending' &&
      status != 'cancelled';

  bool get canExtendCateringSubscription {
    final subStatus = (subscriptionStatus ?? '').toLowerCase();
    return isCateringSubscription &&
        isPaid &&
        subStatus == 'active' &&
        subStatus != 'cancel_requested' &&
        subStatus != 'ended' &&
        subStatus != 'expired' &&
        status != 'cancelled';
  }
}
