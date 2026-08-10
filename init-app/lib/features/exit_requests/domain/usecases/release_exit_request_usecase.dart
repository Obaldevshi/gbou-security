import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';

@injectable
class ReleaseExitRequestUsecase {
  const ReleaseExitRequestUsecase(this._repository);

  final ExitRequestRepository _repository;

  Future<Either<Failure, ReleaseExitRequestResult>> call(int id) =>
      _repository.releaseExitRequest(id);
}
