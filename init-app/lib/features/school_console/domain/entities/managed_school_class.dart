import 'package:equatable/equatable.dart';

class ManagedSchoolClass extends Equatable {
  const ManagedSchoolClass({
    required this.id,
    required this.name,
    required this.buildingId,
    required this.buildingName,
    required this.isActive,
  });
  final int id;
  final String name;
  final int buildingId;
  final String buildingName;
  final bool isActive;
  @override
  List<Object?> get props => [id, name, buildingId, buildingName, isActive];
}
