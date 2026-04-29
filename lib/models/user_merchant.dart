class MerchantMenuItem {
  const MerchantMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;

  factory MerchantMenuItem.fromJson(Map<String, dynamic> json) {
    return MerchantMenuItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
    };
  }
}

class MerchantReview {
  const MerchantReview({
    required this.reviewer,
    required this.rating,
    required this.comment,
    required this.timeLabel,
  });

  final String reviewer;
  final double rating;
  final String comment;
  final String timeLabel;

  factory MerchantReview.fromJson(Map<String, dynamic> json) {
    return MerchantReview(
      reviewer: json['reviewer'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      comment: json['comment'] as String? ?? '',
      timeLabel: json['timeLabel'] as String? ?? '',
    );
  }
}

class UserMerchant {
  const UserMerchant({
    required this.id,
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
    required this.description,
    required this.phone,
    required this.email,
    required this.menuItems,
    required this.reviews,
  });

  final String id;
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
  final String description;
  final String phone;
  final String email;
  final List<MerchantMenuItem> menuItems;
  final List<MerchantReview> reviews;

  bool get isAvailable {
    final normalized = status.toLowerCase();
    return normalized != 'tutup' &&
        normalized != 'sibuk' &&
        normalized != 'closed';
  }

  factory UserMerchant.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'] as List<dynamic>? ?? const [];
    final menuRaw = json['menuItems'] as List<dynamic>? ?? const [];
    final reviewsRaw = json['reviews'] as List<dynamic>? ?? const [];

    return UserMerchant(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'cafe',
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
      description: json['description'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      menuItems: menuRaw
          .map((e) => MerchantMenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      reviews: reviewsRaw
          .map((e) => MerchantReview.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  UserMerchant copyWith({
    double? rating,
    int? reviewCount,
    List<MerchantReview>? reviews,
  }) {
    return UserMerchant(
      id: id,
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
      description: description,
      phone: phone,
      email: email,
      menuItems: menuItems,
      reviews: reviews ?? this.reviews,
    );
  }
}
