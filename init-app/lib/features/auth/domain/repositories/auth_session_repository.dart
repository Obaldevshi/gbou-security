import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';
import 'package:mobile_template/features/auth/domain/entities/trusted_device.dart';

abstract interface class AuthSessionRepository {
  Future<Either<Failure, AuthSession>> login({
    required String login,
    required String password,
  });

  Future<Either<Failure, CurrentUser?>> restoreSession();

  Future<Either<Failure, void>> enablePin(String pin);

  Future<Either<Failure, AuthSession>> unlockWithPin(String pin);

  Future<Either<Failure, void>> changePin(String pin);

  Future<Either<Failure, void>> disablePin();

  Future<Either<Failure, List<TrustedDevice>>> getTrustedDevices();

  Future<Either<Failure, void>> revokeTrustedDevice(int id);

  Future<void> logout();
}
