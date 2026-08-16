import 'package:equatable/equatable.dart';

class ManagedSchoolClass extends Equatable {
  const ManagedSchoolClass({
    required this.id,
    required this.name,
    required this.isActive,
  });
  final int id;
  final String name;
  final bool isActive;
  @override
  List<Object?> get props => [id, name, isActive];
}
