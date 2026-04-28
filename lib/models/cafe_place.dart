/// Model kafe di sekitar kos.
class CafePlace {
  const CafePlace({
    required this.id,
    required this.name,
    required this.vibe,
    required this.rating,
    required this.imageUrl,
    required this.distanceKm,
  });

  final String id;
  final String name;
  final String vibe;
  final double rating;
  final String imageUrl;
  final double distanceKm;

  factory CafePlace.fromJson(Map<String, dynamic> json) => CafePlace(
  id:          json['id'] as String,
  name:        json['name'] as String,
  vibe:        json['vibe'] as String,
  rating:      (json['rating'] as num).toDouble(),
  imageUrl:    json['imageUrl'] as String,
  distanceKm:  (json['distanceKm'] as num).toDouble(),
);
}
