// Real Android rendering + production login routing, synthetic transports only.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/core/bootstrap.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/mock_di.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/core/services/school_connection_service.dart';
import 'package:mobile_template/core/services/theme_service.dart';
import 'package:mobile_template/features/auth/data/datasources/auth_api_data_source.dart';
import 'package:mobile_template/features/auth/data/repositories/auth_session_repository_impl.dart';
import 'package:mobile_template/features/auth/data/repositories/school_directory_repository_impl.dart';
import 'package:mobile_template/features/auth/data/repositories/school_login_coordinator.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:mobile_template/features/moderation_demo/data/demo_dependencies.dart';
import 'package:mobile_template/presentation/widgets/common/error_dialog.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('school/central entry, offline QR state, password routing and roles', (
    tester,
  ) async {
    const schoolOrigin = 'https://school-2036.gbousecurity.ru';
    const secondOrigin = 'https://2036-2.gbousecurity.ru';
    const password = 'Synthetic8!';
    var scenario = 'offline';
    var directoryCalls = 0, schoolCalls = 0, centralCalls = 0;
    final contractViolations = <String>[];
    // Interceptors can run while tester.tap's guarded async scope is active.
    // Do not call widget-test expect() there; fail closed, assert after pumping.
    void requireContract(bool condition, String name) {
      if (!condition) {
        contractViolations.add(name);
        throw StateError('Synthetic request contract: $name');
      }
    }

    String? selectedOrigin;
    Dio privateClient() => Dio()..httpClientAdapter = NoDemoNetwork();
    final directory = privateClient(),
        school = privateClient(),
        central = privateClient();
    directory.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          directoryCalls++;
          requireContract(
            request.uri.path == '/api/v1/login-directory/destinations',
            'directory-path',
          );
          requireContract(
            request.data is Map &&
                (request.data as Map).length == 1 &&
                (request.data as Map).containsKey('login_digest'),
            'digest-only',
          );
          requireContract(
            !request.headers.containsKey('Authorization'),
            'no-directory-auth',
          );
          requireContract(!request.followRedirects, 'directory-no-redirect');
          if (scenario == 'unknown') {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: request,
                  statusCode: 404,
                  data: {
                    'code': 'school_not_resolved',
                    'message':
                        'Школа по этому логину не найдена. Обратитесь к администратору.',
                  },
                ),
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'choices': [
                  {
                    'school_id': 2,
                    'building_id': 1,
                    'origin': schoolOrigin,
                    'building_name': 'Корпус 1',
                  },
                  if (scenario == 'multi')
                    {
                      'school_id': 2,
                      'building_id': 2,
                      'origin': secondOrigin,
                      'building_name':
                          'Корпус 2 — длинное название для проверки переноса',
                    },
                ],
              },
            ),
          );
        },
      ),
    );
    Map<String, dynamic> response(
      String login, {
      bool control = false,
      int building = 1,
    }) => {
      'message': 'Synthetic login completed',
      'data': {
        'access_token': 'synthetic-emulator-token',
        'token_type': 'bearer',
        'expires_in': 1800,
        if (!control) 'node_building_id': building,
        'user': {
          'id': 101,
          'login': login,
          'full_name': 'Вымышленный пользователь',
          'role': control
              ? 'super_admin'
              : login == 'guard.demo'
              ? 'guard'
              : login == 'school.admin'
              ? 'school_admin'
              : 'teacher',
          'school_id': control ? null : 2,
          'is_active': true,
        },
      },
    };
    school.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          schoolCalls++;
          requireContract(
            [schoolOrigin, secondOrigin].contains(request.uri.origin),
            'school-origin',
          );
          requireContract(
            request.uri.path == '/api/v1/auth/login',
            'school-path',
          );
          requireContract(!request.followRedirects, 'school-no-redirect');
          requireContract(
            !request.headers.containsKey('Authorization'),
            'no-old-auth',
          );
          requireContract(
            request.data['password'] == password,
            'school-password',
          );
          selectedOrigin = request.uri.origin;
          if (scenario == 'offline') {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.unknown,
                message: 'Synthetic connection closed during QR replacement',
              ),
            );
          } else if (scenario == 'wrong') {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: request,
                  statusCode: 401,
                  data: {
                    'code': 'invalid_credentials',
                    'message': 'Неверный логин или пароль',
                  },
                ),
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: response(
                  request.data['login'],
                  building: request.uri.origin == secondOrigin ? 2 : 1,
                ),
              ),
            );
          }
        },
      ),
    );
    central.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          centralCalls++;
          requireContract(
            request.uri.path == '/api/v1/auth/login',
            'central-path',
          );
          if (request.data['login'] == 'superadmin') {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: response('superadmin', control: true),
              ),
            );
          } else {
            // Reproduce the currently deployed stale server hint, not live accounts.
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: request,
                  statusCode: 403,
                  data: {
                    'code': 'local_access_required',
                    'message':
                        'В приложении выберите «Подключение к школе» перед входом.',
                  },
                ),
              ),
            );
          }
        },
      ),
    );
    await bootstrap(
      envFileName: 'assets/env/.env.example',
      configureOverrides: () async {
        await configureMockRepositories();
        getIt<Dio>().httpClientAdapter = NoDemoNetwork();
        getIt<Dio>().interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (request, handler) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.cancel,
                  message: 'Root network disabled in emulator audit',
                ),
              );
            },
          ),
        );
        final session = getIt<SessionService>();
        await session.clearSession();
        final connection = getIt<SchoolConnectionService>();
        await connection.select(
          SchoolConnection.parse(connection.defaultBaseUrl),
        );
        await connection.enableAutomaticDiscovery();
        await getIt.unregister<AuthSessionRepository>();
        getIt.registerSingleton<AuthSessionRepository>(
          AuthSessionRepositoryImpl(
            AuthApiDataSource(central, baseUrl: connection.defaultBaseUrl),
            session,
            schoolLogin: SchoolLoginCoordinator(
              SchoolDirectoryRepositoryImpl(
                'https://central.example/api/v1',
                client: directory,
              ),
              connection,
              schoolClient: school,
            ),
          ),
        );
      },
    );
    final connection = getIt<SchoolConnectionService>(),
        session = getIt<SessionService>();
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(
        tester.takeException(),
        isNull,
        reason: 'No overflow, DI or navigation exception',
      );
      expect(contractViolations, isEmpty);
    }

    Future<void> tap(Finder target) async {
      // Let native IME/focus scrolling finish before deliberately scrolling to
      // a button. Otherwise the scheduled focused-field scroll races this one.
      await settle();
      await Scrollable.ensureVisible(tester.element(target), alignment: .5);
      await settle();
      expect(target.hitTestable(), findsOneWidget);
      await tester.tap(target);
      await settle();
    }

    Future<void> shot(String name) async {
      debugPrint('Login emulator audit: $name');
      if (const bool.fromEnvironment('AUDIT_SKIP_SCREENSHOTS')) return;
      await settle();
      await binding.takeScreenshot('login-$name');
    }

    Future<void> fill([String login = 'teacher.demo']) async {
      await tester.enterText(find.byType(TextFormField).at(0), login);
      await tester.enterText(find.byType(TextFormField).at(1), password);
    }

    GoRouter router() => GoRouter.of(
      getIt<GlobalKey<NavigatorState>>(
        instanceName: 'navigatorKey',
      ).currentContext!,
    );
    Future<void> logout() async {
      await session.clearSession();
      await settle();
      router().go(AppRoutes.login);
      await settle();
    }

    Future<void> dismissPin() async {
      // Native secure storage writes complete on platform threads; pumping a
      // fixed number of frames is not a reliable authentication barrier.
      for (
        var i = 0;
        i < 100 &&
            session.currentUser == null &&
            find.byType(ErrorDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(
        session.currentUser,
        isNotNull,
        reason:
            'Synthetic login completes before role/PIN assertions; '
            'error=${find.byType(ErrorDialog).evaluate().isEmpty ? "none" : tester.widget<ErrorDialog>(find.byType(ErrorDialog)).failure.message}; '
            'central=$centralCalls directory=$directoryCalls school=$schoolCalls',
      );
      if (session.shouldOfferPin) {
        await session.dismissPinOffer();
        await settle();
      }
    }

    await settle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await shot('first-start');
    expect(find.text('Демонстрация'), findsNothing);
    expect(find.text('Подключить Raspberry по QR'), findsNothing);
    await tap(find.byIcon(Icons.more_horiz));
    await shot('menu-school');
    await tap(find.text('Вход в центр управления').last);
    expect(
      find.textContaining('Этот раздел только для главного администратора'),
      findsOneWidget,
    );
    await shot('central-explained');
    await tap(find.byIcon(Icons.more_horiz));
    expect(find.text('Вход в школу'), findsOneWidget);
    expect(find.text('Войти'), findsNothing);
    await shot('menu-central');
    await tap(find.text('Вход в школу'));

    // Offline school is not "wrong password", and never falls back to central.
    await fill();
    await tap(find.text('Войти'));
    expect(find.byType(ErrorDialog), findsOneWidget);
    final uiFailure = tester
        .widget<ErrorDialog>(find.byType(ErrorDialog))
        .failure;
    debugPrint(
      'Synthetic offline result: ${uiFailure.errorCode}; directory=$directoryCalls school=$schoolCalls central=$centralCalls',
    );
    await shot('raspberry-offline');
    expect(
      find.textContaining('Если Raspberry переподключается по QR'),
      findsOneWidget,
    );
    expect(centralCalls, 0);
    expect(schoolCalls, 1);
    expect(connection.confirmedSchoolId, isNull);
    await tap(find.text('ОК'));

    scenario = 'unknown';
    final beforeUnknown = schoolCalls;
    await fill('missing.demo');
    await tap(find.text('Войти'));
    expect(schoolCalls, beforeUnknown);
    expect(centralCalls, 0);
    await shot('unknown-login');
    await tap(find.text('ОК'));
    scenario = 'wrong';
    await fill();
    await tap(find.text('Войти'));
    expect(find.text('Неверный логин или пароль'), findsOneWidget);
    expect(centralCalls, 0);
    await shot('wrong-password');
    await tap(find.text('ОК'));

    // Recovery from the *wrong* sign-in screen requires a new deliberate login.
    await tap(find.byIcon(Icons.more_horiz));
    await tap(find.text('Вход в центр управления').last);
    await fill();
    await tap(find.text('Войти в центр управления'));
    expect(find.text('Подключение к школе'), findsNothing);
    expect(find.text('Вход в школу'), findsOneWidget);
    await shot('wrong-section-recovery');
    await tap(find.text('Вход в школу'));
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      isEmpty,
    );

    scenario = 'ok';
    for (final login in ['teacher.demo', 'guard.demo', 'school.admin']) {
      final beforeCentral = centralCalls;
      await fill(login);
      await tap(find.text('Войти'));
      for (
        var i = 0;
        i < 30 &&
            session.currentUser == null &&
            find.byType(ErrorDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      if (session.currentUser == null) {
        final dialogs = find.byType(ErrorDialog);
        final error = dialogs.evaluate().isEmpty
            ? null
            : tester.widget<ErrorDialog>(dialogs).failure;
        debugPrint(
          'Synthetic role result ${error?.runtimeType}/${error?.errorCode}/${error?.message}; directory=$directoryCalls school=$schoolCalls central=$centralCalls',
        );
        await shot('unexpected-role-error');
      }
      expect(
        session.currentUser,
        isNotNull,
        reason: 'Synthetic school login must complete',
      );
      await dismissPin();
      expect(session.currentUser!.login, login);
      expect(connection.confirmedSchoolId, 2);
      expect(connection.confirmedBuildingId, 1);
      expect(connection.confirmedLoginDigest, schoolLoginDigest(login));
      expect(centralCalls, beforeCentral);
      await shot('authenticated-$login');
      await logout();
    }
    scenario = 'multi';
    await fill('school.admin');
    final beforeChoose = schoolCalls;
    await tap(find.text('Войти'));
    expect(find.text('Выберите корпус'), findsOneWidget);
    expect(schoolCalls, beforeChoose);
    await shot('choose-building');
    await tap(find.text('Корпус 2 — длинное название для проверки переноса'));
    await dismissPin();
    expect(selectedOrigin, secondOrigin);
    expect(connection.confirmedBuildingId, 2);
    await shot('selected-building');
    await logout();

    scenario = 'ok';
    await tap(find.byIcon(Icons.more_horiz));
    await tap(find.text('Вход в центр управления').last);
    await fill('superadmin');
    await tap(find.text('Войти в центр управления'));
    await dismissPin();
    expect(session.currentUser!.role.wireName, 'super_admin');
    await shot('authenticated-central');
    await logout();
    await getIt<ThemeService>().setThemeMode(ThemeMode.dark);
    await shot('dark-login');
    await getIt<ThemeService>().setThemeMode(ThemeMode.light);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await shot('large-text-login');
    await tap(find.byIcon(Icons.more_horiz));
    await tap(find.text('Вход в центр управления').last);
    await shot('large-text-central');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    expect(directoryCalls, greaterThanOrEqualTo(8));
    directory.close(force: true);
    school.close(force: true);
    central.close(force: true);
    debugPrint(
      'Routing audit passed: synthetic transports only, no production passwords or writes',
    );
  });
}
