import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/domain/repositories/teacher_students_repository.dart';

@injectable
class GetTeacherStudentsUsecase {
  const GetTeacherStudentsUsecase(this.repository);
  final TeacherStudentsRepository repository;
  Future<Either<Failure, List<ManagedStudent>>> call() =>
      repository.getStudents();
}

@injectable
class CreateTeacherStudentUsecase {
  const CreateTeacherStudentUsecase(this.repository);
  final TeacherStudentsRepository repository;
  Future<Either<Failure, ManagedStudent>> call(StudentDraft draft) =>
      repository.createStudent(draft);
}

@injectable
class SetTeacherStudentStatusUsecase {
  const SetTeacherStudentStatusUsecase(this.repository);
  final TeacherStudentsRepository repository;
  Future<Either<Failure, ManagedStudent>> call(int id, bool active) =>
      repository.setStudentStatus(id, active);
}

@injectable
class DeleteTeacherStudentUsecase {
  const DeleteTeacherStudentUsecase(this.repository);
  final TeacherStudentsRepository repository;
  Future<Either<Failure, Unit>> call(int id) => repository.deleteStudent(id);
}
