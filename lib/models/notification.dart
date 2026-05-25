/// Model untuk notifikasi user
class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'payment', 'order', 'catering', 'laundry', 'room', 'promo', 'general'
  final String status; // 'baru', 'dibaca'
  final DateTime createdAt;
  final String? actionUrl;
  final bool hasAction;
  final String? actionButtonText;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.status,
    required this.createdAt,
    this.actionUrl,
    this.hasAction = false,
    this.actionButtonText,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      status: json['status'] as String? ?? 'baru',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      actionUrl: json['actionUrl'] as String? ?? json['action_url'] as String?,
      hasAction: json['hasAction'] as bool? ?? false,
      actionButtonText: json['actionButtonText'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'actionUrl': actionUrl,
      'hasAction': hasAction,
      'actionButtonText': actionButtonText,
    };
  }

  bool get isNew => status == 'baru';
  bool get isUnread => status != 'dibaca';

  AppNotification copyWith({
    String? status,
    bool? hasAction,
    String? actionButtonText,
  }) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      actionUrl: actionUrl,
      hasAction: hasAction ?? this.hasAction,
      actionButtonText: actionButtonText ?? this.actionButtonText,
    );
  }
}
