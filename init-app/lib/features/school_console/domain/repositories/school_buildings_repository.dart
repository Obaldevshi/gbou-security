import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_building.dart';

abstract interface class SchoolBuildingsRepository {
  Future<Either<Failure, List<ManagedSchoolBuilding>>> getBuildings();
  Future<Either<Failure, ManagedSchoolBuilding>> createBuilding(
    String name,
    String address,
  );
  Future<Either<Failure, ManagedSchoolBuilding>> updateBuilding(
    int id,
    String name,
    String address,
  );
  Future<Either<Failure, ManagedSchoolBuilding>> setBuildingStatus(
    int id,
    bool active,
  );
  Future<Either<Failure, Unit>> deleteBuilding(int id);
}
