import 'package:equatable/equatable.dart';

class School extends Equatable {
  const School({
    required this.id,
    required this.fullName,
    required this.shortName,
    required this.address,
    required this.isActive,
  });

  final int id;
  final String fullName;
  final String shortName;
  final String address;
  final bool isActive;

  @override
  List<Object?> get props => [id, fullName, shortName, address, isActive];
}

class SchoolDraft extends Equatable {
  const SchoolDraft({
    required this.fullName,
    required this.shortName,
    required this.address,
  });

  final String fullName;
  final String shortName;
  final String address;

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'short_name': shortName,
    'address': address,
  };

  @override
  List<Object?> get props => [fullName, shortName, address];
}

class SchoolAdmin extends Equatable {
  const SchoolAdmin({
    required this.id,
    required this.schoolId,
    required this.login,
    required this.fullName,
    required this.isActive,
    this.phone,
  });
  final int id;
  final int schoolId;
  final String login;
  final String fullName;
  final String? phone;
  final bool isActive;
  @override
  List<Object?> get props => [id, schoolId, login, fullName, phone, isActive];
}

class SchoolAdminDraft extends Equatable {
  const SchoolAdminDraft({
    required this.schoolId,
    required this.login,
    required this.fullName,
    this.phone,
    this.password,
  });
  final int schoolId;
  final String login;
  final String fullName;
  final String? phone;
  final String? password;
  Map<String, dynamic> toJson() => {
    'school_id': schoolId,
    'login': login,
    'full_name': fullName,
    'phone': phone,
    if (password != null && password!.isNotEmpty) 'password': password,
  };
  @override
  List<Object?> get props => [schoolId, login, fullName, phone, password];
}

class SystemStats extends Equatable {
  const SystemStats({
    required this.schools,
    required this.activeSchools,
    required this.schoolAdmins,
    required this.users,
  });
  final int schools;
  final int activeSchools;
  final int schoolAdmins;
  final int users;
  @override
  List<Object?> get props => [schools, activeSchools, schoolAdmins, users];
}
