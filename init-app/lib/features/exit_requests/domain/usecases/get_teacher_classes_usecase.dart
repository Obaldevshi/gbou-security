import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';

@injectable
class GetTeacherClassesUsecase {
  const GetTeacherClassesUsecase(this._repository);

  final ExitRequestRepository _repository;

  Future<Either<Failure, List<TeacherClass>>> call() =>
      _repository.getTeacherClasses();
}
