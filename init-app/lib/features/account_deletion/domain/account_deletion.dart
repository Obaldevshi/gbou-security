import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';

class AccountDeletionInfo {
  const AccountDeletionInfo({
    required this.central,
    required this.userId,
    required this.canDelete,
  });
  final bool central, canDelete;
  final int userId;
}

abstract interface class AccountDeletionRepository {
  Future<Either<Failure, AccountDeletionInfo>> info();
  Future<Either<Failure, Unit>> delete(String password, String confirmation);
}

class DeleteOwnAccount {
  const DeleteOwnAccount(this.repository);
  final AccountDeletionRepository repository;
  Future<Either<Failure, Unit>> call(String password, String confirmation) {
    if (password.isEmpty || confirmation != 'УДАЛИТЬ') {
      return Future.value(
        const Left(
          ValidationFailure(message: 'Введите пароль и подтверждение УДАЛИТЬ'),
        ),
      );
    }
    return repository.delete(password, confirmation);
  }
}
