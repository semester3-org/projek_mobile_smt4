class CateringSubscriber {
  const CateringSubscriber({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.merchantId,
    required this.merchantName,
    required this.packageType,
    required this.packageLabel,
    required this.productName,
    required this.productDescription,
    required this.subscriptionStatus,
    required this.totalAmount,
    this.startDate,
    this.endDate,
    this.cancellationRequestedAt,
  });

  final String id;
  final String orderId;
  final String orderCode;
  final String userId;
  final String userName;
  final String userPhone;
  final String merchantId;
  final String merchantName;
  final String packageType;
  final String packageLabel;
  final String productName;
  final String productDescription;
  final String subscriptionStatus;
  final double totalAmount;
  final String? startDate;
  final String? endDate;
  final String? cancellationRequestedAt;

  bool get isActive {
    final s = subscriptionStatus.toLowerCase();
    return s == 'active' ||
        s == 'cancel_requested' ||
        s == 'pending' ||
        s == 'pending_payment';
  }

  bool get isExpired =>
      subscriptionStatus.toLowerCase() == 'expired' ||
      subscriptionStatus.toLowerCase() == 'ended';

  factory CateringSubscriber.fromJson(Map<String, dynamic> json) {
    return CateringSubscriber(
      id: json['id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      orderCode: json['orderCode'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      userPhone: json['userPhone'] as String? ?? '',
      merchantId: json['merchantId'] as String? ?? '',
      merchantName: json['merchantName'] as String? ?? '',
      packageType: json['packageType'] as String? ?? '',
      packageLabel: json['packageLabel'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      productDescription: json['productDescription'] as String? ?? '',
      subscriptionStatus: json['subscriptionStatus'] as String? ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      cancellationRequestedAt: json['cancellationRequestedAt'] as String?,
    );
  }
}
