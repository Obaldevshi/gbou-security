import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';

@injectable
class RestoreSessionUsecase {
  const RestoreSessionUsecase(this._repository);

  final AuthSessionRepository _repository;

  Future<Either<Failure, CurrentUser?>> call() => _repository.restoreSession();
}
