import '../core/indonesia_time.dart';

class MerchantOrderItem {
  const MerchantOrderItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.description,
    required this.quantity,
    this.quantityValue = 0,
    required this.price,
    required this.subtotal,
    required this.imageUrl,
    this.pricingType = '',
    this.unit = '',
    this.isAddon = false,
  });

  final String id;
  final String productId;
  final String name;
  final String description;
  final int quantity;
  final double quantityValue;
  final double price;
  final double subtotal;
  final String imageUrl;
  final String pricingType;
  final String unit;
  final bool isAddon;

  String get pricingTypeLabel => pricingTypeLabelFor(pricingType);

  factory MerchantOrderItem.fromJson(Map<String, dynamic> json) {
    return MerchantOrderItem(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      quantityValue: (json['quantityValue'] as num?)?.toDouble() ??
          (json['quantity'] as num?)?.toDouble() ??
          0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      imageUrl: json['imageUrl'] as String? ?? '',
      pricingType: json['pricingType'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      isAddon: json['isAddon'] as bool? ?? false,
    );
  }
}

class MerchantLaundryAddon {
  const MerchantLaundryAddon({
    required this.id,
    required this.name,
    required this.price,
    required this.pricingType,
    required this.pricingTypeLabel,
    required this.unit,
    this.quantity = 1,
    this.subtotal = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final double price;
  final String pricingType;
  final String pricingTypeLabel;
  final String unit;
  final double quantity;
  final double subtotal;
  final bool isActive;

  factory MerchantLaundryAddon.fromJson(Map<String, dynamic> json) {
    final pricingType = json['pricingType'] as String? ?? 'flat';
    return MerchantLaundryAddon(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      pricingType: pricingType,
      pricingTypeLabel: json['pricingTypeLabel'] as String? ??
          pricingTypeLabelFor(pricingType),
      unit: json['unit'] as String? ?? pricingUnitFor(pricingType),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'price': price,
      'pricingType': pricingType,
      'isActive': isActive,
    };
  }
}

String pricingTypeLabelFor(String pricingType) {
  switch (pricingType) {
    case 'per_item':
      return 'Per Item';
    case 'flat':
      return 'Flat Price';
    default:
      return 'Per Kg';
  }
}

String pricingUnitFor(String pricingType) {
  switch (pricingType) {
    case 'per_item':
      return '/item';
    case 'flat':
      return 'fixed';
    default:
      return '/kg';
  }
}

class MerchantDeliveryMilestone {
  const MerchantDeliveryMilestone({
    required this.id,
    required this.date,
    required this.slotNumber,
    required this.scheduledTime,
    required this.status,
    this.deliveryNote = '',
    this.deliveryPhotoUrl = '',
    this.deliveredAt,
  });

  final String id;
  final String date;
  final int slotNumber;
  final String scheduledTime;
  final String status;
  final String deliveryNote;
  final String deliveryPhotoUrl;
  final DateTime? deliveredAt;

  factory MerchantDeliveryMilestone.fromJson(Map<String, dynamic> json) {
    return MerchantDeliveryMilestone(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      slotNumber: (json['slotNumber'] as num?)?.toInt() ?? 1,
      scheduledTime: json['scheduledTime'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      deliveryNote: json['deliveryNote'] as String? ?? '',
      deliveryPhotoUrl: json['deliveryPhotoUrl'] as String? ?? '',
      deliveredAt: IndonesiaTime.tryParse(json['deliveredAt']),
    );
  }

  bool get isDelivered => status == 'delivered';
}

class MerchantOrder {
  const MerchantOrder({
    required this.id,
    required this.code,
    this.customerUserId = '',
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.serviceType,
    required this.serviceName,
    required this.createdAt,
    required this.estimatedTime,
    this.estimatedFinishAt,
    required this.status,
    required this.statusLabel,
    required this.statusGroup,
    required this.deliveryAddress,
    required this.totalAmount,
    this.subtotalAmount = 0,
    this.promoName = '',
    this.promoDiscountAmount = 0,
    this.actualWeight,
    required this.paymentMethod,
    required this.paymentMethodLabel,
    required this.paymentStatus,
    required this.paymentStatusLabel,
    required this.serviceEstimateLabel,
    required this.canApprove,
    required this.notes,
    required this.items,
    required this.deliveryMilestones,
    this.availableAddons = const [],
    this.selectedAddons = const [],
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
  final String customerUserId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String serviceType;
  final String serviceName;
  final DateTime createdAt;
  final String estimatedTime;
  final DateTime? estimatedFinishAt;
  final String status;
  final String statusLabel;
  final String statusGroup;
  final String deliveryAddress;
  final double totalAmount;
  final double subtotalAmount;
  final String promoName;
  final double promoDiscountAmount;
  final double? actualWeight;
  final String paymentMethod;
  final String paymentMethodLabel;
  final String paymentStatus;
  final String paymentStatusLabel;
  final String serviceEstimateLabel;
  final bool canApprove;
  final String notes;
  final List<MerchantOrderItem> items;
  final List<MerchantDeliveryMilestone> deliveryMilestones;
  final List<MerchantLaundryAddon> availableAddons;
  final List<MerchantLaundryAddon> selectedAddons;
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
    final rawMilestones =
        json['deliveryMilestones'] as List<dynamic>? ?? const [];
    final rawAvailableAddons =
        json['availableAddons'] as List<dynamic>? ?? const [];
    final rawSelectedAddons =
        json['selectedAddons'] as List<dynamic>? ?? const [];
    final deliveryAddress = json['deliveryAddress'] as String? ?? '';
    final deliveryLongitude = (json['deliveryLongitude'] as num?)?.toDouble();
    return MerchantOrder(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      customerUserId: json['customerUserId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? 'Pelanggan',
      customerPhone: json['customerPhone'] as String? ?? '',
      customerEmail: json['customerEmail'] as String? ?? '',
      serviceType: json['serviceType'] as String? ?? '',
      serviceName: json['serviceName'] as String? ?? '',
      createdAt: IndonesiaTime.parse(
        json['createdAt'],
        address: deliveryAddress,
        longitude: deliveryLongitude,
      ),
      estimatedTime: json['estimatedTime'] as String? ?? '',
      estimatedFinishAt: IndonesiaTime.tryParse(
        json['estimatedFinishAt'],
        address: deliveryAddress,
        longitude: deliveryLongitude,
      ),
      status: json['status'] as String? ?? 'pending',
      statusLabel: json['statusLabel'] as String? ?? 'Pending',
      statusGroup: json['statusGroup'] as String? ?? 'pending',
      deliveryAddress: deliveryAddress,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      subtotalAmount: (json['subtotalAmount'] as num?)?.toDouble() ?? 0,
      promoName: json['promoName'] as String? ?? '',
      promoDiscountAmount:
          (json['promoDiscountAmount'] as num?)?.toDouble() ?? 0,
      actualWeight: (json['actualWeight'] as num?)?.toDouble(),
      paymentMethod: json['paymentMethod'] as String? ?? '',
      paymentMethodLabel: json['paymentMethodLabel'] as String? ?? '',
      paymentStatus: json['paymentStatus'] as String? ?? '',
      paymentStatusLabel: json['paymentStatusLabel'] as String? ?? '',
      serviceEstimateLabel: json['serviceEstimateLabel'] as String? ?? '',
      canApprove: json['canApprove'] as bool? ?? true,
      notes: json['notes'] as String? ?? '',
      items: rawItems
          .map((item) =>
              MerchantOrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      deliveryMilestones: rawMilestones
          .map((item) => MerchantDeliveryMilestone.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(),
      availableAddons: rawAvailableAddons
          .map((item) =>
              MerchantLaundryAddon.fromJson(item as Map<String, dynamic>))
          .toList(),
      selectedAddons: rawSelectedAddons
          .map((item) =>
              MerchantLaundryAddon.fromJson(item as Map<String, dynamic>))
          .toList(),
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: deliveryLongitude,
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
    this.price20Days,
    required this.category,
    required this.unit,
    this.pricingType = 'per_kg',
    this.pricingTypeLabel = 'Per Kg',
    this.durationValue,
    this.durationUnit = 'day',
    this.durationLabel = '',
    this.addons = const [],
    this.hasActivePromo = false,
    this.activePromoName = '',
    required this.imageUrl,
    required this.isActive,
    required this.serviceType,
    this.packageDeliveryType,
    this.mealDeliveryCount = 1,
    this.deliveryTime1 = '07:00',
    this.deliveryTime2,
    this.rating = 0,
    this.reviewCount = 0,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final double? price20Days;
  final String category;
  final String unit;
  final String pricingType;
  final String pricingTypeLabel;
  final int? durationValue;
  final String durationUnit;
  final String durationLabel;
  final List<MerchantLaundryAddon> addons;
  final bool hasActivePromo;
  final String activePromoName;
  final String imageUrl;
  final bool isActive;
  final String serviceType;
  final String? packageDeliveryType;
  final int mealDeliveryCount;
  final String deliveryTime1;
  final String? deliveryTime2;
  final double rating;
  final int reviewCount;

  factory MerchantProduct.fromJson(Map<String, dynamic> json) {
    final rawAddons = json['addons'] as List<dynamic>? ?? const [];
    final pricingType = json['pricingType'] as String? ?? 'per_kg';
    return MerchantProduct(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      price20Days: (json['price20Days'] as num?)?.toDouble(),
      category: json['category'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      pricingType: pricingType,
      pricingTypeLabel: json['pricingTypeLabel'] as String? ??
          pricingTypeLabelFor(pricingType),
      durationValue: (json['durationValue'] as num?)?.toInt(),
      durationUnit: json['durationUnit'] as String? ?? 'day',
      durationLabel: json['durationLabel'] as String? ?? '',
      addons: rawAddons
          .map((item) =>
              MerchantLaundryAddon.fromJson(item as Map<String, dynamic>))
          .toList(),
      hasActivePromo: json['hasActivePromo'] as bool? ?? false,
      activePromoName: json['activePromoName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      serviceType: json['serviceType'] as String? ?? '',
      packageDeliveryType: json['packageDeliveryType'] as String?,
      mealDeliveryCount: (json['mealDeliveryCount'] as num?)?.toInt() ?? 1,
      deliveryTime1: json['deliveryTime1'] as String? ?? '07:00',
      deliveryTime2: json['deliveryTime2'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class MerchantProductReview {
  const MerchantProductReview({
    required this.id,
    required this.productId,
    required this.productName,
    required this.reviewer,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String productId;
  final String productName;
  final String reviewer;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MerchantProductReview.fromJson(Map<String, dynamic> json) {
    return MerchantProductReview(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      reviewer: json['reviewer'] as String? ?? 'User',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      comment: json['comment'] as String? ?? '',
      createdAt: _parseMerchantDate(json['createdAt']),
      updatedAt: _parseMerchantDate(json['updatedAt']),
    );
  }
}

class MerchantProductReviewSummary {
  const MerchantProductReviewSummary({
    required this.product,
    required this.reviews,
  });

  final MerchantProduct product;
  final List<MerchantProductReview> reviews;

  factory MerchantProductReviewSummary.fromJson(Map<String, dynamic> json) {
    final rawReviews = json['reviews'] as List<dynamic>? ?? const [];
    return MerchantProductReviewSummary(
      product: MerchantProduct.fromJson(
        json['product'] as Map<String, dynamic>? ?? const {},
      ),
      reviews: rawReviews
          .map((item) =>
              MerchantProductReview.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MerchantPromo {
  const MerchantPromo({
    required this.id,
    required this.productId,
    required this.productIds,
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
    required this.perUserUsageLimit,
    required this.usedCount,
  });

  final String id;
  final String productId;
  final List<String> productIds;
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
  final int perUserUsageLimit;
  final int usedCount;

  bool get targetsAllProducts => productIds.isEmpty && productId.isEmpty;

  String get targetLabel {
    if (targetsAllProducts) return 'Semua produk';
    if (productIds.length > 1) return '${productIds.length} produk';
    return productName;
  }

  factory MerchantPromo.fromJson(Map<String, dynamic> json) {
    final rawIds = json['productIds'];
    final ids = rawIds is List
        ? rawIds.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final legacyId = json['productId'] as String? ?? '';
    return MerchantPromo(
      id: json['id'] as String? ?? '',
      productId: legacyId,
      productIds: ids.isNotEmpty
          ? ids
          : (legacyId.isNotEmpty ? <String>[legacyId] : <String>[]),
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
      perUserUsageLimit: (json['perUserUsageLimit'] as num?)?.toInt() ?? 1,
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
  final double rating;
  final int reviewCount;
  final String status;
  final String email;

  factory MerchantProfile.fromJson(Map<String, dynamic> json) {
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
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
      email: json['email'] as String? ?? '',
    );
  }
}

DateTime _parseMerchantDate(dynamic raw) {
  if (raw == null) return DateTime.now();
  final text = raw.toString().trim();
  if (text.isEmpty) return DateTime.now();
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return DateTime.now();
  return parsed.isUtc ? parsed.toLocal() : parsed;
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
      createdAt: _parseMerchantDate(json['createdAt']),
      actionUrl: json['actionUrl'] as String?,
      actionButtonText: json['actionButtonText'] as String?,
    );
  }

  bool get isUnread => status != 'dibaca';

  String? get orderIdFromAction {
    final action = actionUrl ?? '';
    if (action.startsWith('order:')) {
      return action.substring('order:'.length);
    }
    return null;
  }
}
