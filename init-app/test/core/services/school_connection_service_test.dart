import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/core/interceptors/school_connection_interceptor.dart';
import 'package:mobile_template/core/services/school_connection_service.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const cloud = 'https://cloud.example/api/v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SchoolConnectionService service;
  late SessionService session;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    session = await SessionService.create(
      storage,
      await SharedPreferences.getInstance(),
    );
    service = await SchoolConnectionService.create(
      storage: storage,
      session: session,
      defaultBaseUrl: cloud,
    );
  });

  test('normalizes HTTPS school addresses', () {
    expect(
      SchoolConnection.parse(' https://gbousecurity.local/ ').apiBaseUrl,
      'https://gbousecurity.local/api/v1',
    );
    expect(
      SchoolConnection.parse('https://school.local:8443/api/v1/').apiBaseUrl,
      'https://school.local:8443/api/v1',
    );
    expect(
      SchoolConnection.parse('https://192.168.1.85').apiBaseUrl,
      'https://192.168.1.85/api/v1',
    );
  });

  test('rejects insecure or ambiguous addresses', () {
    for (final url in [
      'http://school.local',
      'school.local',
      'https://user:pass@school.local',
      'https://school.local/?key=secret',
      'https://school.local/#login',
      'https://school.local/other',
    ]) {
      expect(
        () => SchoolConnection.parse(url),
        throwsFormatException,
        reason: url,
      );
    }
    expect(
      () =>
          SchoolConnection.parse('https://school.local', caPem: 'PRIVATE KEY'),
      throwsFormatException,
    );
  });

  test(
    'changing school removes access token, trusted session and PIN',
    () async {
      await session.saveToken(
        accessToken: 'old-token',
        tokenType: 'bearer',
        expiresIn: 300,
      );
      await session.configurePin(
        pin: '1234',
        refreshToken: 'old-refresh',
        trustedDeviceId: 1,
      );
      await service.select(SchoolConnection.parse('https://school.local'));
      expect(session.getAccessToken(), isNull);
      expect(session.hasTrustedSession, isFalse);
      expect(session.hasPinConfigured, isFalse);
      expect(service.isLocal, isTrue);
    },
  );

  test('startup discards tokens whose saved endpoint scope differs', () async {
    await session.saveToken(
      accessToken: 'cloud-token',
      tokenType: 'bearer',
      expiresIn: 300,
    );
    const storage = FlutterSecureStorage();
    await storage.write(
      key: 'school_connection_v1',
      value: jsonEncode({'url': 'https://school.local', 'ca_pem': null}),
    );
    await SchoolConnectionService.create(
      storage: storage,
      session: session,
      defaultBaseUrl: cloud,
    );
    expect(session.getAccessToken(), isNull);
  });

  test(
    'API requests use selected server with no duplicate query or redirect',
    () async {
      await service.select(SchoolConnection.parse('https://school.local:8443'));
      final dio = Dio();
      final interceptor = SchoolConnectionInterceptor(service, dio);
      dio.interceptors.add(interceptor);
      RequestOptions? captured;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: {}),
            );
          },
        ),
      );
      await dio.get(
        '$cloud/teacher/students',
        queryParameters: {'class_id': 4},
      );
      expect(captured!.uri.origin, 'https://school.local:8443');
      expect(captured!.uri.path, '/api/v1/teacher/students');
      expect(captured!.uri.queryParametersAll['class_id'], ['4']);
      expect(captured!.followRedirects, isFalse);
      await expectLater(
        dio.get('https://unrelated.example/api/v1/users/'),
        throwsA(isA<DioException>()),
      );
      interceptor.dispose();
      dio.close(force: true);
    },
  );
}
