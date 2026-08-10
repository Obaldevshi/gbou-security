import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';

@injectable
class GetClassStudentsUsecase {
  const GetClassStudentsUsecase(this._repository);

  final ExitRequestRepository _repository;

  Future<Either<Failure, List<Student>>> call(int classId) =>
      _repository.getClassStudents(classId);
}
