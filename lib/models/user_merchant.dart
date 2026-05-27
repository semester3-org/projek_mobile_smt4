class MerchantMenuItem {
  const MerchantMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.category = '',
    this.unit = '',
    this.price20Days,
    this.price30Days,
    this.packageDeliveryType,
  });

  final String id;
  final String name;
  final String description;

  /// Harga Full Day (catering) atau harga layanan (laundry).
  final double price;
  final String imageUrl;
  final String category;
  final String unit;

  /// Harga Weekday 30 hari: dikirim Senin-Jumat, weekend libur.
  final double? price20Days;
  final double? price30Days;
  final String? packageDeliveryType;

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
    final price30 = (json['price30Days'] as num?)?.toDouble() ??
        (json['price'] as num?)?.toDouble() ??
        0;
    return MerchantMenuItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: price30,
      imageUrl: json['imageUrl'] as String? ?? '',
      category: json['category'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      price20Days: (json['price20Days'] as num?)?.toDouble(),
      price30Days: price30 > 0 ? price30 : null,
      packageDeliveryType: json['packageDeliveryType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'unit': unit,
      'price20Days': price20Days,
      'price30Days': price30Days ?? price,
      'packageDeliveryType': packageDeliveryType,
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

  factory MerchantReview.fromJson(Map<String, dynamic> json) {
    return MerchantReview(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      reviewer: json['reviewer'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      comment: json['comment'] as String? ?? '',
      timeLabel: json['timeLabel'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      deletedAt: json['deletedAt'] as String? ?? '',
      isDeleted: json['isDeleted'] as bool? ?? false,
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
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Produk',
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
        json['reviewableProducts'] as List<dynamic>? ?? const [];
    final reviewsRaw = json['myReviews'] as List<dynamic>? ?? const [];
    return UserMerchantReviewState(
      reviewableProducts: productsRaw
          .map((e) => ReviewableProduct.fromJson(e as Map<String, dynamic>))
          .where((e) => e.id.isNotEmpty)
          .toList(),
      myReviews: reviewsRaw
          .map((e) => MerchantReview.fromJson(e as Map<String, dynamic>))
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
    final tagsRaw = json['tags'] as List<dynamic>? ?? const [];
    final menuRaw = json['menuItems'] as List<dynamic>? ?? const [];
    final reviewsRaw = json['reviews'] as List<dynamic>? ?? const [];

    return UserMerchant(
      id: json['id'] as String? ?? '',
      placeId: json['placeId'] as String? ?? '',
      merchantId: json['merchantId'] as String? ?? json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'laundry',
      name: json['name'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      address: json['address'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      imageUrl: json['imageUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'Tersedia',
      tags: tagsRaw.map((e) => e.toString()).toList(),
      minPrice: (json['minPrice'] as num?)?.toDouble() ?? 0,
      priceUnit: json['priceUnit'] as String? ?? '',
      eta: json['eta'] as String? ?? '',
      openHours: json['openHours'] as String? ?? '',
      openTime: json['openTime'] as String? ?? '',
      closeTime: json['closeTime'] as String? ?? '',
      isOpenNow: json['isOpenNow'] as bool? ?? true,
      description: json['description'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      menuItems: menuRaw
          .map((e) => MerchantMenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      reviews: reviewsRaw
          .map((e) => MerchantReview.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasDistanceEstimate: json['hasDistanceEstimate'] as bool? ?? false,
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
