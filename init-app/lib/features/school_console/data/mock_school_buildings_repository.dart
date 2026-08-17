import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_building.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_buildings_repository.dart';

class MockSchoolBuildingsRepository implements SchoolBuildingsRepository {
  final items = <ManagedSchoolBuilding>[
    const ManagedSchoolBuilding(
      id: 1,
      name: 'Основной корпус',
      address: 'Москва, Школьная улица, 1',
      isActive: true,
    ),
    const ManagedSchoolBuilding(
      id: 2,
      name: 'Начальная школа',
      address: 'Москва, Школьная улица, 3',
      isActive: true,
    ),
  ];
  int nextId = 3;

  @override
  Future<Either<Failure, List<ManagedSchoolBuilding>>> getBuildings() async =>
      Right(List.unmodifiable(items));

  @override
  Future<Either<Failure, ManagedSchoolBuilding>> createBuilding(
    String name,
    String address,
  ) async {
    final item = ManagedSchoolBuilding(
      id: nextId++,
      name: name,
      address: address,
      isActive: true,
    );
    items.add(item);
    return Right(item);
  }

  @override
  Future<Either<Failure, ManagedSchoolBuilding>> updateBuilding(
    int id,
    String name,
    String address,
  ) async {
    final old = items.firstWhere((item) => item.id == id);
    final item = ManagedSchoolBuilding(
      id: id,
      name: name,
      address: address,
      isActive: old.isActive,
    );
    items[items.indexOf(old)] = item;
    return Right(item);
  }

  @override
  Future<Either<Failure, ManagedSchoolBuilding>> setBuildingStatus(
    int id,
    bool active,
  ) async {
    final old = items.firstWhere((item) => item.id == id);
    final item = ManagedSchoolBuilding(
      id: id,
      name: old.name,
      address: old.address,
      isActive: active,
    );
    items[items.indexOf(old)] = item;
    return Right(item);
  }

  @override
  Future<Either<Failure, Unit>> deleteBuilding(int id) async {
    items.removeWhere((item) => item.id == id);
    return const Right(unit);
  }
}
