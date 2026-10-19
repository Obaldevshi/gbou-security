import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';

class SchoolDestination {
  const SchoolDestination({
    required this.schoolId,
    required this.origin,
    this.buildingId,
    this.buildingName,
  });
  final int schoolId;
  final String origin;
  final int? buildingId;
  final String? buildingName;
}

class BuildingSelectionRequired extends Failure {
  const BuildingSelectionRequired(this.choices)
    : super(errorCode: 'building_selection_required');
  final List<SchoolDestination> choices;
  @override
  List<Object?> get props => [...super.props, choices];
}

abstract interface class SchoolDirectoryRepository {
  Future<Either<Failure, SchoolDestination>> resolve(String login);
}
