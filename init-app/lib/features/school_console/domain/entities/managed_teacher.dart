import 'package:equatable/equatable.dart';

class TeacherClass extends Equatable {
  const TeacherClass({required this.id, required this.name});
  final int id;
  final String name;
  @override
  List<Object?> get props => [id, name];
}

class ManagedTeacher extends Equatable {
  const ManagedTeacher({
    required this.id,
    required this.login,
    required this.fullName,
    required this.buildingId,
    required this.buildingName,
    required this.isActive,
    required this.classes,
    this.phone,
  });
  final int id;
  final String login;
  final String fullName;
  final int buildingId;
  final String buildingName;
  final String? phone;
  final bool isActive;
  final List<TeacherClass> classes;
  @override
  List<Object?> get props => [
    id,
    login,
    fullName,
    buildingId,
    buildingName,
    phone,
    isActive,
    classes,
  ];
}

class TeacherDraft extends Equatable {
  const TeacherDraft({
    required this.login,
    required this.fullName,
    required this.buildingId,
    required this.classIds,
    this.phone,
    this.password,
  });
  final String login;
  final String fullName;
  final int buildingId;
  final String? phone;
  final String? password;
  final List<int> classIds;
  Map<String, dynamic> toJson({required bool includePassword}) => {
    'login': login,
    'full_name': fullName,
    'building_id': buildingId,
    'phone': phone,
    'class_ids': classIds,
    if (includePassword || password != null) 'password': password,
  };
  @override
  List<Object?> get props => [
    login,
    fullName,
    buildingId,
    phone,
    password,
    classIds,
  ];
}

class TeacherImportError extends Equatable {
  const TeacherImportError({required this.line, required this.message});
  final int line;
  final String message;
  @override
  List<Object?> get props => [line, message];
}

class TeacherImportSummary extends Equatable {
  const TeacherImportSummary({
    required this.createdCount,
    required this.errors,
  });
  final int createdCount;
  final List<TeacherImportError> errors;
  @override
  List<Object?> get props => [createdCount, errors];
}
