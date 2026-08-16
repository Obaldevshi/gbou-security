import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_teacher.dart';

abstract interface class SchoolTeachersRepository {
  Future<Either<Failure, List<ManagedTeacher>>> getTeachers();
  Future<Either<Failure, ManagedTeacher>> createTeacher(TeacherDraft draft);
  Future<Either<Failure, ManagedTeacher>> updateTeacher(
    int id,
    TeacherDraft draft,
  );
  Future<Either<Failure, ManagedTeacher>> setTeacherStatus(int id, bool active);
  Future<Either<Failure, Unit>> deleteTeacher(int id);
  Future<Either<Failure, TeacherImportSummary>> importTeachers(
    String text, {
    bool dryRun = false,
  });
}
