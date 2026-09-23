import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/data/datasources/auth_api_data_source.dart';
import 'package:mobile_template/features/auth/data/models/auth_login_request.dart';
import 'package:mobile_template/features/auth/data/models/auth_login_response.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';
import 'package:mobile_template/features/auth/domain/entities/trusted_device.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';

@LazySingleton(as: AuthSessionRepository)
class AuthSessionRepositoryImpl implements AuthSessionRepository {
  const AuthSessionRepositoryImpl(this._api, this._sessionService);

  final AuthApiDataSource _api;
  final SessionService _sessionService;

  @override
  Future<Either<Failure, AuthSession>> login({
    required String login,
    required String password,
  }) async {
    try {
      final response = await _api.login(
        AuthLoginRequest(login: login.trim().toLowerCase(), password: password),
      );
      final session = response.data!.toDomain();
      await _sessionService.establishSession(session);
      return Right(session);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, CurrentUser?>> restoreSession() async {
    if (!_sessionService.hasRestorableToken) {
      await _sessionService.clearSession();
      return const Right(null);
    }

    try {
      final response = await _api.getCurrentUser().timeout(
        const Duration(seconds: 10),
      );
      final user = response.data!.toDomain();
      _sessionService.markAuthenticated(user);
      return Right(user);
    } catch (error) {
      final failure = error is TimeoutException
          ? const TimeoutFailure()
          : ErrorHandler.handleError(error);
      if (_sessionService.hasRestorableToken) {
        _sessionService.markTemporarilyUnavailable();
      }
      return Left(failure);
    }
  }

  @override
  Future<Either<Failure, void>> enablePin(String pin) async {
    try {
      final response = await _api.createTrustedDevice({
        'device_name': 'Android-приложение',
      });
      final data = Map<String, dynamic>.from(response.data! as Map);
      final device = TrustedDevice.fromJson(data);
      await _sessionService.configurePin(
        pin: pin,
        refreshToken: data['refresh_token'] as String,
        trustedDeviceId: device.id,
      );
      return const Right(null);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, AuthSession>> unlockWithPin(String pin) async {
    final verification = await _sessionService.verifyPin(pin);
    if (verification == PinVerificationResult.invalid) {
      return Left(
        AuthFailure(
          message:
              'Неверный PIN. Осталось попыток: ${_sessionService.remainingPinAttempts}',
          statusCode: 401,
          errorCode: 'invalid_pin',
        ),
      );
    }
    if (verification == PinVerificationResult.lockedOut) {
      return const Left(
        AuthFailure(
          message: 'Слишком много попыток. Войдите по логину и паролю.',
          statusCode: 401,
          errorCode: 'pin_locked',
        ),
      );
    }
    if (verification != PinVerificationResult.success) {
      return const Left(
        AuthFailure(
          message: 'Быстрый вход недоступен. Войдите по логину и паролю.',
          statusCode: 401,
          errorCode: 'pin_unavailable',
        ),
      );
    }

    try {
      final response = await _api.refreshTrustedDevice({
        'refresh_token': _sessionService.getRefreshToken(),
      });
      final data = Map<String, dynamic>.from(response.data! as Map);
      final session = AuthLoginResponse.fromJson(data).toDomain();
      await _sessionService.establishTrustedSession(
        session: session,
        refreshToken: data['refresh_token'] as String,
        trustedDeviceId: (data['trusted_device_id'] as num).toInt(),
      );
      return Right(session);
    } catch (error) {
      final failure = ErrorHandler.handleError(error);
      if (failure.errorCode == 'trusted_session_invalid' ||
          failure.errorCode == 'trusted_session_expired' ||
          failure.errorCode == 'account_inactive' ||
          failure.errorCode == 'school_inactive' ||
          failure.errorCode == 'school_required' ||
          failure.errorCode == 'password_change_required') {
        await _sessionService.clearSession();
      }
      return Left(failure);
    }
  }

  @override
  Future<Either<Failure, void>> changePin(String pin) async {
    try {
      await _sessionService.changePin(pin);
      return const Right(null);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, void>> disablePin() async {
    try {
      final wasLocked = _sessionService.status == SessionStatus.locked;
      final id = _sessionService.getTrustedDeviceId();
      final refreshToken = _sessionService.getRefreshToken();
      if (id != null && _sessionService.hasRestorableToken) {
        await _api.revokeTrustedDevice(id);
      } else if (refreshToken != null) {
        await _api.revokeTrustedDeviceToken({'refresh_token': refreshToken});
      }
      if (wasLocked) {
        await _sessionService.clearSession();
      } else {
        await _sessionService.disablePinLocal();
      }
      return const Right(null);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, List<TrustedDevice>>> getTrustedDevices() async {
    try {
      final response = await _api.getTrustedDevices();
      final data = response.data! as List<dynamic>;
      return Right(
        data
            .map(
              (item) => TrustedDevice.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, void>> revokeTrustedDevice(int id) async {
    try {
      await _api.revokeTrustedDevice(id);
      if (id == _sessionService.getTrustedDeviceId()) {
        await _sessionService.disablePinLocal();
      }
      return const Right(null);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = _sessionService.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _api.revokeTrustedDeviceToken({'refresh_token': refreshToken});
      } catch (_) {
        // Local logout must always work, even without a network connection.
      }
    }
    await _sessionService.clearSession();
  }
}
