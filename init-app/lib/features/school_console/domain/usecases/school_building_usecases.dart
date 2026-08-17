import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_building.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_buildings_repository.dart';

class GetManagedBuildingsUsecase {
  const GetManagedBuildingsUsecase(this.repository);
  final SchoolBuildingsRepository repository;
  Future<Either<Failure, List<ManagedSchoolBuilding>>> call() =>
      repository.getBuildings();
}

class SaveManagedBuildingUsecase {
  const SaveManagedBuildingUsecase(this.repository);
  final SchoolBuildingsRepository repository;
  Future<Either<Failure, ManagedSchoolBuilding>> call({
    int? id,
    required String name,
    required String address,
  }) => id == null
      ? repository.createBuilding(name, address)
      : repository.updateBuilding(id, name, address);
}

class SetManagedBuildingStatusUsecase {
  const SetManagedBuildingStatusUsecase(this.repository);
  final SchoolBuildingsRepository repository;
  Future<Either<Failure, ManagedSchoolBuilding>> call(int id, bool active) =>
      repository.setBuildingStatus(id, active);
}

class DeleteManagedBuildingUsecase {
  const DeleteManagedBuildingUsecase(this.repository);
  final SchoolBuildingsRepository repository;
  Future<Either<Failure, Unit>> call(int id) => repository.deleteBuilding(id);
}
