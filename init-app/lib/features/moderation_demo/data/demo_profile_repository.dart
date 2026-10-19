import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/domain/repositories/auth_repository.dart';
import 'package:mobile_template/data/models/request/change_password_request.dart';
import 'package:mobile_template/data/models/request/login_request.dart';
import 'package:mobile_template/data/models/request/register_request.dart';
import 'package:mobile_template/data/models/request/update_profile_request.dart';
import 'package:mobile_template/data/models/response/login_response.dart';
import 'package:mobile_template/features/profile/domain/dto/profile_dto.dart';

/// No shared MockDataStore singleton, preferences or real authentication.
class DemoProfileRepository implements AuthRepository {
  DemoProfileRepository(this.session);
  final SessionService session;
  @override
  Future<Either<Failure, ProfileDto>> getProfile() async {
    final user = session.currentUser;
    if (user == null) {
      return const Left(AuthFailure(message: 'Выберите демонстрационную роль'));
    }
    return Right(
      ProfileDto(
        id: user.id,
        login: user.login,
        fullName: user.fullName,
        role: user.role.wireName,
        schoolId: user.schoolId,
        isActive: true,
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-01T00:00:00Z',
      ),
    );
  }

  @override
  Future<Either<Failure, String>> changePassword(
    ChangePasswordRequest request,
  ) async => const Right('В демонстрации пароль не изменяется: DemoPass123!');
  @override
  Future<Either<Failure, String>> updateProfile(
    UpdateProfileRequest request,
  ) async => const Left(
    ValidationFailure(message: 'Демонстрационные реквизиты не изменяются'),
  );
  @override
  Future<Either<Failure, void>> deleteAccount() async {
    await session.clearSession();
    return const Right(null);
  }

  @override
  Future<Either<Failure, LoginResponse>> login(LoginRequest request) async =>
      const Left(AuthFailure(message: 'Выберите роль на панели демонстрации'));
  @override
  Future<Either<Failure, String>> register(RegisterRequest request) async =>
      const Left(AuthFailure(message: 'Регистрация в демонстрации недоступна'));
}
