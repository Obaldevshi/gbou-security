import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/network/private_json_transport.dart';
import 'package:mobile_template/features/auth/domain/repositories/school_directory_repository.dart';

String schoolLoginDigest(String login) => sha256
    .convert(
      utf8.encode('gbou-login-directory-v1:${login.trim().toLowerCase()}'),
    )
    .toString();

bool isDirectorySchoolOrigin(String origin) {
  final uri = Uri.tryParse(origin);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.origin == origin &&
      !uri.hasPort &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      RegExp(
        r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.gbousecurity\.ru$',
      ).hasMatch(uri.host);
}

/// No global interceptors, credentials, cookie jar, redirects or body logging.
class SchoolDirectoryRepositoryImpl implements SchoolDirectoryRepository {
  SchoolDirectoryRepositoryImpl(String baseUrl, {Dio? client})
    : _baseUrl = baseUrl,
      _client =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 10),
              followRedirects: false,
            ),
          ) {
    final uri = Uri.parse(baseUrl);
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != '/api/v1' ||
        uri.host.isEmpty) {
      throw ArgumentError('A trusted central HTTPS API is required');
    }
    if (client == null) configurePrivateJsonTransport(_client);
  }
  final String _baseUrl;
  final Dio _client;

  @override
  Future<Either<Failure, SchoolDestination>> resolve(String login) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '$_baseUrl/login-directory/resolve',
        data: {'login_digest': schoolLoginDigest(login)},
        options: Options(followRedirects: false),
      );
      final data = response.data!;
      final origin = data['origin'] as String;
      final id = data['school_id'] as int;
      if (!isDirectorySchoolOrigin(origin) || id <= 0) {
        return const Left(
          ServerFailure(message: 'Получен недопустимый адрес школы.'),
        );
      }
      return Right(SchoolDestination(schoolId: id, origin: origin));
    } on DioException catch (error) {
      return Left(ErrorHandler.handleDioError(error));
    } catch (_) {
      return const Left(
        ServerFailure(message: 'Не удалось безопасно определить школу.'),
      );
    }
  }
}
