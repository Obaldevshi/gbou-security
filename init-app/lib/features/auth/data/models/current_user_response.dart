import 'package:json_annotation/json_annotation.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';

part 'current_user_response.g.dart';

@JsonSerializable(createToJson: false)
class CurrentUserResponse {
  const CurrentUserResponse({
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
  @JsonKey(name: 'full_name')
  final String fullName;
  final String? phone;
  final String role;
  @JsonKey(name: 'school_id')
  final int? schoolId;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'must_change_password', defaultValue: false)
  final bool mustChangePassword;

  factory CurrentUserResponse.fromJson(Map<String, dynamic> json) =>
      _$CurrentUserResponseFromJson(json);

  CurrentUser toDomain() => CurrentUser(
    id: id,
    login: login,
    fullName: fullName,
    phone: phone,
    role: UserRole.fromWireName(role),
    schoolId: schoolId,
    isActive: isActive,
    mustChangePassword: mustChangePassword,
  );
}
