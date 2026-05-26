class MerchantOrderItem {
  const MerchantOrderItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.description,
    required this.quantity,
    required this.price,
    required this.subtotal,
    required this.imageUrl,
  });

  final String id;
  final String productId;
  final String name;
  final String description;
  final int quantity;
  final double price;
  final double subtotal;
  final String imageUrl;

  factory MerchantOrderItem.fromJson(Map<String, dynamic> json) {
    return MerchantOrderItem(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }
}

class MerchantOrder {
  const MerchantOrder({
    required this.id,
    required this.code,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.serviceType,
    required this.serviceName,
    required this.createdAt,
    required this.estimatedTime,
    required this.status,
    required this.statusLabel,
    required this.statusGroup,
    required this.deliveryAddress,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.paymentStatusLabel,
    required this.canApprove,
    required this.notes,
    required this.items,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.midtransOrderId,
    this.subscriptionDays,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.subscriptionStatus,
    this.cancellationRequestedAt,
  });

  final String id;
  final String code;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String serviceType;
  final String serviceName;
  final DateTime createdAt;
  final String estimatedTime;
  final String status;
  final String statusLabel;
  final String statusGroup;
  final String deliveryAddress;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String paymentStatusLabel;
  final bool canApprove;
  final String notes;
  final List<MerchantOrderItem> items;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? midtransOrderId;
  final int? subscriptionDays;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final String? subscriptionStatus;
  final DateTime? cancellationRequestedAt;

  factory MerchantOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return MerchantOrder(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      customerName: json['customerName'] as String? ?? 'Pelanggan',
      customerPhone: json['customerPhone'] as String? ?? '',
      customerEmail: json['customerEmail'] as String? ?? '',
      serviceType: json['serviceType'] as String? ?? '',
      serviceName: json['serviceName'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      estimatedTime: json['estimatedTime'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      statusLabel: json['statusLabel'] as String? ?? 'Pending',
      statusGroup: json['statusGroup'] as String? ?? 'pending',
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod'] as String? ?? '',
      paymentStatus: json['paymentStatus'] as String? ?? '',
      paymentStatusLabel: json['paymentStatusLabel'] as String? ?? '',
      canApprove: json['canApprove'] as bool? ?? true,
      notes: json['notes'] as String? ?? '',
      items: rawItems
          .map((item) =>
              MerchantOrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
      midtransOrderId: json['midtransOrderId'] as String?,
      subscriptionDays: (json['subscriptionDays'] as num?)?.toInt(),
      subscriptionStartDate:
          DateTime.tryParse(json['subscriptionStartDate'] as String? ?? ''),
      subscriptionEndDate:
          DateTime.tryParse(json['subscriptionEndDate'] as String? ?? ''),
      subscriptionStatus: json['subscriptionStatus'] as String?,
      cancellationRequestedAt:
          DateTime.tryParse(json['cancellationRequestedAt'] as String? ?? ''),
    );
  }

  bool get isCateringSubscription =>
      serviceType == 'catering' && subscriptionDays != null;

  bool get isSubscriptionCancellationRequested =>
      (subscriptionStatus ?? '').toLowerCase() == 'cancel_requested';
}

class MerchantDashboard {
  const MerchantDashboard({
    required this.merchantName,
    required this.merchantType,
    required this.totalOrders,
    required this.processingOrders,
    required this.activeProducts,
    required this.activePromos,
    required this.recentOrders,
  });

  final String merchantName;
  final String merchantType;
  final int totalOrders;
  final int processingOrders;
  final int activeProducts;
  final int activePromos;
  final List<MerchantOrder> recentOrders;

  factory MerchantDashboard.fromJson(Map<String, dynamic> json) {
    final rawOrders = json['recentOrders'] as List<dynamic>? ?? const [];
    return MerchantDashboard(
      merchantName: json['merchantName'] as String? ?? 'Merchant',
      merchantType: json['merchantType'] as String? ?? 'laundry',
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      processingOrders: (json['processingOrders'] as num?)?.toInt() ?? 0,
      activeProducts: (json['activeProducts'] as num?)?.toInt() ?? 0,
      activePromos: (json['activePromos'] as num?)?.toInt() ?? 0,
      recentOrders: rawOrders
          .map((item) => MerchantOrder.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MerchantProduct {
  const MerchantProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.unit,
    required this.imageUrl,
    required this.isActive,
    required this.serviceType,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String unit;
  final String imageUrl;
  final bool isActive;
  final String serviceType;

  factory MerchantProduct.fromJson(Map<String, dynamic> json) {
    return MerchantProduct(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      serviceType: json['serviceType'] as String? ?? '',
    );
  }
}

class MerchantPromo {
  const MerchantPromo({
    required this.id,
    required this.productId,
    required this.productName,
    required this.name,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    required this.maxDiscountAmount,
    required this.startAt,
    required this.endAt,
    required this.isActive,
    required this.status,
    required this.usageLimit,
    required this.usedCount,
  });

  final String id;
  final String productId;
  final String productName;
  final String name;
  final String description;
  final String discountType;
  final double discountValue;
  final double minOrderAmount;
  final double maxDiscountAmount;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isActive;
  final String status;
  final int? usageLimit;
  final int usedCount;

  factory MerchantPromo.fromJson(Map<String, dynamic> json) {
    return MerchantPromo(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? 'Semua produk',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      discountType: json['discountType'] as String? ?? 'percentage',
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
      minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble() ?? 0,
      maxDiscountAmount: (json['maxDiscountAmount'] as num?)?.toDouble() ?? 0,
      startAt: DateTime.tryParse(json['startAt'] as String? ?? ''),
      endAt: DateTime.tryParse(json['endAt'] as String? ?? ''),
      isActive: json['isActive'] as bool? ?? true,
      status: json['status'] as String? ?? 'scheduled',
      usageLimit: (json['usageLimit'] as num?)?.toInt(),
      usedCount: (json['usedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class MerchantProfile {
  const MerchantProfile({
    required this.id,
    required this.merchantCode,
    required this.merchantType,
    required this.businessName,
    required this.description,
    required this.phone,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.photoUrl,
    required this.openTime,
    required this.closeTime,
    required this.categories,
    required this.rating,
    required this.reviewCount,
    required this.status,
    required this.email,
  });

  final String id;
  final String merchantCode;
  final String merchantType;
  final String businessName;
  final String description;
  final String phone;
  final String address;
  final double? latitude;
  final double? longitude;
  final String photoUrl;
  final String openTime;
  final String closeTime;
  final List<String> categories;
  final double rating;
  final int reviewCount;
  final String status;
  final String email;

  factory MerchantProfile.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'] as List<dynamic>? ?? const [];
    return MerchantProfile(
      id: json['id'] as String? ?? '',
      merchantCode: json['merchantCode'] as String? ?? '',
      merchantType: json['merchantType'] as String? ?? 'laundry',
      businessName: json['businessName'] as String? ?? 'Merchant',
      description: json['description'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      photoUrl: json['photoUrl'] as String? ?? '',
      openTime: json['openTime'] as String? ?? '08:00',
      closeTime: json['closeTime'] as String? ?? '21:00',
      categories: rawCategories.map((item) => item.toString()).toList(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
      email: json['email'] as String? ?? '',
    );
  }
}

class MerchantNotification {
  const MerchantNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.status,
    required this.createdAt,
    this.actionUrl,
    this.actionButtonText,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final String status;
  final DateTime createdAt;
  final String? actionUrl;
  final String? actionButtonText;

  factory MerchantNotification.fromJson(Map<String, dynamic> json) {
    return MerchantNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'info',
      status: json['status'] as String? ?? 'dibaca',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      actionUrl: json['actionUrl'] as String?,
      actionButtonText: json['actionButtonText'] as String?,
    );
  }

  bool get isUnread => status != 'dibaca';
}
