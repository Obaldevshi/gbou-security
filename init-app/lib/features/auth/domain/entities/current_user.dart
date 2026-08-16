import 'package:equatable/equatable.dart';
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';

class CurrentUser extends Equatable {
  const CurrentUser({
    required this.id,
    required this.login,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.mustChangePassword = false,
    this.phone,
    this.schoolId,
  });

  final int id;
  final String login;
  final String fullName;
  final String? phone;
  final UserRole role;
  final int? schoolId;
  final bool isActive;
  final bool mustChangePassword;

  @override
  List<Object?> get props => [
    id,
    login,
    fullName,
    phone,
    role,
    schoolId,
    isActive,
    mustChangePassword,
  ];
}
