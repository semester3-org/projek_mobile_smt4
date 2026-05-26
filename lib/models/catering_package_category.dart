class CateringPackageCategory {
  const CateringPackageCategory({
    required this.id,
    required this.categoryName,
    required this.description,
    required this.isActive,
  });

  final String id;
  final String categoryName;
  final String description;
  final bool isActive;

  factory CateringPackageCategory.fromJson(Map<String, dynamic> json) {
    return CateringPackageCategory(
      id: json['id'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
