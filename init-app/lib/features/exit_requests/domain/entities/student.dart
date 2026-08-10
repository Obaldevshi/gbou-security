import 'package:equatable/equatable.dart';

class Student extends Equatable {
  const Student({
    required this.id,
    required this.classId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.middleName,
  });

  final int id;
  final int classId;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String fullName;

  @override
  List<Object?> get props => [
    id,
    classId,
    firstName,
    lastName,
    middleName,
    fullName,
  ];
}
