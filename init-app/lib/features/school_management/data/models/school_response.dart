import 'package:mobile_template/features/school_management/domain/entities/school.dart';

class SchoolResponse {
  const SchoolResponse({
    required this.id,
    required this.fullName,
    required this.shortName,
    required this.address,
    required this.isActive,
  });

  factory SchoolResponse.fromJson(Map<String, dynamic> json) => SchoolResponse(
    id: json['id'] as int,
    fullName: json['full_name'] as String,
    shortName: json['short_name'] as String,
    address: json['address'] as String,
    isActive: json['is_active'] as bool,
  );

  final int id;
  final String fullName;
  final String shortName;
  final String address;
  final bool isActive;

  School toDomain() => School(
    id: id,
    fullName: fullName,
    shortName: shortName,
    address: address,
    isActive: isActive,
  );
}

class SchoolAdminResponse {
  const SchoolAdminResponse({
    required this.id,
    required this.schoolId,
    required this.login,
    required this.fullName,
    required this.isActive,
    this.phone,
  });
  factory SchoolAdminResponse.fromJson(Map<String, dynamic> json) =>
      SchoolAdminResponse(
        id: json['id'] as int,
        schoolId: json['school_id'] as int,
        login: json['login'] as String,
        fullName: json['full_name'] as String,
        phone: json['phone'] as String?,
        isActive: json['is_active'] as bool,
      );
  final int id;
  final int schoolId;
  final String login;
  final String fullName;
  final String? phone;
  final bool isActive;
  SchoolAdmin toDomain() => SchoolAdmin(
    id: id,
    schoolId: schoolId,
    login: login,
    fullName: fullName,
    phone: phone,
    isActive: isActive,
  );
}

class SystemStatsResponse {
  const SystemStatsResponse({
    required this.schools,
    required this.activeSchools,
    required this.schoolAdmins,
    required this.users,
  });
  factory SystemStatsResponse.fromJson(Map<String, dynamic> json) =>
      SystemStatsResponse(
        schools: json['schools'] as int,
        activeSchools: json['active_schools'] as int,
        schoolAdmins: json['school_admins'] as int,
        users: json['users'] as int,
      );
  final int schools;
  final int activeSchools;
  final int schoolAdmins;
  final int users;
  SystemStats toDomain() => SystemStats(
    schools: schools,
    activeSchools: activeSchools,
    schoolAdmins: schoolAdmins,
    users: users,
  );
}
