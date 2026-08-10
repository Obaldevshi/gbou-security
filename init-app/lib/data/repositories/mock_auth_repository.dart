import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/data/fixtures/mock_data_store.dart';
import 'package:mobile_template/data/models/request/change_password_request.dart';
import 'package:mobile_template/data/models/request/login_request.dart';
import 'package:mobile_template/data/models/request/register_request.dart';
import 'package:mobile_template/data/models/request/update_profile_request.dart';
import 'package:mobile_template/data/models/response/login_response.dart';
import 'package:mobile_template/domain/repositories/auth_repository.dart';
import 'package:mobile_template/features/profile/domain/dto/profile_dto.dart';
import 'package:fpdart/fpdart.dart';

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._sessionService);

  final SessionService _sessionService;
  final _store = MockDataStore.instance;

  static const _mockToken = 'mock-access-token';
  static const _networkDelay = Duration(milliseconds: 400);

  Future<void> _simulateNetwork() => Future<void>.delayed(_networkDelay);

  @override
  Future<Either<Failure, LoginResponse>> login(LoginRequest request) async {
    await _simulateNetwork();

    if (request.password.length < 6) {
      return const Left(
        AuthFailure(message: 'Invalid email or password', statusCode: 401),
      );
    }

    final response = LoginResponse(
      accessToken: _mockToken,
      tokenType: 'Bearer',
      expiresIn: 86400,
    );

    await _sessionService.saveToken(
      accessToken: response.accessToken,
      tokenType: response.tokenType,
      expiresIn: response.expiresIn,
    );

    return Right(response);
  }

  @override
  Future<Either<Failure, String>> register(RegisterRequest request) async {
    await _simulateNetwork();

    _store.profile = ProfileDto(
      id: _store.profile.id,
      email: request.email,
      firstName: request.firstName,
      lastName: request.lastName,
      createdAt: _store.profile.createdAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    _store.password = request.password;

    return const Right('Registration successful');
  }

  @override
  Future<Either<Failure, ProfileDto>> getProfile() async {
    await _simulateNetwork();
    return Right(_store.profile);
  }

  @override
  Future<Either<Failure, String>> updateProfile(
    UpdateProfileRequest request,
  ) async {
    await _simulateNetwork();

    _store.profile = ProfileDto(
      id: _store.profile.id,
      email: request.email,
      firstName: request.firstName,
      lastName: request.lastName,
      createdAt: _store.profile.createdAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    return const Right('Profile updated successfully');
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    await _simulateNetwork();
    await _sessionService.clearSession();
    _store.reset();
    return const Right(null);
  }

  @override
  Future<Either<Failure, String>> changePassword(
    ChangePasswordRequest request,
  ) async {
    await _simulateNetwork();

    if (request.currentPassword != _store.password) {
      return const Left(
        ValidationFailure(
          message: 'Current password is incorrect',
          statusCode: 400,
        ),
      );
    }

    _store.password = request.newPassword;
    return const Right('Password changed successfully');
  }
}
