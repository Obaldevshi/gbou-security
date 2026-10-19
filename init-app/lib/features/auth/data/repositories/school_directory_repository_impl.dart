import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/network/private_json_transport.dart';
import 'package:mobile_template/features/auth/domain/repositories/school_directory_repository.dart';
import 'package:mobile_template/features/auth/domain/repositories/routing_identifier.dart';
export 'package:mobile_template/features/auth/domain/repositories/routing_identifier.dart';

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
      Map<String, dynamic> data;
      try {
        data = (await _client.post<Map<String, dynamic>>(
          '$_baseUrl/login-directory/destinations',
          data: {'login_digest': schoolLoginDigest(login)},
          options: Options(followRedirects: false),
        )).data!;
      } on DioException catch (error) {
        // Compatibility with the previous backend ONLY when the route itself
        // is absent. Never override a negative directory/rate-limit response.
        if (error.response?.statusCode != 404 ||
            error.response?.data is! Map ||
            (error.response!.data as Map)['detail'] != 'Not Found') {
          rethrow;
        }
        final legacy = (await _client.post<Map<String, dynamic>>(
          '$_baseUrl/login-directory/resolve',
          data: {'login_digest': schoolLoginDigest(login)},
          options: Options(followRedirects: false),
        )).data!;
        data = {
          'choices': [legacy],
        };
      }
      final raw = data['choices'] as List;
      if (raw.isEmpty || raw.length > 64) throw const FormatException();
      final choices = raw
          .map((item) {
            final origin = item['origin'] as String;
            final id = item['school_id'] as int;
            final buildingId = item['building_id'] as int?;
            if (!isDirectorySchoolOrigin(origin) ||
                id <= 0 ||
                (buildingId != null && buildingId <= 0)) {
              throw const FormatException();
            }
            return SchoolDestination(
              schoolId: id,
              origin: origin,
              buildingId: buildingId,
              buildingName: item['building_name'] as String?,
            );
          })
          .toList(growable: false);
      if (choices.map((c) => c.schoolId).toSet().length != 1 ||
          choices.map((c) => c.origin).toSet().length != choices.length ||
          (choices.length > 1 && choices.any((c) => c.buildingId == null))) {
        throw const FormatException();
      }
      if (choices.length > 1) {
        return Left(BuildingSelectionRequired(List.unmodifiable(choices)));
      }
      return Right(choices.single);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.unknown ||
          error.type == DioExceptionType.badCertificate) {
        // Discovery failures precede password transmission. Never disguise a
        // trust/transport failure as a bad password or suggest the removed
        // manual school-address settings; there is no cloud-login fallback.
        return const Left(
          ServerFailure(
            errorCode: 'school_directory_unavailable',
            statusCode: 503,
            message:
                'Не удалось безопасно определить адрес школы. Проверьте интернет и повторите вход. Если ошибка сохраняется, обратитесь к администратору. Адрес школы вводить вручную не нужно.',
          ),
        );
      }
      return Left(ErrorHandler.handleDioError(error));
    } catch (_) {
      return const Left(
        ServerFailure(message: 'Не удалось безопасно определить школу.'),
      );
    }
  }
}
