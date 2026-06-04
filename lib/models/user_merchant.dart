String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

double _readDouble(
  Map<String, dynamic> json,
  List<String> keys, {
  double fallback = 0,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

double? _readNullableDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

int _readInt(
  Map<String, dynamic> json,
  List<String> keys, {
  int fallback = 0,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

bool _readBool(
  Map<String, dynamic> json,
  List<String> keys, {
  bool fallback = false,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (['1', 'true', 'yes', 'aktif', 'active'].contains(normalized)) {
        return true;
      }
      if (['0', 'false', 'no', 'nonaktif', 'inactive'].contains(normalized)) {
        return false;
      }
    }
  }
  return fallback;
}

List<dynamic> _readList(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is List) return value;
  }
  return const [];
}

class MerchantMenuAddon {
  const MerchantMenuAddon({
    required this.id,
    required this.name,
    required this.price,
    this.pricingType = 'flat',
    this.pricingTypeLabel = 'Flat Price',
    this.unit = 'fixed',
    this.isActive = true,
  });

  final String id;
  final String name;
  final double price;
  final String pricingType;
  final String pricingTypeLabel;
  final String unit;
  final bool isActive;

  factory MerchantMenuAddon.fromJson(Map<String, dynamic> json) {
    return MerchantMenuAddon(
      id: _readString(json, const ['id']),
      name: _readString(json, const ['name', 'nama_produk']),
      price: _readDouble(json, const ['price', 'harga']),
      pricingType: _readString(json, const ['pricingType', 'pricing_type'],
          fallback: 'flat'),
      pricingTypeLabel: _readString(
        json,
        const ['pricingTypeLabel', 'pricing_type_label'],
        fallback: 'Flat Price',
      ),
      unit: _readString(json, const ['unit', 'satuan'], fallback: 'fixed'),
      isActive:
          _readBool(json, const ['isActive', 'is_active'], fallback: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'pricingType': pricingType,
      'pricingTypeLabel': pricingTypeLabel,
      'unit': unit,
      'isActive': isActive,
    };
  }
}

class MerchantMenuItem {
  const MerchantMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.merchantId = '',
    this.merchantName = '',
    this.merchantType = '',
    this.category = '',
    this.unit = '',
    this.price20Days,
    this.price30Days,
    this.packageDeliveryType,
    this.mealDeliveryCount = 1,
    this.deliveryTime1 = '07:00',
    this.deliveryTime2,
    this.rating = 0,
    this.reviewCount = 0,
    this.hasPromo = false,
    this.originalPrice,
    this.promoPrice,
    this.promoDiscountAmount,
    this.promoDiscountType,
    this.promoDiscountValue,
    this.promoLabel,
    this.promoDescription,
    this.pricingType = '',
    this.pricingTypeLabel = '',
    this.durationLabel = '',
    this.addons = const [],
  });

  final String id;
  final String name;
  final String description;
  final String merchantId;
  final String merchantName;
  final String merchantType;

  /// Harga Full Day (catering) atau harga layanan (laundry).
  final double price;
  final String imageUrl;
  final String category;
  final String unit;

  /// Harga Weekday 30 hari: dikirim Senin-Jumat, weekend libur.
  final double? price20Days;
  final double? price30Days;
  final String? packageDeliveryType;
  final int mealDeliveryCount;
  final String deliveryTime1;
  final String? deliveryTime2;
  final double rating;
  final int reviewCount;
  final bool hasPromo;
  final double? originalPrice;
  final double? promoPrice;
  final double? promoDiscountAmount;
  final String? promoDiscountType;
  final double? promoDiscountValue;
  final String? promoLabel;
  final String? promoDescription;
  final String pricingType;
  final String pricingTypeLabel;
  final String durationLabel;
  final List<MerchantMenuAddon> addons;

  bool get hasWeekdayPrice => price20Days != null && price20Days! > 0;

  double cateringPriceForDays(int days) {
    if (days == 20 && hasWeekdayPrice) {
      return price20Days!;
    }
    if (days == 30 && price30Days != null && price30Days! > 0) {
      return price30Days!;
    }
    if (days == 30) return price;
    if (days == 20 && price20Days != null && price20Days! > 0) {
      return price20Days!;
    }
    return price;
  }

  factory MerchantMenuItem.fromJson(Map<String, dynamic> json) {
    final price30 = _readDouble(
      json,
      const ['price30Days', 'price_30_days', 'price', 'harga'],
    );
    final addonsRaw = _readList(json, const ['addons', 'add_ons']);
    final imageUrl = [
      json['imageUrl'],
      json['image_url'],
      json['photoUrl'],
      json['photo_url'],
    ]
        .map((value) => value?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    return MerchantMenuItem(
      id: _readString(json, const ['id']),
      name: _readString(json, const ['name', 'nama_produk']),
      description: _readString(json, const ['description', 'deskripsi']),
      price: price30,
      imageUrl: imageUrl,
      merchantId: _readString(json, const ['merchantId', 'merchant_id']),
      merchantName: _readString(json, const ['merchantName', 'merchant_name']),
      merchantType: _readString(json, const ['merchantType', 'merchant_type']),
      category: _readString(json, const ['category', 'category_name']),
      unit: _readString(json, const ['unit', 'satuan']),
      price20Days: _readNullableDouble(
        json,
        const ['price20Days', 'price_20_days'],
      ),
      price30Days: price30 > 0 ? price30 : null,
      packageDeliveryType: _readString(
        json,
        const ['packageDeliveryType', 'package_delivery_type'],
      ),
      mealDeliveryCount: _readInt(
        json,
        const ['mealDeliveryCount', 'meal_delivery_count'],
        fallback: 1,
      ),
      deliveryTime1: _readString(
        json,
        const ['deliveryTime1', 'delivery_time_1'],
        fallback: '07:00',
      ),
      deliveryTime2:
          _readString(json, const ['deliveryTime2', 'delivery_time_2']),
      rating: _readDouble(json, const ['rating']),
      reviewCount: _readInt(json, const ['reviewCount', 'review_count']),
      hasPromo: _readBool(json, const ['hasPromo', 'has_promo']),
      originalPrice: _readNullableDouble(
        json,
        const ['originalPrice', 'original_price'],
      ),
      promoPrice:
          _readNullableDouble(json, const ['promoPrice', 'promo_price']),
      promoDiscountAmount: _readNullableDouble(
        json,
        const ['promoDiscountAmount', 'promo_discount_amount'],
      ),
      promoDiscountType: _readString(
        json,
        const ['promoDiscountType', 'promo_discount_type'],
      ),
      promoDiscountValue: _readNullableDouble(
        json,
        const ['promoDiscountValue', 'promo_discount_value'],
      ),
      promoLabel: _readString(json, const ['promoLabel', 'promo_label']),
      promoDescription: _readString(
        json,
        const ['promoDescription', 'promo_description'],
      ),
      pricingType: _readString(json, const ['pricingType', 'pricing_type']),
      pricingTypeLabel: _readString(
        json,
        const ['pricingTypeLabel', 'pricing_type_label'],
      ),
      durationLabel:
          _readString(json, const ['durationLabel', 'duration_label']),
      addons: addonsRaw
          .whereType<Map>()
          .map((addon) => MerchantMenuAddon.fromJson(
                Map<String, dynamic>.from(addon),
              ))
          .where((addon) => addon.id.isNotEmpty && addon.name.isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'merchantType': merchantType,
      'category': category,
      'unit': unit,
      'price20Days': price20Days,
      'price30Days': price30Days ?? price,
      'packageDeliveryType': packageDeliveryType,
      'mealDeliveryCount': mealDeliveryCount,
      'deliveryTime1': deliveryTime1,
      'deliveryTime2': deliveryTime2,
      'rating': rating,
      'reviewCount': reviewCount,
      'hasPromo': hasPromo,
      'originalPrice': originalPrice,
      'promoPrice': promoPrice,
      'promoDiscountAmount': promoDiscountAmount,
      'promoDiscountType': promoDiscountType,
      'promoDiscountValue': promoDiscountValue,
      'promoLabel': promoLabel,
      'promoDescription': promoDescription,
      'pricingType': pricingType,
      'pricingTypeLabel': pricingTypeLabel,
      'durationLabel': durationLabel,
      'addons': addons.map((addon) => addon.toJson()).toList(),
    };
  }
}

class MerchantReview {
  const MerchantReview({
    this.id = '',
    this.productId = '',
    this.productName = '',
    this.userId = '',
    required this.reviewer,
    required this.rating,
    required this.comment,
    required this.timeLabel,
    this.createdAt = '',
    this.updatedAt = '',
    this.deletedAt = '',
    this.isDeleted = false,
    this.editCount = 0,
    this.remainingEditAttempts = 3,
  });

  final String id;
  final String productId;
  final String productName;
  final String userId;
  final String reviewer;
  final double rating;
  final String comment;
  final String timeLabel;
  final String createdAt;
  final String updatedAt;
  final String deletedAt;
  final bool isDeleted;
  final int editCount;
  final int remainingEditAttempts;

  factory MerchantReview.fromJson(Map<String, dynamic> json) {
    final editCount = _readInt(json, const ['editCount', 'edit_count']);
    return MerchantReview(
      id: _readString(json, const ['id']),
      productId: _readString(json, const ['productId', 'product_id']),
      productName: _readString(json, const ['productName', 'product_name']),
      userId: _readString(json, const ['userId', 'user_id']),
      reviewer: _readString(json, const ['reviewer', 'display_name']),
      rating: _readDouble(json, const ['rating']),
      comment: _readString(json, const ['comment']),
      timeLabel: _readString(json, const ['timeLabel', 'time_label']),
      createdAt: _readString(json, const ['createdAt', 'created_at']),
      updatedAt: _readString(json, const ['updatedAt', 'updated_at']),
      deletedAt: _readString(json, const ['deletedAt', 'deleted_at']),
      isDeleted: _readBool(json, const ['isDeleted', 'is_deleted']),
      editCount: editCount,
      remainingEditAttempts: _readInt(
        json,
        const ['remainingEditAttempts', 'remaining_edit_attempts'],
        fallback: editCount < 3 ? 3 - editCount : 0,
      ),
    );
  }
}

class ReviewableProduct {
  const ReviewableProduct({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory ReviewableProduct.fromJson(Map<String, dynamic> json) {
    return ReviewableProduct(
      id: _readString(json, const ['id']),
      name:
          _readString(json, const ['name', 'nama_produk'], fallback: 'Produk'),
    );
  }
}

class UserMerchantReviewState {
  const UserMerchantReviewState({
    required this.reviewableProducts,
    required this.myReviews,
  });

  final List<ReviewableProduct> reviewableProducts;
  final List<MerchantReview> myReviews;

  factory UserMerchantReviewState.fromJson(Map<String, dynamic> json) {
    final productsRaw =
        _readList(json, const ['reviewableProducts', 'reviewable_products']);
    final reviewsRaw = _readList(json, const ['myReviews', 'my_reviews']);
    return UserMerchantReviewState(
      reviewableProducts: productsRaw
          .whereType<Map>()
          .map((e) => ReviewableProduct.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList(),
      myReviews: reviewsRaw
          .whereType<Map>()
          .map((e) => MerchantReview.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class UserMerchant {
  const UserMerchant({
    required this.id,
    this.placeId = '',
    this.merchantId = '',
    required this.type,
    required this.name,
    required this.subtitle,
    required this.address,
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    required this.imageUrl,
    required this.status,
    required this.tags,
    required this.minPrice,
    required this.priceUnit,
    required this.eta,
    required this.openHours,
    this.openTime = '',
    this.closeTime = '',
    this.isOpenNow = true,
    required this.description,
    required this.phone,
    required this.email,
    required this.menuItems,
    required this.reviews,
    this.hasDistanceEstimate = false,
  });

  final String id;
  final String placeId;
  final String merchantId;
  final String type;
  final String name;
  final String subtitle;
  final String address;
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final String imageUrl;
  final String status;
  final List<String> tags;
  final double minPrice;
  final String priceUnit;
  final String eta;
  final String openHours;
  final String openTime;
  final String closeTime;
  final bool isOpenNow;
  final String description;
  final String phone;
  final String email;
  final List<MerchantMenuItem> menuItems;
  final List<MerchantReview> reviews;
  final bool hasDistanceEstimate;

  bool get isAvailable {
    final normalized = status.toLowerCase();
    if (normalized == 'sibuk') return false;
    if (!isOpenNow) return false;
    return normalized != 'tutup' && normalized != 'closed';
  }

  factory UserMerchant.fromJson(Map<String, dynamic> json) {
    final tagsRaw = _readList(json, const ['tags']);
    final menuRaw = _readList(json, const ['menuItems', 'menu_items']);
    final reviewsRaw = _readList(json, const ['reviews']);

    final imageUrl = [
      json['imageUrl'],
      json['image_url'],
      json['photoUrl'],
      json['photo_url'],
    ]
        .map((value) => value?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    return UserMerchant(
      id: _readString(json, const ['id']),
      placeId: _readString(json, const ['placeId', 'place_id']),
      merchantId: _readString(
        json,
        const ['merchantId', 'merchant_id', 'id'],
      ),
      type: _readString(json, const ['type', 'merchant_type'],
          fallback: 'laundry'),
      name: _readString(json, const ['name', 'business_name']),
      subtitle: _readString(json, const ['subtitle']),
      address: _readString(json, const ['address']),
      rating: _readDouble(json, const ['rating']),
      reviewCount: _readInt(json, const ['reviewCount', 'review_count']),
      distanceKm: _readDouble(json, const ['distanceKm', 'distance_km']),
      imageUrl: imageUrl,
      status: _readString(json, const ['status'], fallback: 'Tersedia'),
      tags: tagsRaw.map((e) => e.toString()).toList(),
      minPrice: _readDouble(json, const ['minPrice', 'min_price']),
      priceUnit: _readString(json, const ['priceUnit', 'price_unit']),
      eta: _readString(json, const ['eta']),
      openHours: _readString(json, const ['openHours', 'open_hours']),
      openTime: _readString(json, const ['openTime', 'open_time']),
      closeTime: _readString(json, const ['closeTime', 'close_time']),
      isOpenNow:
          _readBool(json, const ['isOpenNow', 'is_open_now'], fallback: true),
      description: _readString(json, const ['description']),
      phone: _readString(json, const ['phone']),
      email: _readString(json, const ['email']),
      menuItems: menuRaw
          .whereType<Map>()
          .map((e) => MerchantMenuItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      reviews: reviewsRaw
          .whereType<Map>()
          .map((e) => MerchantReview.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasDistanceEstimate: _readBool(
        json,
        const ['hasDistanceEstimate', 'has_distance_estimate'],
      ),
    );
  }

  UserMerchant copyWith({
    double? rating,
    int? reviewCount,
    List<MerchantReview>? reviews,
    bool? hasDistanceEstimate,
  }) {
    return UserMerchant(
      id: id,
      placeId: placeId,
      merchantId: merchantId,
      type: type,
      name: name,
      subtitle: subtitle,
      address: address,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      distanceKm: distanceKm,
      imageUrl: imageUrl,
      status: status,
      tags: tags,
      minPrice: minPrice,
      priceUnit: priceUnit,
      eta: eta,
      openHours: openHours,
      openTime: openTime,
      closeTime: closeTime,
      isOpenNow: isOpenNow,
      description: description,
      phone: phone,
      email: email,
      menuItems: menuItems,
      reviews: reviews ?? this.reviews,
      hasDistanceEstimate: hasDistanceEstimate ?? this.hasDistanceEstimate,
    );
  }
}
