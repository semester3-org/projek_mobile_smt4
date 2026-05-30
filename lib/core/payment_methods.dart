/// Utilities untuk payment methods formatting dan grouping
class PaymentMethodHelper {
  PaymentMethodHelper._();

  // Formatted payment method names with clean presentation
  static const Map<String, String> displayNames = {
    'bca': 'Transfer Bank BCA',
    'bca_va': 'Transfer Bank BCA',
    'mandiri': 'Transfer Bank Mandiri',
    'echannel': 'Transfer Bank Mandiri',
    'bni': 'Transfer Bank BNI',
    'bni_va': 'Transfer Bank BNI',
    'cimb': 'Transfer Bank CIMB Niaga',
    'cimb_clicks': 'Transfer Bank CIMB Niaga',
    'bank_transfer': 'Transfer Bank',

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
    'bca': 'Transfer Bank',
    'bca_va': 'Transfer Bank',
    'mandiri': 'Transfer Bank',
    'echannel': 'Transfer Bank',
    'bni': 'Transfer Bank',
    'bni_va': 'Transfer Bank',
    'cimb': 'Transfer Bank',
    'cimb_clicks': 'Transfer Bank',
    'bank_transfer': 'Transfer Bank',

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
    return method != null && method.isNotEmpty && !isCashOnDelivery(method);
  }

  /// Opsi pembayaran untuk form checkout user.
  static List<String> checkoutOptionKeys({required bool isLaundry}) {
    const bank = ['bca', 'mandiri', 'bni', 'cimb'];
    const wallet = ['gopay', 'dana', 'shopeepay', 'ovo'];
    const other = ['qris'];
    if (isLaundry) {
      return ['cod', ...bank, ...wallet, ...other];
    }
    return [...bank, ...wallet, ...other];
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
