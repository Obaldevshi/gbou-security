import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';

abstract interface class ExitRequestRepository {
  Future<Either<Failure, List<TeacherClass>>> getTeacherClasses();

  Future<Either<Failure, List<Student>>> getClassStudents(int classId);

  Future<Either<Failure, ExitRequest>> createExitRequest(
    CreateExitRequestCommand command,
  );

  Future<Either<Failure, List<ExitRequest>>> getPendingGuardRequests();

  Future<Either<Failure, ReleaseExitRequestResult>> releaseExitRequest(int id);

  Future<Either<Failure, TeacherExitRequestsSnapshot>> getTeacherExitRequests();
  Future<Either<Failure, TeacherExitRequestsSnapshot>> getSchoolExitRequests();
}
