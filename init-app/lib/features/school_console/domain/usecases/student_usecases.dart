import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_students_repository.dart';

@injectable
class GetManagedStudentsUsecase {
  const GetManagedStudentsUsecase(this.repository);
  final SchoolStudentsRepository repository;
  Future<Either<Failure, List<ManagedStudent>>> call({int? classId}) =>
      repository.getStudents(classId: classId);
}

@injectable
class CreateManagedStudentUsecase {
  const CreateManagedStudentUsecase(this.repository);
  final SchoolStudentsRepository repository;
  Future<Either<Failure, ManagedStudent>> call(StudentDraft draft) =>
      repository.createStudent(draft);
}

@injectable
class UpdateManagedStudentUsecase {
  const UpdateManagedStudentUsecase(this.repository);
  final SchoolStudentsRepository repository;
  Future<Either<Failure, ManagedStudent>> call(int id, StudentDraft draft) =>
      repository.updateStudent(id, draft);
}

@injectable
class SetManagedStudentStatusUsecase {
  const SetManagedStudentStatusUsecase(this.repository);
  final SchoolStudentsRepository repository;
  Future<Either<Failure, ManagedStudent>> call(int id, bool active) =>
      repository.setStudentStatus(id, active);
}

@injectable
class DeleteManagedStudentUsecase {
  const DeleteManagedStudentUsecase(this.repository);
  final SchoolStudentsRepository repository;
  Future<Either<Failure, Unit>> call(int id) => repository.deleteStudent(id);
}

@injectable
class ImportManagedStudentsUsecase {
  const ImportManagedStudentsUsecase(this.repository);
  final SchoolStudentsRepository repository;
  Future<Either<Failure, StudentImportSummary>> call(
    String text, {
    required int buildingId,
    required int classId,
    bool dryRun = false,
  }) => repository.importStudents(
    text,
    buildingId: buildingId,
    classId: classId,
    dryRun: dryRun,
  );
}
