import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';

abstract interface class SchoolStudentsRepository {
  Future<Either<Failure, List<ManagedStudent>>> getStudents({int? classId});
  Future<Either<Failure, ManagedStudent>> createStudent(StudentDraft draft);
  Future<Either<Failure, ManagedStudent>> updateStudent(
    int id,
    StudentDraft draft,
  );
  Future<Either<Failure, ManagedStudent>> setStudentStatus(int id, bool active);
  Future<Either<Failure, Unit>> deleteStudent(int id);
  Future<Either<Failure, StudentImportSummary>> importStudents(
    String text, {
    required int buildingId,
    required int classId,
    bool dryRun = false,
  });
}
