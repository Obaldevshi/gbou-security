// Real emulator rendering with synthetic repositories only. No school records.
import 'dart:async';
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
import 'package:mobile_template/core/services/theme_service.dart';
import 'package:mobile_template/features/auth/data/repositories/mock_auth_session_repository.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:mobile_template/features/exit_requests/data/request_events_service.dart';
import 'package:mobile_template/features/exit_requests/data/repositories/mock_exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';
import 'package:mobile_template/features/school_console/data/mock_school_buildings_repository.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_buildings_repository.dart';
import 'package:mobile_template/presentation/widgets/common/glass_bottom_nav_bar.dart';

class _NoEvents extends RequestEventsService {
  _NoEvents() : super(Dio(), 'http://localhost');
  @override
  Stream<void> watch() => const Stream<void>.empty();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Visual audit of all roles and modal navigation on Android', (
    tester,
  ) async {
    await bootstrap(
      envFileName: 'assets/env/.env.example',
      configureOverrides: () async {
        await configureMockRepositories();
        await getIt.unregister<ExitRequestRepository>();
        getIt.registerSingleton<ExitRequestRepository>(
          MockExitRequestRepository(
            studentsProvider: () => List.generate(
              35,
              (i) => Student(
                id: i + 1,
                classId: 1,
                firstName: 'Ученикномер${i + 1}',
                lastName: 'Демонстрационный',
                middleName: 'Проверочный',
                fullName: 'Демонстрационный Ученикномер${i + 1} Проверочный',
              ),
            ),
          ),
        );
        if (getIt.isRegistered<RequestEventsService>()) {
          await getIt.unregister<RequestEventsService>();
        }
        getIt.registerSingleton<RequestEventsService>(_NoEvents());
        if (getIt.isRegistered<SchoolBuildingsRepository>()) {
          await getIt.unregister<SchoolBuildingsRepository>();
        }
        getIt.registerSingleton<SchoolBuildingsRepository>(
          MockSchoolBuildingsRepository(),
        );
        getIt<Dio>().interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (request, handler) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  message: 'Network disabled in visual audit',
                ),
              );
            },
          ),
        );
        await getIt<SessionService>().clearSession();
      },
    );
    Future<void> settle() async {
      for (var i = 0; i < 18; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.takeException(),
        isNull,
        reason: 'No layout overflow or rendering exception',
      );
    }

    Future<void> shot(String name) async {
      debugPrint('AUDIT screenshot $name');
      await settle();
      await binding.takeScreenshot(name).timeout(const Duration(seconds: 25));
    }

    Future<void> route(String path) async {
      final context = getIt<GlobalKey<NavigatorState>>(
        instanceName: 'navigatorKey',
      ).currentContext!;
      GoRouter.of(context).go(path);
      await settle();
    }

    Future<void> login(String name) async {
      await getIt<SessionService>().clearSession();
      await settle();
      await route(AppRoutes.login);
      await getIt<AuthSessionRepository>().login(
        login: name,
        password: MockAuthSessionRepository.password,
      );
      await settle();
      if (getIt<SessionService>().shouldOfferPin) {
        if (name == 'teacher.demo') {
          await shot('pin-setup');
          await tester.ensureVisible(find.text('Не сейчас'));
          await shot('pin-setup-actions');
          expect(find.text('Не сейчас').hitTestable(), findsOneWidget);
        }
        await getIt<SessionService>().dismissPinOffer();
        await settle();
      }
    }

    await settle();
    debugPrint('AUDIT convert surface');
    await binding.convertFlutterSurfaceToImage().timeout(
      const Duration(seconds: 25),
    );
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('01-login');
    if (!const bool.fromEnvironment('AUDIT_FOCUSED')) {
      await login('teacher.demo');
      await shot('02-teacher-request');
      final pick = find.text('Выберите учеников').first;
      await tester.ensureVisible(pick);
      await tester.tap(pick);
      await shot('03-student-picker');
      final done = find.textContaining('Готово · выбрано');
      expect(
        done.hitTestable(),
        findsOneWidget,
        reason: 'Done must not be covered by bottom navigation',
      );
      await tester.tap(find.text('Выбрать всех'));
      await tester.scrollUntilVisible(
        find.text('Демонстрационный Ученикномер35 Проверочный'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.textContaining('Готово · выбрано 35').hitTestable(),
        findsOneWidget,
      );
      await shot('03-student-picker-last-of-35');
      await tester.tap(done);
      await shot('04-selected-students');
      await route(AppRoutes.teacherStudents);
      await shot('05-teacher-students');
      final add = find.widgetWithText(FloatingActionButton, 'Добавить ученика');
      expect(add.hitTestable(), findsOneWidget);
      final navigation = find.byType(GlassBottomNavBar);
      if (navigation.evaluate().isNotEmpty) {
        expect(
          tester.getRect(add).overlaps(tester.getRect(navigation)),
          isFalse,
          reason: 'Add student must sit above navigation',
        );
      }
      await tester.tap(add);
      await shot('06-add-student');
      await tester.tap(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, 'Тестоваяфамилия');
      await shot('06-add-student-keyboard');
      await tester.ensureVisible(find.text('Добавить'));
      expect(find.text('Добавить').hitTestable(), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(tester.element(find.byType(TextField).first)).pop();
      await settle();
      for (final page in [
        AppRoutes.teacherActive,
        AppRoutes.teacherHistory,
        AppRoutes.teacherProfile,
      ]) {
        await route(page);
        await shot('teacher-${page.split('/').last}');
      }
      await getIt<ThemeService>().setThemeMode(ThemeMode.dark);
      await route(AppRoutes.teacherRequest);
      await shot('07-teacher-dark');
      await getIt<ThemeService>().setThemeMode(ThemeMode.light);
      for (final entry in {
        'guard.demo': [AppRoutes.guardQueue, AppRoutes.guardProfile],
        'school.admin': [
          AppRoutes.schoolClasses,
          AppRoutes.schoolBuildings,
          AppRoutes.schoolStudents,
          AppRoutes.schoolTeachers,
          AppRoutes.schoolGuards,
          AppRoutes.schoolRequests,
          AppRoutes.schoolProfile,
        ],
        'superadmin': [
          AppRoutes.systemSchools,
          AppRoutes.systemSchoolAdmins,
          AppRoutes.systemProfile,
        ],
      }.entries) {
        await login(entry.key);
        for (final page in entry.value) {
          await route(page);
          await shot(page.substring(1).replaceAll('/', '-'));
          final addLabel = {
            AppRoutes.schoolClasses: 'Добавить класс',
            AppRoutes.schoolBuildings: 'Добавить корпус',
            AppRoutes.schoolStudents: 'Добавить ученика',
            AppRoutes.schoolTeachers: 'Добавить учителя',
            AppRoutes.schoolGuards: 'Добавить охранника',
            AppRoutes.systemSchools: 'Добавить школу',
            AppRoutes.systemSchoolAdmins: 'Создать учётную запись',
          }[page];
          if (addLabel != null) {
            final button = find.widgetWithText(FloatingActionButton, addLabel);
            expect(button.hitTestable(), findsOneWidget);
            await tester.tap(button);
            await shot('${page.substring(1).replaceAll('/', '-')}-form');
            getIt<GlobalKey<NavigatorState>>(
              instanceName: 'navigatorKey',
            ).currentState!.pop();
            await settle();
          }
        }
      }
      await route('/connect/demo');
      await shot('08-qr-login');
    }
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // Physical display changes are tested with browser viewport overrides.
    // Keep the emulator surface native-sized for the Android screenshot API.
    for (final width in [
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    ]) {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      await login('teacher.demo');
      await route(AppRoutes.teacherRequest);
      final stressPicker = find.text('Выберите учеников').first;
      await Scrollable.ensureVisible(
        tester.element(stressPicker),
        alignment: 0.25,
      );
      await settle();
      expect(stressPicker.hitTestable(), findsOneWidget);
      await tester.tap(stressPicker);
      await shot('stress-${width.toInt()}-picker-large-text');
      expect(
        find.textContaining('Готово · выбрано').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.textContaining('Готово · выбрано'));
      await route(AppRoutes.teacherStudents);
      await shot('stress-${width.toInt()}-students-large-text');
      await login('school.admin');
      await route(AppRoutes.schoolRequests);
      await shot('stress-${width.toInt()}-requests-large-text');
      await login('guard.demo');
      await route(AppRoutes.guardQueue);
      await shot('stress-${width.toInt()}-guard-large-text');
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await route(AppRoutes.guardProfile);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    await Scrollable.ensureVisible(
      tester.element(find.text('Лицензии компонентов')),
      alignment: 0.4,
    );
    await settle();
    expect(find.text('Лицензии компонентов').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Лицензии компонентов'));
    await shot('09-licenses');
    await tester.scrollUntilVisible(
      find.text('Quicksand'),
      450,
      scrollable: find.byType(Scrollable).last,
    );
    await shot('10-quicksand-license-entry');
    expect(find.text('Quicksand'), findsOneWidget);
    getIt<GlobalKey<NavigatorState>>(
      instanceName: 'navigatorKey',
    ).currentState!.pop();
    await getIt<SessionService>().clearSession();
  });
}
