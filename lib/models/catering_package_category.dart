class CateringPackageCategory {
  const CateringPackageCategory({
    required this.id,
    required this.categoryName,
    required this.description,
    required this.isActive,
    this.scope = 'merchant',
    this.createdBy = '',
  });

  final String id;
  final String categoryName;
  final String description;
  final bool isActive;
  final String scope;
  final String createdBy;

  factory CateringPackageCategory.fromJson(Map<String, dynamic> json) {
    return CateringPackageCategory(
      id: json['id'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      scope: json['scope'] as String? ?? 'merchant',
      createdBy: json['createdBy'] as String? ?? '',
    );
  }
}
