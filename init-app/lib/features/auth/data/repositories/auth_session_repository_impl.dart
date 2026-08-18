import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/data/datasources/auth_api_data_source.dart';
import 'package:mobile_template/features/auth/data/models/auth_login_request.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';
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
  Future<void> logout() => _sessionService.clearSession();
}
