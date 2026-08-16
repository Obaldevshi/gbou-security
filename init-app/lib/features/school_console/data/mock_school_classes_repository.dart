import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_class.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_classes_repository.dart';

class MockSchoolClassesRepository implements SchoolClassesRepository {
  final items = <ManagedSchoolClass>[
    const ManagedSchoolClass(id: 1, name: '5А', isActive: true),
    const ManagedSchoolClass(id: 2, name: '7Б', isActive: true),
  ];
  int nextId = 3;
  @override
  Future<Either<Failure, List<ManagedSchoolClass>>> getClasses() async =>
      Right(List.unmodifiable(items));
  @override
  Future<Either<Failure, ManagedSchoolClass>> createClass(String name) async {
    final item = ManagedSchoolClass(id: nextId++, name: name, isActive: true);
    items.add(item);
    return Right(item);
  }

  @override
  Future<Either<Failure, ManagedSchoolClass>> updateClass(
    int id,
    String name,
  ) async {
    final old = items.firstWhere((item) => item.id == id);
    final item = ManagedSchoolClass(id: id, name: name, isActive: old.isActive);
    items[items.indexOf(old)] = item;
    return Right(item);
  }

  @override
  Future<Either<Failure, ManagedSchoolClass>> setClassStatus(
    int id,
    bool active,
  ) async {
    final old = items.firstWhere((item) => item.id == id);
    final item = ManagedSchoolClass(id: id, name: old.name, isActive: active);
    items[items.indexOf(old)] = item;
    return Right(item);
  }

  @override
  Future<Either<Failure, Unit>> deleteClass(int id) async {
    items.removeWhere((item) => item.id == id);
    return const Right(unit);
  }
}
