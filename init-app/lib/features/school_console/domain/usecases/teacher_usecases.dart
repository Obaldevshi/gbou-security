import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_teacher.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_teachers_repository.dart';

@injectable
class GetManagedTeachersUsecase {
  const GetManagedTeachersUsecase(this.repository);
  final SchoolTeachersRepository repository;
  Future<Either<Failure, List<ManagedTeacher>>> call() =>
      repository.getTeachers();
}

@injectable
class CreateManagedTeacherUsecase {
  const CreateManagedTeacherUsecase(this.repository);
  final SchoolTeachersRepository repository;
  Future<Either<Failure, ManagedTeacher>> call(TeacherDraft draft) =>
      repository.createTeacher(draft);
}

@injectable
class UpdateManagedTeacherUsecase {
  const UpdateManagedTeacherUsecase(this.repository);
  final SchoolTeachersRepository repository;
  Future<Either<Failure, ManagedTeacher>> call(int id, TeacherDraft draft) =>
      repository.updateTeacher(id, draft);
}

@injectable
class SetManagedTeacherStatusUsecase {
  const SetManagedTeacherStatusUsecase(this.repository);
  final SchoolTeachersRepository repository;
  Future<Either<Failure, ManagedTeacher>> call(int id, bool active) =>
      repository.setTeacherStatus(id, active);
}

@injectable
class DeleteManagedTeacherUsecase {
  const DeleteManagedTeacherUsecase(this.repository);
  final SchoolTeachersRepository repository;
  Future<Either<Failure, Unit>> call(int id) => repository.deleteTeacher(id);
}
