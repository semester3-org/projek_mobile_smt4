enum UserRole {
  admin,
  merchant,
  user,
  owner,
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
