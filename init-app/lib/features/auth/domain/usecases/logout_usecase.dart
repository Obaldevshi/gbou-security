import 'package:injectable/injectable.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';

@injectable
class LogoutUsecase {
  const LogoutUsecase(this._repository);

  final AuthSessionRepository _repository;

  Future<void> call() => _repository.logout();
}
