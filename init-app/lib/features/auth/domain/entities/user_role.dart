enum UserRole {
  superAdmin('super_admin'),
  schoolAdmin('school_admin'),
  teacher('teacher'),
  guard('guard');

  const UserRole(this.wireName);

  final String wireName;

  static UserRole fromWireName(String value) {
    return UserRole.values.firstWhere(
      (role) => role.wireName == value,
      orElse: () => throw FormatException('Unknown user role: $value'),
    );
  }

  bool get isSupportedByMvp =>
      this == superAdmin || this == teacher || this == guard;
}
