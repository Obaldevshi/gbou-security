import 'package:equatable/equatable.dart';

class ManagedStudent extends Equatable {
  const ManagedStudent({
    required this.id,
    required this.classId,
    required this.className,
    required this.lastName,
    required this.firstName,
    required this.isActive,
    this.middleName,
  });
  final int id;
  final int classId;
  final String className;
  final String lastName;
  final String firstName;
  final String? middleName;
  final bool isActive;
  String get fullName => [
    lastName,
    firstName,
    middleName,
  ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
  @override
  List<Object?> get props => [
    id,
    classId,
    className,
    lastName,
    firstName,
    middleName,
    isActive,
  ];
}

class StudentDraft extends Equatable {
  const StudentDraft({
    required this.classId,
    required this.lastName,
    required this.firstName,
    this.middleName,
  });
  final int classId;
  final String lastName;
  final String firstName;
  final String? middleName;
  Map<String, dynamic> toJson() => {
    'class_id': classId,
    'last_name': lastName,
    'first_name': firstName,
    'middle_name': middleName,
  };
  @override
  List<Object?> get props => [classId, lastName, firstName, middleName];
}

class StudentImportError extends Equatable {
  const StudentImportError({required this.line, required this.message});
  final int line;
  final String message;
  @override
  List<Object?> get props => [line, message];
}

class StudentImportSummary extends Equatable {
  const StudentImportSummary({
    required this.createdCount,
    required this.errors,
  });
  final int createdCount;
  final List<StudentImportError> errors;
  @override
  List<Object?> get props => [createdCount, errors];
}
