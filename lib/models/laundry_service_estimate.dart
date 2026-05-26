class LaundryServiceEstimate {
  const LaundryServiceEstimate({
    required this.id,
    required this.serviceName,
    required this.minHours,
    required this.maxHours,
    required this.estimateLabel,
    required this.isActive,
  });

  final String id;
  final String serviceName;
  final int minHours;
  final int maxHours;
  final String estimateLabel;
  final bool isActive;

  factory LaundryServiceEstimate.fromJson(Map<String, dynamic> json) {
    return LaundryServiceEstimate(
      id: json['id'] as String? ?? '',
      serviceName: json['serviceName'] as String? ?? '',
      minHours: (json['minHours'] as num?)?.toInt() ?? 0,
      maxHours: (json['maxHours'] as num?)?.toInt() ?? 0,
      estimateLabel: json['estimateLabel'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
