import 'package:mobile_template/data/models/response/profile_response.dart';

class ProfileDto {
  const ProfileDto({
    required this.id,
    required this.login,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.schoolId,
  });

  final int id;
  final String login;
  final String fullName;
  final String? phone;
  final String role;
  final int? schoolId;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  factory ProfileDto.fromResponse(ProfileResponse response) => ProfileDto(
    id: response.id,
    login: response.login,
    fullName: response.fullName,
    phone: response.phone,
    role: response.role,
    schoolId: response.schoolId,
    isActive: response.isActive,
    createdAt: response.createdAt,
    updatedAt: response.updatedAt,
  );

  // Совместимость с неиспользуемой формой шаблона.
  String get email => login;
  String get firstName => fullName;
  String get lastName => '';
}
