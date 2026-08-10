import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';

class MockAuthSessionRepository implements AuthSessionRepository {
  MockAuthSessionRepository(this._sessionService);

  final SessionService _sessionService;

  static const password = 'DemoPass123!';
  static const _delay = Duration(milliseconds: 400);

  static const teacher = CurrentUser(
    id: 1,
    login: 'teacher.demo',
    fullName: 'Демо Учитель',
    role: UserRole.teacher,
    schoolId: 1,
    isActive: true,
  );

  static const guard = CurrentUser(
    id: 2,
    login: 'guard.demo',
    fullName: 'Пост охраны',
    role: UserRole.guard,
    schoolId: 1,
    isActive: true,
  );

  @override
  Future<Either<Failure, AuthSession>> login({
    required String login,
    required String password,
  }) async {
    await Future<void>.delayed(_delay);
    final normalizedLogin = login.trim().toLowerCase();
    final user = switch (normalizedLogin) {
      'teacher.demo' => teacher,
      'guard.demo' => guard,
      _ => null,
    };

    if (user == null || password != MockAuthSessionRepository.password) {
      return const Left(
        AuthFailure(
          message: 'Неверный логин или пароль',
          statusCode: 401,
          errorCode: 'invalid_credentials',
        ),
      );
    }

    final session = AuthSession(
      accessToken: 'mock-${user.role.wireName}-token',
      tokenType: 'bearer',
      expiresIn: 86400,
      user: user,
    );
    await _sessionService.establishSession(session);
    return Right(session);
  }

  @override
  Future<Either<Failure, CurrentUser?>> restoreSession() async {
    await Future<void>.delayed(_delay);
    if (!_sessionService.hasRestorableToken) {
      await _sessionService.clearSession();
      return const Right(null);
    }

    final token = _sessionService.getAccessToken();
    final user = token?.contains('guard') == true ? guard : teacher;
    _sessionService.markAuthenticated(user);
    return Right(user);
  }

  @override
  Future<void> logout() => _sessionService.clearSession();
}
