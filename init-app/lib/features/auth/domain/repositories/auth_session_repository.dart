import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';

abstract interface class AuthSessionRepository {
  Future<Either<Failure, AuthSession>> login({
    required String login,
    required String password,
  });

  Future<Either<Failure, CurrentUser?>> restoreSession();

  Future<void> logout();
}
