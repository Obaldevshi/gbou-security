import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/account_deletion/domain/account_deletion.dart';

class MockAccountDeletionRepository implements AccountDeletionRepository {
  MockAccountDeletionRepository(this.session);
  final SessionService session;
  @override
  Future<Either<Failure, AccountDeletionInfo>> info() async => Right(
    AccountDeletionInfo(
      central: false,
      userId: session.currentUser?.id ?? 1,
      canDelete: true,
    ),
  );
  @override
  Future<Either<Failure, Unit>> delete(
    String password,
    String confirmation,
  ) async {
    if (password != 'DemoPass123!' || confirmation != 'УДАЛИТЬ') {
      return const Left(
        AuthFailure(
          message: 'Демопароль: DemoPass123!; подтверждение: УДАЛИТЬ',
        ),
      );
    }
    return const Right(unit);
  }
}
