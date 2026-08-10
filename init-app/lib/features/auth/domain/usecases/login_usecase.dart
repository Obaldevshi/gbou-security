import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';

@injectable
class LoginUsecase {
  const LoginUsecase(this._repository);

  final AuthSessionRepository _repository;

  Future<Either<Failure, AuthSession>> call({
    required String login,
    required String password,
  }) {
    return _repository.login(login: login, password: password);
  }
}
