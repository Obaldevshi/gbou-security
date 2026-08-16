import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_guard.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_guards_repository.dart';

class MockSchoolGuardsRepository implements SchoolGuardsRepository {
  final items = <ManagedGuard>[
    const ManagedGuard(
      id: 1,
      login: 'guard.demo',
      fullName: 'Главный пост охраны',
      isActive: true,
    ),
  ];
  int nextId = 2;
  @override
  Future<Either<Failure, List<ManagedGuard>>> getGuards() async =>
      Right(List.unmodifiable(items));
  @override
  Future<Either<Failure, ManagedGuard>> createGuard(GuardDraft d) async {
    final item = ManagedGuard(
      id: nextId++,
      login: d.login,
      fullName: d.fullName,
      phone: d.phone,
      isActive: true,
    );
    items.add(item);
    return Right(item);
  }

  @override
  Future<Either<Failure, ManagedGuard>> updateGuard(
    int id,
    GuardDraft d,
  ) async {
    final old = items.firstWhere((e) => e.id == id);
    final item = ManagedGuard(
      id: id,
      login: d.login,
      fullName: d.fullName,
      phone: d.phone,
      isActive: old.isActive,
    );
    items[items.indexOf(old)] = item;
    return Right(item);
  }

  @override
  Future<Either<Failure, ManagedGuard>> setGuardStatus(
    int id,
    bool active,
  ) async {
    final old = items.firstWhere((e) => e.id == id);
    final item = ManagedGuard(
      id: id,
      login: old.login,
      fullName: old.fullName,
      phone: old.phone,
      isActive: active,
    );
    items[items.indexOf(old)] = item;
    return Right(item);
  }

  @override
  Future<Either<Failure, Unit>> deleteGuard(int id) async {
    items.removeWhere((e) => e.id == id);
    return const Right(unit);
  }
}
