import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/account_deletion/domain/account_deletion.dart';

class AccountDeletionRepositoryImpl implements AccountDeletionRepository {
  AccountDeletionRepositoryImpl(
    this.dio,
    this.baseUrl,
    this.session,
    this.centralBaseUrl, {
    this.centralClientFactory,
  });
  final Dio dio;
  final String baseUrl, centralBaseUrl;
  final SessionService session;
  final Dio Function()? centralClientFactory;
  AccountDeletionInfo _parse(dynamic body) {
    final data = body['data'] as Map<String, dynamic>;
    return AccountDeletionInfo(
      central: data['authority'] == 'central',
      userId: data['user_id'] as int,
      canDelete: data['can_delete'] == true,
    );
  }

  @override
  Future<Either<Failure, AccountDeletionInfo>> info() async {
    try {
      return Right(
        _parse((await dio.get('$baseUrl/users/deletion-info')).data),
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(
    String password,
    String confirmation,
  ) async {
    Dio? central;
    try {
      final before = session.currentUser;
      if (before == null) {
        return const Left(AuthFailure(message: 'Необходим вход в систему'));
      }
      final details = _parse(
        (await dio.get('$baseUrl/users/deletion-info')).data,
      );
      final payload = {
        'current_password': password,
        'confirmation': confirmation,
      };
      if (details.central) {
        final uri = Uri.parse(centralBaseUrl);
        if (uri.scheme != 'https' ||
            uri.userInfo.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment ||
            uri.path != '/api/v1') {
          throw const FormatException(
            'Недопустимый адрес центрального сервиса',
          );
        }
        central =
            centralClientFactory?.call() ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 30),
                followRedirects: false,
              ),
            );
        // Separate client: no school TLS override, stored refresh, logs or auth interceptors.
        final login =
            (await central.post(
                  '$centralBaseUrl/auth/account-deletion-session',
                  data: {'login': before.login, 'password': password},
                  options: Options(followRedirects: false),
                )).data['data']
                as Map<String, dynamic>;
        final user = login['user'] as Map<String, dynamic>;
        if (user['id'] != details.userId ||
            user['role'] != before.role.wireName ||
            user['school_id'] != before.schoolId) {
          return const Left(
            AuthFailure(
              message: 'Центральный аккаунт не соответствует текущему профилю',
            ),
          );
        }
        final token = login['access_token'] as String;
        await central.post(
          '$centralBaseUrl/users/delete-account-with-session',
          data: payload,
          options: Options(
            followRedirects: false,
            headers: {'Authorization': 'Bearer $token'},
          ),
        );
      } else {
        await dio.post('$baseUrl/users/delete-account', data: payload);
      }
      return const Right(unit);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    } finally {
      central?.close(force: true);
    }
  }
}
