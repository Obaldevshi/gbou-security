import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_guard.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_guards_repository.dart';

@injectable
class GetManagedGuardsUsecase {
  const GetManagedGuardsUsecase(this.repository);
  final SchoolGuardsRepository repository;
  Future<Either<Failure, List<ManagedGuard>>> call() => repository.getGuards();
}

@injectable
class CreateManagedGuardUsecase {
  const CreateManagedGuardUsecase(this.repository);
  final SchoolGuardsRepository repository;
  Future<Either<Failure, ManagedGuard>> call(GuardDraft draft) =>
      repository.createGuard(draft);
}

@injectable
class UpdateManagedGuardUsecase {
  const UpdateManagedGuardUsecase(this.repository);
  final SchoolGuardsRepository repository;
  Future<Either<Failure, ManagedGuard>> call(int id, GuardDraft draft) =>
      repository.updateGuard(id, draft);
}

@injectable
class SetManagedGuardStatusUsecase {
  const SetManagedGuardStatusUsecase(this.repository);
  final SchoolGuardsRepository repository;
  Future<Either<Failure, ManagedGuard>> call(int id, bool active) =>
      repository.setGuardStatus(id, active);
}

@injectable
class DeleteManagedGuardUsecase {
  const DeleteManagedGuardUsecase(this.repository);
  final SchoolGuardsRepository repository;
  Future<Either<Failure, Unit>> call(int id) => repository.deleteGuard(id);
}
