import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_class.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_classes_repository.dart';

@injectable
class GetManagedClassesUsecase {
  const GetManagedClassesUsecase(this.repository);
  final SchoolClassesRepository repository;
  Future<Either<Failure, List<ManagedSchoolClass>>> call() =>
      repository.getClasses();
}

@injectable
class CreateManagedClassUsecase {
  const CreateManagedClassUsecase(this.repository);
  final SchoolClassesRepository repository;
  Future<Either<Failure, ManagedSchoolClass>> call(
    int buildingId,
    String name,
  ) => repository.createClass(buildingId, name);
}

@injectable
class UpdateManagedClassUsecase {
  const UpdateManagedClassUsecase(this.repository);
  final SchoolClassesRepository repository;
  Future<Either<Failure, ManagedSchoolClass>> call(
    int id,
    int buildingId,
    String name,
  ) => repository.updateClass(id, buildingId, name);
}

@injectable
class SetManagedClassStatusUsecase {
  const SetManagedClassStatusUsecase(this.repository);
  final SchoolClassesRepository repository;
  Future<Either<Failure, ManagedSchoolClass>> call(int id, bool active) =>
      repository.setClassStatus(id, active);
}

@injectable
class DeleteManagedClassUsecase {
  const DeleteManagedClassUsecase(this.repository);
  final SchoolClassesRepository repository;
  Future<Either<Failure, Unit>> call(int id) => repository.deleteClass(id);
}
