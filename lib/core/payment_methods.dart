/// Utilities untuk payment methods formatting dan grouping
class PaymentMethodHelper {
  PaymentMethodHelper._();

  // Formatted payment method names with clean presentation
  static const Map<String, String> displayNames = {
    // Bank Transfer
    'bank_transfer': 'Bank Transfer',
    'bca': 'Bank BCA',
    'mandiri': 'Bank Mandiri',
    'bni': 'Bank BNI',
    'cimb': 'Bank CIMB Niaga',

    // E-Wallet
    'gopay': 'GoPay',
    'ovo': 'OVO',
    'dana': 'DANA',
    'shopeepay': 'ShopeePay',
    'linkaja': 'LinkAja',

    // QRIS
    'qris': 'QRIS',

    // Credit Card
    'credit_card': 'Kartu Kredit',
    'debit_card': 'Kartu Debit',

    // Cash on Delivery
    'cod': 'Bayar di Tempat (COD)',
    'cash': 'Bayar di Tempat (COD)',
  };

  // Category grouping
  static const Map<String, String> categories = {
    // Bank Transfer Category
    'bank_transfer': 'Bank',
    'bca': 'Bank',
    'mandiri': 'Bank',
    'bni': 'Bank',
    'cimb': 'Bank',

    // E-Wallet Category
    'gopay': 'E-Wallet',
    'ovo': 'E-Wallet',
    'dana': 'E-Wallet',
    'shopeepay': 'E-Wallet',
    'linkaja': 'E-Wallet',

    // QRIS Category
    'qris': 'QRIS',

    // Card Category
    'credit_card': 'Kartu Kredit/Debit',
    'debit_card': 'Kartu Kredit/Debit',

    // COD Category
    'cod': 'Bayar di Tempat',
    'cash': 'Bayar di Tempat',
  };

  /// Get formatted display name for a payment method
  static String getDisplayName(String? method) {
    if (method == null || method.isEmpty) return 'Metode Pembayaran';
    final normalized = method.toLowerCase().trim();
    return displayNames[normalized] ?? method;
  }

  /// Get category for a payment method
  static String getCategory(String? method) {
    if (method == null || method.isEmpty) return 'Lainnya';
    final normalized = method.toLowerCase().trim();
    return categories[normalized] ?? 'Lainnya';
  }

  /// Check if payment method is COD/Cash
  static bool isCashOnDelivery(String? method) {
    if (method == null || method.isEmpty) return false;
    final normalized = method.toLowerCase();
    return normalized.contains('cod') || normalized.contains('cash');
  }

  /// Check if payment method requires online processing
  static bool requiresOnlineProcessing(String? method) {
    return method != null &&
        method.isNotEmpty &&
        !isCashOnDelivery(method);
  }

  /// Get all payment methods grouped by category
  static Map<String, List<String>> getGroupedMethods() {
    final Map<String, List<String>> grouped = {
      'Bank': [],
      'E-Wallet': [],
      'QRIS': [],
      'Kartu Kredit/Debit': [],
      'Bayar di Tempat': [],
    };

    categories.forEach((method, category) {
      grouped[category]?.add(getDisplayName(method));
    });

    return grouped;
  }
}
