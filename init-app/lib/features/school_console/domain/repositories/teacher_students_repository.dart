import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';

abstract interface class TeacherStudentsRepository {
  Future<Either<Failure, List<ManagedStudent>>> getStudents();
  Future<Either<Failure, ManagedStudent>> createStudent(StudentDraft draft);
  Future<Either<Failure, ManagedStudent>> setStudentStatus(int id, bool active);
  Future<Either<Failure, Unit>> deleteStudent(int id);
}
