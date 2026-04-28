/// Model laundry terdekat.
class LaundryPlace {
  const LaundryPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.rating,
    required this.distanceKm,
    required this.imageUrl,
    required this.openHours,
  });

  final String id;
  final String name;
  final String address;
  final double rating;
  final double distanceKm;
  final String imageUrl;
  final String openHours;

  factory LaundryPlace.fromJson(Map<String, dynamic> json) => LaundryPlace(
  id:          json['id'] as String,
  name:        json['name'] as String,
  address:     json['address'] as String,
  rating:      (json['rating'] as num).toDouble(),
  distanceKm:  (json['distanceKm'] as num).toDouble(),
  imageUrl:    json['imageUrl'] as String,
  openHours:   json['openHours'] as String,
);
}
