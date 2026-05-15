enum UserRole {
  admin,
  merchant,
  user,
  owner,
}

enum MerchantType {
  laundry,
  catering,
}

extension MerchantTypeLabel on MerchantType {
  String get label {
    switch (this) {
      case MerchantType.laundry:
        return 'Laundry';
      case MerchantType.catering:
        return 'Catering';
    }
  }

  static MerchantType? fromString(String? type) {
    if (type == null) return null;
    final normalized = type.trim().toLowerCase();
    try {
      return MerchantType.values.firstWhere(
        (t) => t.name.toLowerCase() == normalized,
      );
    } catch (e) {
      return null;
    }
  }
}

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.merchant:
        return 'Merchant';
      case UserRole.user:
        return 'User';
      case UserRole.owner:
        return 'Owner';
    }
  }

  static UserRole fromString(String role) {
    final normalized = role.trim().toLowerCase();
    return UserRole.values.firstWhere(
      (r) =>
          r.label.toLowerCase() == normalized ||
          r.name.toLowerCase() == normalized,
      orElse: () => UserRole.user,
    );
  }
}
