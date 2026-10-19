import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/core/bootstrap.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/core/services/school_connection_service.dart';
import 'package:mobile_template/features/moderation_demo/data/demo_dependencies.dart';
import 'package:mobile_template/features/privacy/presentation/privacy_page.dart';
import 'package:mobile_template/features/account_deletion/presentation/account_deletion_page.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/data/repositories/mock_exit_request_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'offline policy, real-screen isolated demo and own-account deletion',
    (tester) async {
      await bootstrap(
        envFileName: 'assets/env/.env.example',
        configureOverrides: () async {
          getIt<Dio>().httpClientAdapter = NoDemoNetwork();
          await getIt<SessionService>().clearSession();
        },
      );
      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 350));
        }
        expect(
          tester.takeException(),
          isNull,
          reason: 'No overflow, navigation or DI error',
        );
      }

      Future<void> shot(String name) async {
        await settle();
        final notice = find.text(
          'ДЕМО · вымышленные данные, без доступа к школе',
        );
        if (getIt<SessionService>().isDemo) {
          expect(notice.hitTestable(), findsOneWidget);
          expect(tester.getRect(notice).top, greaterThanOrEqualTo(0));
        }
        await binding.takeScreenshot('store-$name');
        debugPrint('Store readiness: $name');
      }

      Future<void> tapVisible(Finder finder) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await settle();
        await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
        await settle();
        expect(finder.hitTestable(), findsOneWidget);
        await tester.tap(finder);
        await settle();
      }

      await settle();
      final realContainer = getIt;
      final realSession = getIt<SessionService>();
      final realConnection = getIt<SchoolConnectionService>().connection.scope;
      final storage = await const FlutterSecureStorage().readAll();
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await tapVisible(find.text('Конфиденциальность'));
      await shot('privacy');
      expect(find.byType(PrivacyPage), findsOneWidget);
      GoRouter.of(tester.element(find.byType(PrivacyPage))).pop();
      await settle();
      await tapVisible(find.text('Демонстрация'));
      await shot('demo-request');
      expect(identical(realContainer, getIt), isFalse);
      expect(getIt<SessionService>().isDemo, isTrue);
      final picker = find.text('Выберите учеников').first;
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await settle();
      expect(
        find.text('ДЕМО · вымышленные данные, без доступа к школе'),
        findsOneWidget,
      );
      await tester.tap(find.text('Выбрать всех'));
      final done = find.textContaining('Готово · выбрано');
      expect(done.hitTestable(), findsOneWidget);
      await shot('demo-picker');
      await tester.tap(done);
      await settle();
      await tapVisible(find.byType(DropdownButtonFormField<ExitReasonType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('По заявлению родителя').last);
      await settle();
      await tapVisible(find.text('Сейчас или укажите время'));
      await tester.tap(find.text('Сейчас').last);
      await settle();
      final send = find.textContaining('Отправить заявки');
      await tapVisible(send);
      await shot('demo-active');
      final requests =
          getIt<ExitRequestRepository>() as MockExitRequestRepository;
      expect(requests.createdRequests.length, 2);
      await tester.tap(find.byTooltip('Роль в демонстрации'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Охрана').last);
      await shot('demo-guard');
      await tapVisible(find.text('Отпустить').first);
      expect(
        requests.createdRequests
            .where((e) => e.status == ExitRequestStatus.released)
            .length,
        1,
      );
      await tapVisible(find.text('История').last);
      await shot('demo-guard-history');
      Future<void> demoRole(String label) async {
        await tester.tap(find.byTooltip('Роль в демонстрации'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await settle();
      }

      Future<void> demoRoute(String path) async {
        final nav = getIt<GlobalKey<NavigatorState>>(
          instanceName: 'navigatorKey',
        );
        GoRouter.of(nav.currentContext!).go(path);
        await settle();
      }

      await demoRole('Администратор школы');
      await shot('demo-school-admin');
      await demoRoute(AppRoutes.schoolTeachers);
      await tapVisible(find.text('Добавить учителя'));
      await shot('demo-teacher-form');
      getIt<GlobalKey<NavigatorState>>(
        instanceName: 'navigatorKey',
      ).currentState!.pop();
      await settle();
      await demoRoute(AppRoutes.schoolAudit);
      await shot('demo-school-audit');
      await demoRoute(AppRoutes.schoolReports);
      await tapVisible(find.text('Дата начала'));
      await shot('demo-report-date');
      getIt<GlobalKey<NavigatorState>>(
        instanceName: 'navigatorKey',
      ).currentState!.pop();
      await settle();
      await demoRole('Главный администратор');
      await shot('demo-super-admin');
      await tapVisible(find.text('Добавить школу'));
      await shot('demo-school-form');
      getIt<GlobalKey<NavigatorState>>(
        instanceName: 'navigatorKey',
      ).currentState!.pop();
      await settle();
      await demoRoute(AppRoutes.systemSchoolAdmins);
      await shot('demo-school-admins');
      await tester.tap(find.byTooltip('Роль в демонстрации'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Учитель').last);
      await settle();
      final key = getIt<GlobalKey<NavigatorState>>(
        instanceName: 'navigatorKey',
      );
      GoRouter.of(key.currentContext!).go(AppRoutes.teacherProfile);
      await settle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Удаление аккаунта')),
        alignment: .3,
      );
      await tester.tap(find.text('Удаление аккаунта'));
      await settle();
      expect(find.byType(AccountDeletionPage), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'wrong');
      await tester.enterText(find.byType(TextField).at(1), 'УДАЛИТЬ');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Удалить аккаунт')),
        alignment: .3,
      );
      await tester.tap(find.text('Удалить аккаунт'));
      await shot('delete-proof-error');
      expect(getIt<SessionService>().currentUser, isNotNull);
      await tester.enterText(find.byType(TextField).at(0), 'DemoPass123!');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Удалить аккаунт')),
        alignment: .3,
      );
      await tester.tap(find.text('Удалить аккаунт'));
      await shot('demo-deleted');
      expect(getIt<SessionService>().currentUser, isNull);
      // Exit during the delayed role login: it must not touch the restored DI.
      await tester.tap(find.byTooltip('Роль в демонстрации'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Администратор школы').last);
      // Let the menu barrier close, but do not wait for the mock role login.
      await tester.pump(const Duration(milliseconds: 320));
      await tester.tap(find.byTooltip('Выйти из демонстрации'));
      await settle();
      expect(identical(realContainer, getIt), isTrue);
      expect(identical(realSession, getIt<SessionService>()), isTrue);
      expect(getIt<SchoolConnectionService>().connection.scope, realConnection);
      expect(
        await const FlutterSecureStorage().readAll(),
        storage,
        reason: 'Demo cannot mutate real secure session or school settings',
      );
      await shot('real-login-restored');
    },
  );
}
