import 'package:dio/dio.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/network/private_json_transport.dart';
import 'package:mobile_template/core/services/school_connection_service.dart';
import 'package:mobile_template/features/auth/data/models/auth_login_response.dart';
import 'package:mobile_template/features/auth/data/repositories/school_directory_repository_impl.dart';
import 'package:mobile_template/features/auth/domain/repositories/school_directory_repository.dart';

class SchoolDiscoveryFailure implements Exception {
  const SchoolDiscoveryFailure(this.failure);
  final Failure failure;
}

/// Password is used only after an allowlisted school destination is resolved.
class SchoolLoginCoordinator {
  SchoolLoginCoordinator(this.directory, this.connection, {Dio? schoolClient})
    : _schoolClient =
          schoolClient ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 15),
              followRedirects: false,
            ),
          ) {
    if (schoolClient == null) configurePrivateJsonTransport(_schoolClient);
  }
  final SchoolDirectoryRepository directory;
  final SchoolConnectionService connection;
  final Dio _schoolClient;
  bool get shouldDiscover =>
      connection.supportsDiscovery && connection.automaticDiscovery;

  Future<AuthLoginResponse> login(String login, String password) async {
    final revision = connection.revision;
    final digest = schoolLoginDigest(login);
    final result = await directory.resolve(login);
    final destination = result.fold((failure) {
      if (failure is BuildingSelectionRequired) {
        final selected = connection.buildingOriginFor(digest);
        final matches = failure.choices
            .where((c) => c.origin == selected)
            .toList();
        if (matches.length == 1) return matches.single;
        throw SchoolDiscoveryFailure(failure);
      }
      // Only connection/time-out errors: never bypass a negative directory result,
      // rate limit, invalid TLS certificate, or an invalid destination.
      if ((failure is NetworkFailure ||
              failure is TimeoutFailure ||
              failure is NoInternetFailure) &&
          connection.confirmedLoginDigest == digest &&
          connection.confirmedSchoolId != null) {
        return SchoolDestination(
          schoolId: connection.confirmedSchoolId!,
          origin: Uri.parse(connection.connection.apiBaseUrl).origin,
          buildingId: connection.confirmedBuildingId,
        );
      }
      throw SchoolDiscoveryFailure(failure);
    }, (value) => value);
    if (revision != connection.revision ||
        !shouldDiscover ||
        !isDirectorySchoolOrigin(destination.origin)) {
      throw const SchoolDiscoveryFailure(
        ServerFailure(message: 'Подключение изменено. Повторите вход.'),
      );
    }
    if (connection.confirmedLoginDigest == digest &&
        connection.confirmedSchoolId != null &&
        connection.confirmedSchoolId != destination.schoolId) {
      throw const SchoolDiscoveryFailure(
        ServerFailure(
          message:
              'Для этого логина изменилась школа. Проверьте адрес у администратора и укажите его вручную.',
        ),
      );
    }
    // This client has system trust roots only. No inherited CA/token/cookies.
    final response = await _schoolClient.post<Map<String, dynamic>>(
      '${destination.origin}/api/v1/auth/login',
      data: {'login': login.trim().toLowerCase(), 'password': password},
      options: Options(followRedirects: false),
    );
    final payload = Map<String, dynamic>.from(response.data!['data'] as Map);
    final data = AuthLoginResponse.fromJson(payload);
    if (revision != connection.revision ||
        !shouldDiscover ||
        data.user.schoolId != destination.schoolId ||
        (destination.buildingId != null &&
            payload['node_building_id'] != destination.buildingId) ||
        !data.user.isActive ||
        !const {'teacher', 'guard', 'school_admin'}.contains(data.user.role)) {
      throw const SchoolDiscoveryFailure(
        ServerFailure(
          message: 'Ответ сервера не соответствует выбранной школе.',
        ),
      );
    }
    await connection.rememberDiscovered(
      SchoolConnection.parse(destination.origin),
      digest,
      destination.schoolId,
      buildingId: destination.buildingId,
    );
    return data;
  }
}
