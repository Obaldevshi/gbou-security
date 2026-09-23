import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';
import 'package:mobile_template/features/auth/domain/entities/trusted_device.dart';
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

  static const superAdmin = CurrentUser(
    id: 3,
    login: 'superadmin',
    fullName: 'Главный администратор',
    role: UserRole.superAdmin,
    isActive: true,
  );

  static const schoolAdmin = CurrentUser(
    id: 4,
    login: 'school.admin',
    fullName: 'Администратор школы',
    role: UserRole.schoolAdmin,
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
      'superadmin' => superAdmin,
      'school.admin' => schoolAdmin,
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
    final user = token?.contains('super_admin') == true
        ? superAdmin
        : token?.contains('school_admin') == true
        ? schoolAdmin
        : token?.contains('guard') == true
        ? guard
        : teacher;
    _sessionService.markAuthenticated(user);
    return Right(user);
  }

  @override
  Future<Either<Failure, void>> enablePin(String pin) async {
    await _sessionService.configurePin(
      pin: pin,
      refreshToken: 'mock-refresh-token-that-is-long-enough-for-local-use',
      trustedDeviceId: 1,
    );
    return const Right(null);
  }

  @override
  Future<Either<Failure, AuthSession>> unlockWithPin(String pin) async {
    final verification = await _sessionService.verifyPin(pin);
    if (verification != PinVerificationResult.success) {
      return const Left(AuthFailure(message: 'Неверный PIN'));
    }
    final session = AuthSession(
      accessToken: 'mock-teacher-token',
      tokenType: 'bearer',
      expiresIn: 86400,
      user: teacher,
    );
    await _sessionService.establishTrustedSession(
      session: session,
      refreshToken: 'mock-rotated-refresh-token-that-is-long-enough',
      trustedDeviceId: 1,
    );
    return Right(session);
  }

  @override
  Future<Either<Failure, void>> changePin(String pin) async {
    await _sessionService.changePin(pin);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> disablePin() async {
    if (_sessionService.status == SessionStatus.locked) {
      await _sessionService.clearSession();
    } else {
      await _sessionService.disablePinLocal();
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<TrustedDevice>>> getTrustedDevices() async =>
      Right([
        TrustedDevice(
          id: 1,
          name: 'Демо-устройство',
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
        ),
      ]);

  @override
  Future<Either<Failure, void>> revokeTrustedDevice(int id) => disablePin();

  @override
  Future<void> logout() => _sessionService.clearSession();
}
