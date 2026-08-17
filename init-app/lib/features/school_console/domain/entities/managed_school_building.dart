import 'package:equatable/equatable.dart';

class ManagedSchoolBuilding extends Equatable {
  const ManagedSchoolBuilding({
    required this.id,
    required this.name,
    required this.address,
    required this.isActive,
  });

  final int id;
  final String name;
  final String address;
  final bool isActive;

  @override
  List<Object?> get props => [id, name, address, isActive];
}
