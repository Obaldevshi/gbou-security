import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/core/services/school_connection_service.dart';
import 'package:mobile_template/features/auth/data/repositories/school_directory_repository_impl.dart';
import 'package:mobile_template/features/auth/data/repositories/school_login_coordinator.dart';
import 'package:mobile_template/features/auth/domain/repositories/school_directory_repository.dart';
import 'package:mobile_template/features/auth/data/datasources/auth_api_data_source.dart';
import 'package:mobile_template/features/auth/data/repositories/auth_session_repository_impl.dart';

const school = SchoolDestination(
  schoolId: 2,
  origin: 'https://school-2036.gbousecurity.ru',
);

class FakeDirectory implements SchoolDirectoryRepository {
  Either<Failure, SchoolDestination> result = const Right(school);
  @override
  Future<Either<Failure, SchoolDestination>> resolve(String login) async =>
      result;
}

class DelayedDirectory implements SchoolDirectoryRepository {
  final completer = Completer<Either<Failure, SchoolDestination>>();
  @override
  Future<Either<Failure, SchoolDestination>> resolve(String login) =>
      completer.future;
}

Map<String, dynamic> loginResponse({
  int schoolId = 2,
  String role = 'teacher',
}) => {
  'data': {
    'access_token': 'synthetic-token',
    'token_type': 'bearer',
    'expires_in': 1800,
    'user': {
      'id': 1,
      'login': 'teacher.demo',
      'full_name': 'Synthetic',
      'role': role,
      'school_id': schoolId,
      'is_active': true,
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionService session;
  late SchoolConnectionService connection;
  late FakeDirectory directory;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    session = await SessionService.create(
      const FlutterSecureStorage(),
      await SharedPreferences.getInstance(),
    );
    connection = await SchoolConnectionService.create(
      storage: const FlutterSecureStorage(),
      session: session,
      defaultBaseUrl: 'https://central.example/api/v1',
    );
    directory = FakeDirectory();
  });

  test('wire digest normalization and strict destination allowlist', () {
    expect(
      schoolLoginDigest(' Teacher.Demo '),
      schoolLoginDigest('teacher.demo'),
    );
    expect(schoolLoginDigest('teacher.demo'), hasLength(64));
    expect(isDirectorySchoolOrigin(school.origin), isTrue);
    for (final url in [
      'http://1.gbousecurity.ru',
      'https://evil.example',
      'https://1.gbousecurity.ru.evil.example',
      'https://gbousecurity.ru',
      'https://user@1.gbousecurity.ru',
      'https://1.gbousecurity.ru/?x=y',
      'https://1.gbousecurity.ru:8443',
      'https://1.gbousecurity.ru/api/v1',
    ]) {
      expect(isDirectorySchoolOrigin(url), isFalse, reason: url);
    }
  });

  test(
    'central request contains digest only, not source login/password/token',
    () async {
      final client = Dio();
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(
              options.uri.toString(),
              'https://central.example/api/v1/login-directory/resolve',
            );
            expect(options.data, {
              'login_digest': schoolLoginDigest('teacher.demo'),
            });
            expect(options.headers.containsKey('Authorization'), isFalse);
            expect(options.followRedirects, isFalse);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'school_id': school.schoolId, 'origin': school.origin},
              ),
            );
          },
        ),
      );
      final result = await SchoolDirectoryRepositoryImpl(
        'https://central.example/api/v1',
        client: client,
      ).resolve('Teacher.Demo');
      expect(result.isRight(), isTrue);
      client.close(force: true);
    },
  );

  test(
    'success sends password to one school and only then remembers address',
    () async {
      final client = Dio();
      var calls = 0;
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls++;
            expect(connection.isLocal, isFalse);
            expect(connection.confirmedLoginDigest, isNull);
            expect(
              options.uri.toString(),
              '${school.origin}/api/v1/auth/login',
            );
            expect(options.data, {
              'login': 'teacher.demo',
              'password': 'Synthetic8!',
            });
            expect(options.headers.containsKey('Authorization'), isFalse);
            expect(options.followRedirects, isFalse);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: loginResponse(),
              ),
            );
          },
        ),
      );
      final response = await SchoolLoginCoordinator(
        directory,
        connection,
        schoolClient: client,
      ).login(' Teacher.Demo ', 'Synthetic8!');
      expect(response.user.schoolId, 2);
      expect(calls, 1);
      expect(connection.connection.apiBaseUrl, '${school.origin}/api/v1');
      expect(
        connection.confirmedLoginDigest,
        schoolLoginDigest('teacher.demo'),
      );
      expect(connection.automaticDiscovery, isTrue);
      final saved = await const FlutterSecureStorage().read(
        key: 'school_connection_v1',
      );
      expect(saved, isNot(contains('Synthetic8!')));
      expect(saved, isNot(contains('teacher.demo')));
      final restored = await SchoolConnectionService.create(
        storage: const FlutterSecureStorage(),
        session: session,
        defaultBaseUrl: 'https://central.example/api/v1',
      );
      expect(restored.confirmedSchoolId, 2);
      expect(restored.automaticDiscovery, isTrue);
      client.close(force: true);
    },
  );

  test(
    'wrong password leaves endpoint, existing token and PIN unchanged',
    () async {
      await session.saveToken(
        accessToken: 'existing',
        tokenType: 'bearer',
        expiresIn: 300,
      );
      await session.configurePin(
        pin: '1234',
        refreshToken: 'synthetic-refresh',
        trustedDeviceId: 1,
      );
      final client = Dio();
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 401,
                  data: {'code': 'invalid_credentials'},
                ),
              ),
            );
          },
        ),
      );
      await expectLater(
        SchoolLoginCoordinator(
          directory,
          connection,
          schoolClient: client,
        ).login('teacher.demo', 'wrong'),
        throwsA(isA<DioException>()),
      );
      expect(connection.isLocal, isFalse);
      expect(connection.confirmedLoginDigest, isNull);
      expect(session.getAccessToken(), 'existing');
      expect(session.hasPinConfigured, isTrue);
      client.close(force: true);
    },
  );

  test(
    'unknown school never sends password or falls back to central',
    () async {
      directory.result = const Left(
        ServerFailure(statusCode: 404, message: 'School not resolved'),
      );
      final client = Dio();
      var calls = 0;
      client.interceptors.add(
        InterceptorsWrapper(onRequest: (_, _) => calls++),
      );
      await expectLater(
        SchoolLoginCoordinator(
          directory,
          connection,
          schoolClient: client,
        ).login('teacher.demo', 'Synthetic8!'),
        throwsA(isA<SchoolDiscoveryFailure>()),
      );
      expect(calls, 0);
      expect(connection.isLocal, isFalse);
      client.close(force: true);
    },
  );

  test(
    'cached same-login route works offline but never overrides 404',
    () async {
      await connection.rememberDiscovered(
        SchoolConnection.parse(school.origin),
        schoolLoginDigest('teacher.demo'),
        2,
      );
      directory.result = const Left(NoInternetFailure());
      final client = Dio();
      var calls = 0;
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls++;
            expect(options.uri.origin, school.origin);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: loginResponse(),
              ),
            );
          },
        ),
      );
      final coordinator = SchoolLoginCoordinator(
        directory,
        connection,
        schoolClient: client,
      );
      await coordinator.login('teacher.demo', 'Synthetic8!');
      expect(calls, 1);
      await expectLater(
        coordinator.login('other.demo', 'Synthetic8!'),
        throwsA(isA<SchoolDiscoveryFailure>()),
      );
      directory.result = const Left(ServerFailure(statusCode: 404));
      await expectLater(
        coordinator.login('teacher.demo', 'Synthetic8!'),
        throwsA(isA<SchoolDiscoveryFailure>()),
      );
      expect(calls, 1);
      client.close(force: true);
    },
  );

  test(
    'mismatched school or central role never becomes a remembered school',
    () async {
      for (final body in [
        loginResponse(schoolId: 99),
        loginResponse(role: 'super_admin'),
      ]) {
        final client = Dio();
        client.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: body),
            ),
          ),
        );
        await expectLater(
          SchoolLoginCoordinator(
            directory,
            connection,
            schoolClient: client,
          ).login('teacher.demo', 'Synthetic8!'),
          throwsA(isA<SchoolDiscoveryFailure>()),
        );
        expect(connection.isLocal, isFalse);
        client.close(force: true);
      }
    },
  );

  test(
    'manual central selection disables discovery; user can opt back in',
    () async {
      final client = Dio();
      final coordinator = SchoolLoginCoordinator(
        directory,
        connection,
        schoolClient: client,
      );
      expect(coordinator.shouldDiscover, isTrue);
      await connection.select(
        SchoolConnection.parse('https://central.example/api/v1'),
      );
      expect(coordinator.shouldDiscover, isFalse);
      await connection.enableAutomaticDiscovery();
      expect(coordinator.shouldDiscover, isTrue);
      final saved = jsonDecode(
        (await const FlutterSecureStorage().read(key: 'school_connection_v1'))!,
      );
      expect(saved['automatic'], isTrue);
      client.close(force: true);
    },
  );

  test(
    'configuration change during discovery cancels before sending password',
    () async {
      final delayed = DelayedDirectory();
      final client = Dio();
      var calls = 0;
      client.interceptors.add(
        InterceptorsWrapper(onRequest: (_, _) => calls++),
      );
      final attempt = SchoolLoginCoordinator(
        delayed,
        connection,
        schoolClient: client,
      ).login('teacher.demo', 'Synthetic8!');
      final check = expectLater(
        attempt,
        throwsA(isA<SchoolDiscoveryFailure>()),
      );
      await connection.select(SchoolConnection.parse('https://manual.example'));
      delayed.completer.complete(const Right(school));
      await check;
      expect(calls, 0);
      client.close(force: true);
    },
  );

  test('disallowed directory origin never receives a password', () async {
    directory.result = const Right(
      SchoolDestination(schoolId: 2, origin: 'https://evil.example'),
    );
    final client = Dio();
    var calls = 0;
    client.interceptors.add(InterceptorsWrapper(onRequest: (_, _) => calls++));
    await expectLater(
      SchoolLoginCoordinator(
        directory,
        connection,
        schoolClient: client,
      ).login('teacher.demo', 'Synthetic8!'),
      throwsA(isA<SchoolDiscoveryFailure>()),
    );
    expect(calls, 0);
    client.close(force: true);
  });

  test(
    'a previously confirmed login cannot silently move to another school',
    () async {
      await connection.rememberDiscovered(
        SchoolConnection.parse(school.origin),
        schoolLoginDigest('teacher.demo'),
        2,
      );
      directory.result = const Right(
        SchoolDestination(schoolId: 99, origin: 'https://99.gbousecurity.ru'),
      );
      final client = Dio();
      var calls = 0;
      client.interceptors.add(
        InterceptorsWrapper(onRequest: (_, _) => calls++),
      );
      await expectLater(
        SchoolLoginCoordinator(
          directory,
          connection,
          schoolClient: client,
        ).login('teacher.demo', 'Synthetic8!'),
        throwsA(isA<SchoolDiscoveryFailure>()),
      );
      expect(calls, 0);
      expect(connection.confirmedSchoolId, 2);
      client.close(force: true);
    },
  );

  test(
    'repository establishes school session without calling central login',
    () async {
      final centralClient = Dio();
      var centralLogins = 0;
      centralClient.interceptors.add(
        InterceptorsWrapper(
          onRequest: (_, handler) {
            centralLogins++;
            fail(
              'A school password must not be sent to central authentication',
            );
          },
        ),
      );
      final schoolClient = Dio();
      schoolClient.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: loginResponse(),
              ),
            );
          },
        ),
      );
      await session.configurePin(
        pin: '1234',
        refreshToken: 'previous-user-trust',
        trustedDeviceId: 99,
      );
      final repo = AuthSessionRepositoryImpl(
        AuthApiDataSource(
          centralClient,
          baseUrl: 'https://central.example/api/v1',
        ),
        session,
        schoolLogin: SchoolLoginCoordinator(
          directory,
          connection,
          schoolClient: schoolClient,
        ),
      );
      expect(
        (await repo.login(
          login: 'teacher.demo',
          password: 'Synthetic8!',
        )).isRight(),
        isTrue,
      );
      expect(session.currentUser!.schoolId, 2);
      expect(session.getAccessToken(), 'synthetic-token');
      expect(session.hasPinConfigured, isFalse);
      expect(centralLogins, 0);
      directory.result = const Left(ServerFailure(statusCode: 404));
      expect(
        (await repo.login(
          login: 'missing.demo',
          password: 'Synthetic8!',
        )).isLeft(),
        isTrue,
      );
      expect(centralLogins, 0);
      expect(session.getAccessToken(), 'synthetic-token');
      centralClient.close(force: true);
      schoolClient.close(force: true);
    },
  );
}
