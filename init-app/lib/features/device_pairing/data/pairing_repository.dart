import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/device_pairing/domain/pairing.dart';

/// Dedicated client: no global auth, logging, school redirect or token storage.
class PairingApi {
  PairingApi(this.baseUrl)
    : dio = Dio(
        BaseOptions(
          followRedirects: false,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ) {
    final uri = Uri.parse(baseUrl);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != '/api/v1') {
      throw ArgumentError('Pairing requires the trusted central HTTPS API');
    }
  }
  final String baseUrl;
  final Dio dio;
  Future<Map<String, dynamic>> call(
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final options = Options(
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    final response = body == null
        ? await dio.get<Map<String, dynamic>>(
            '$baseUrl/device-admin$path',
            options: options,
          )
        : await dio.post<Map<String, dynamic>>(
            '$baseUrl/device-admin$path',
            data: body,
            options: options,
          );
    return response.data!;
  }
}

class PairingRepositoryImpl implements PairingRepository {
  const PairingRepositoryImpl(this.api);
  final PairingApi api;
  PairingSession _session(Map<String, dynamic> data) => PairingSession(
    data['access_token'] as String,
    DateTime.now().add(Duration(seconds: data['expires_in'] as int)),
    passwordChangeRequired: data['password_change_required'] == true,
  );
  @override
  Future<Either<Failure, PairingSession>> changePassword(
    String token,
    String password,
  ) => _attempt(
    () async => _session(
      await api.call(
        '/password',
        token: token,
        body: {'new_password': password},
      ),
    ),
  );
  Future<Either<Failure, T>> _attempt<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on DioException catch (error) {
      return Left(ErrorHandler.handleDioError(error));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  PairingSchool _school(Map<String, dynamic> data) {
    final overview = Map<String, dynamic>.from(data['overview'] as Map);
    final scoped = data['networking_scope'] == 'building';
    final campuses = scoped ? data['building_overviews'] as List : const [];
    final devices = scoped
        ? campuses.expand((c) => c['devices'] as List).toList()
        : overview['devices'] as List;
    return PairingSchool(
      overview['hostname'] as String,
      overview['generation'] as int,
      (data['buildings'] as List)
          .map((b) => PairingChoice(b['id'] as int, b['name'] as String))
          .toList(),
      devices
          .map(
            (d) => PairedDevice(
              d['device_id'] as String,
              d['label'] as String,
              d['role'] as String,
              d['state'] as String,
              d['building_id'] as int?,
            ),
          )
          .toList(),
      campuses: campuses
          .map(
            (c) => PairingCampus(
              c['building_id'] as int,
              c['hostname'] as String,
              c['generation'] as int,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<Either<Failure, PairingSession>> login(
    String login,
    String password,
  ) => _attempt(() async {
    final data = await api.call(
      '/login',
      body: {'login': login, 'password': password},
    );
    return _session(data);
  });
  @override
  Future<Either<Failure, List<PairingChoice>>> schools(String token) =>
      _attempt(
        () async =>
            ((await api.call('/context', token: token))['schools'] as List)
                .map((s) => PairingChoice(s['id'] as int, s['name'] as String))
                .toList(),
      );
  @override
  Future<Either<Failure, PairingSchool>> school(String token, int school) =>
      _attempt(
        () async => _school(await api.call('/schools/$school', token: token)),
      );
  @override
  Future<Either<Failure, PairingPreview>> inspect(
    String token,
    String request,
  ) => _attempt(() async {
    final data = await api.call(
      '/pairings/$request/inspect',
      token: token,
      body: {},
    );
    return PairingPreview(
      data['label'] as String,
      data['fingerprint'] as String,
      DateTime.parse(data['expires_at'] as String),
    );
  });
  @override
  Future<Either<Failure, PairingSchool>> approve(
    String token,
    String request,
    int school,
    int building,
    String role,
    String code,
  ) => _attempt(
    () async => _school(
      await api.call(
        '/pairings/$request/approve',
        token: token,
        body: {
          'scope_version': 2,
          'school_id': school,
          'building_id': building,
          'role': role,
          'code': code,
        },
      ),
    ),
  );
  Future<PairingSchool> _deviceAction(
    String token,
    int school,
    String device,
    String action,
    Map<String, dynamic> body,
  ) async {
    await api.call(
      '/schools/$school/devices/$device/$action',
      token: token,
      body: body,
    );
    return _school(await api.call('/schools/$school', token: token));
  }

  @override
  Future<Either<Failure, PairingSchool>> activate(
    String token,
    int school,
    String device,
    int generation,
  ) => _attempt(
    () => _deviceAction(token, school, device, 'activate', {
      'expected_generation': generation,
      'previous_primary_stopped': true,
      'database_ready_and_backup_verified': true,
    }),
  );
  @override
  Future<Either<Failure, PairingSchool>> revoke(
    String token,
    int school,
    String device,
  ) => _attempt(() => _deviceAction(token, school, device, 'revoke', {}));
}

class MockPairingRepository implements PairingRepository {
  @override
  Future<Either<Failure, PairingSession>> changePassword(
    String token,
    String password,
  ) async => Right(
    PairingSession('MOCK-ONLY', DateTime.now().add(const Duration(minutes: 5))),
  );
  final List<PairedDevice> _devices = [];
  final Map<int, int> _generations = {1: 0, 2: 0};
  PairingSchool get _school => PairingSchool(
    '236.gbousecurity.ru',
    _generations[1]!,
    const [PairingChoice(1, 'Корпус 1'), PairingChoice(2, 'Корпус 2')],
    List.of(_devices),
    campuses: [
      for (final entry in _generations.entries)
        PairingCampus(
          entry.key,
          '236-${entry.key}.gbousecurity.ru',
          entry.value,
        ),
    ],
  );
  @override
  Future<Either<Failure, PairingSession>> login(
    String login,
    String password,
  ) async => Right(
    PairingSession('MOCK-ONLY', DateTime.now().add(const Duration(minutes: 5))),
  );
  @override
  Future<Either<Failure, List<PairingChoice>>> schools(String token) async =>
      const Right([PairingChoice(1, 'Школа 236')]);
  @override
  Future<Either<Failure, PairingSchool>> school(
    String token,
    int school,
  ) async => Right(_school);
  @override
  Future<Either<Failure, PairingPreview>> inspect(
    String token,
    String request,
  ) async => Right(
    PairingPreview(
      'Новая Raspberry',
      'demo-public',
      DateTime.now().add(const Duration(minutes: 10)),
    ),
  );
  @override
  Future<Either<Failure, PairingSchool>> approve(
    String token,
    String request,
    int school,
    int building,
    String role,
    String code,
  ) async {
    if (code != '123456') {
      return const Left(ValidationFailure(message: 'Демо-код: 123456'));
    }
    if (school != 1 ||
        !_generations.containsKey(building) ||
        !{'primary', 'terminal'}.contains(role) ||
        _devices.any((d) => d.id == request) ||
        (role == 'terminal' && !_school.hasPrimaryFor(building))) {
      return const Left(
        ValidationFailure(
          message: 'Недоступный корпус, роль или повторное подключение',
        ),
      );
    }
    _devices.add(
      PairedDevice(
        request,
        'Новая Raspberry',
        role,
        role == 'primary' ? 'pending' : 'active',
        building,
      ),
    );
    return Right(_school);
  }

  @override
  Future<Either<Failure, PairingSchool>> activate(
    String token,
    int school,
    String device,
    int generation,
  ) async {
    final i = _devices.indexWhere((d) => d.id == device);
    if (school != 1 ||
        (i >= 0 && generation != _generations[_devices[i].buildingId]) ||
        i < 0 ||
        _devices[i].role != 'primary' ||
        _devices[i].state != 'pending') {
      return const Left(
        ValidationFailure(message: 'Состояние устройства изменилось'),
      );
    }
    for (var index = 0; index < _devices.length; index++) {
      final d = _devices[index];
      if (d.role == 'primary' &&
          d.state == 'active' &&
          d.buildingId == _devices[i].buildingId) {
        _devices[index] = PairedDevice(
          d.id,
          d.label,
          d.role,
          'revoked',
          d.buildingId,
        );
      }
    }
    if (i >= 0) {
      final d = _devices[i];
      _devices[i] = PairedDevice(d.id, d.label, d.role, 'active', d.buildingId);
    }
    final building = _devices[i].buildingId!;
    _generations[building] = _generations[building]! + 1;
    return Right(_school);
  }

  @override
  Future<Either<Failure, PairingSchool>> revoke(
    String token,
    int school,
    String device,
  ) async {
    final i = _devices.indexWhere(
      (d) => d.id == device && d.role == 'terminal',
    );
    if (school != 1 || i < 0) {
      return const Left(ValidationFailure(message: 'Терминал не найден'));
    }
    final d = _devices[i];
    _devices[i] = PairedDevice(d.id, d.label, d.role, 'revoked', d.buildingId);
    return Right(_school);
  }
}
