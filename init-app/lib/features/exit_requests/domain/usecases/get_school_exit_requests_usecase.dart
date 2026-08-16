import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';

@injectable
class GetSchoolExitRequestsUsecase {
  const GetSchoolExitRequestsUsecase(this.repository);
  final ExitRequestRepository repository;
  Future<Either<Failure, TeacherExitRequestsSnapshot>> call() =>
      repository.getSchoolExitRequests();
}
