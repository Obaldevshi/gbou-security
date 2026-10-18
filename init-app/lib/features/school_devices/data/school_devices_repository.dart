import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_devices/domain/school_devices.dart';

class SchoolDevicesApi {
  const SchoolDevicesApi(this.dio, this.baseUrl);
  final Dio dio;
  final String baseUrl;
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? payload,
  }) async {
    final response = payload == null
        ? await dio.get<Map<String, dynamic>>('$baseUrl/system/$path')
        : await dio.post<Map<String, dynamic>>(
            '$baseUrl/system/$path',
            data: payload,
          );
    return Map<String, dynamic>.from(response.data!['data'] as Map);
  }
}

class SchoolDevicesRepositoryImpl implements SchoolDevicesRepository {
  const SchoolDevicesRepositoryImpl(this.api);
  final SchoolDevicesApi api;
  Future<Either<Failure, T>> _attempt<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on DioException catch (error) {
      return Left(ErrorHandler.handleDioError(error));
    } catch (_) {
      return const Left(ServerFailure(message: 'Некорректный ответ сервера'));
    }
  }

  SchoolDeviceOverview _overview(Map<String, dynamic> data) =>
      SchoolDeviceOverview(
        hostname: data['hostname'] as String,
        generation: data['generation'] as int,
        devices: (data['devices'] as List)
            .map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              return SchoolDevice(
                id: item['device_id'] as String,
                label: item['label'] as String,
                role: item['role'] as String,
                state: item['state'] as String,
              );
            })
            .toList(growable: false),
      );
  @override
  Future<Either<Failure, SchoolDeviceOverview>> load(int school) => _attempt(
    () async => _overview(await api.request('schools/$school/devices')),
  );
  @override
  Future<Either<Failure, DeviceInvitation>> invite(int school, String role) =>
      _attempt(() async {
        final data = await api.request(
          'schools/$school/device-invitations',
          payload: {'role': role},
        );
        return DeviceInvitation(
          data['invitation'] as String,
          DateTime.parse(data['expires_at'] as String),
        );
      });
  @override
  Future<Either<Failure, SchoolDeviceOverview>> activate(
    int school,
    String device,
    int generation,
  ) => _attempt(
    () async => _overview(
      await api.request(
        'schools/$school/devices/$device/activate',
        payload: {
          'expected_generation': generation,
          'previous_primary_stopped': true,
          'database_ready_and_backup_verified': true,
        },
      ),
    ),
  );
  @override
  Future<Either<Failure, SchoolDeviceOverview>> revoke(
    int school,
    String device,
  ) => _attempt(
    () async => _overview(
      await api.request('schools/$school/devices/$device/revoke', payload: {}),
    ),
  );
}

class MockSchoolDevicesRepository implements SchoolDevicesRepository {
  final _device = const SchoolDevice(
    id: 'demo-primary',
    label: 'Raspberry школы',
    role: 'primary',
    state: 'active',
  );
  @override
  Future<Either<Failure, SchoolDeviceOverview>> load(int school) async => Right(
    SchoolDeviceOverview(
      hostname: '$school.gbousecurity.ru',
      generation: 1,
      devices: [_device],
    ),
  );
  @override
  Future<Either<Failure, DeviceInvitation>> invite(
    int school,
    String role,
  ) async => Right(
    DeviceInvitation(
      'DEMO-ONLY-NOT-A-REAL-INVITATION',
      DateTime.now().add(const Duration(minutes: 10)),
    ),
  );
  @override
  Future<Either<Failure, SchoolDeviceOverview>> activate(
    int school,
    String device,
    int generation,
  ) => load(school);
  @override
  Future<Either<Failure, SchoolDeviceOverview>> revoke(
    int school,
    String device,
  ) => load(school);
}
