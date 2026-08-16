import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_guard.dart';

abstract interface class SchoolGuardsRepository {
  Future<Either<Failure, List<ManagedGuard>>> getGuards();
  Future<Either<Failure, ManagedGuard>> createGuard(GuardDraft draft);
  Future<Either<Failure, ManagedGuard>> updateGuard(int id, GuardDraft draft);
  Future<Either<Failure, ManagedGuard>> setGuardStatus(int id, bool active);
  Future<Either<Failure, Unit>> deleteGuard(int id);
}
