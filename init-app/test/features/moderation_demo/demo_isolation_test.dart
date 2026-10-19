import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/services/connectivity_service.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/moderation_demo/data/demo_dependencies.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';
import 'package:mobile_template/features/auth/data/repositories/mock_auth_session_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/account_deletion/domain/account_deletion.dart';
import 'package:mobile_template/features/moderation_demo/data/demo_admin_services.dart';
import 'package:mobile_template/features/audit/domain/audit_log_repository.dart';
import 'package:mobile_template/features/reports/data/report_export_service.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_buildings_repository.dart';
import 'package:excel/excel.dart';
import 'dart:convert';
import 'package:mobile_template/features/school_console/domain/repositories/teacher_students_repository.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GetIt container, root;
  late ConnectivityService connectivity;
  late SessionService rootSession;
  setUp(() async {
    root = getIt;
    await root.reset();
    rootSession = SessionService.inMemory();
    await rootSession.establishSession(
      const AuthSession(
        accessToken: 'synthetic-root-token',
        tokenType: 'bearer',
        expiresIn: 3600,
        user: MockAuthSessionRepository.teacher,
      ),
    );
    root.registerSingleton<SessionService>(rootSession);
    connectivity = ConnectivityService(Connectivity());
    container = GetIt.asNewInstance();
    await prepareDemoDependencies(container, connectivity);
  });
  tearDown(() async {
    restoreRealContainer(container);
    await container.reset();
    await root.reset();
    connectivity.dispose();
  });
  test(
    'demo has isolated RAM session, blocks network, root token survives',
    () async {
      expect(identical(getIt, container), isTrue);
      expect(identical(container<SessionService>(), rootSession), isFalse);
      expect(container<SessionService>().supportsPin, isFalse);
      await expectLater(
        container<Dio>().post(
          'https://school.example/api/v1/users/delete-account',
        ),
        throwsA(isA<DioException>()),
      );
      await container<SessionService>().clearSession();
      expect(rootSession.getAccessToken(), 'synthetic-root-token');
      restoreRealContainer(container);
      expect(identical(getIt<SessionService>(), rootSession), isTrue);
    },
  );
  test(
    'teacher to guard to history shares only synthetic in-memory requests',
    () async {
      final repo = container<ExitRequestRepository>();
      final created = (await repo.createExitRequests(
        CreateExitRequestCommand(
          classId: 1,
          studentIds: const [1, 2],
          reasonType: ExitReasonType.parentNote,
          scheduledAt: DateTime.now(),
        ),
      )).getOrElse((_) => throw StateError('create failed'));
      await container<AuthSessionRepository>().login(
        login: 'guard.demo',
        password: MockAuthSessionRepository.password,
      );
      expect(
        (await repo.getPendingGuardRequests()).getOrElse((_) => []).length,
        2,
      );
      await repo.releaseExitRequest(created.first.id);
      await container<AuthSessionRepository>().login(
        login: 'teacher.demo',
        password: MockAuthSessionRepository.password,
      );
      final snapshot = (await repo.getTeacherExitRequests()).getOrElse(
        (_) => throw StateError('history failed'),
      );
      expect(snapshot.active.length, 1);
      expect(snapshot.history.length, 1);
      expect(rootSession.getAccessToken(), 'synthetic-root-token');
    },
  );
  test(
    'added demo pupil is offered in the real request form repository',
    () async {
      await container<TeacherStudentsRepository>().createStudent(
        const StudentDraft(classId: 1, lastName: 'Пример', firstName: 'Демо'),
      );
      final pupils = (await container<ExitRequestRepository>().getClassStudents(
        1,
      )).getOrElse((_) => []);
      expect(pupils.length, 3);
      expect(pupils.last.fullName, 'Пример Демо');
    },
  );
  test('both admin demo roles, audit and reports remain offline', () async {
    for (final login in ['school.admin', 'superadmin']) {
      expect(
        (await container<AuthSessionRepository>().login(
          login: login,
          password: MockAuthSessionRepository.password,
        )).isRight(),
        isTrue,
      );
      expect(container<SessionService>().isDemo, isTrue);
    }
    expect(container.isRegistered<SchoolBuildingsRepository>(), isTrue);
    final logs = (await container<AuditLogRepository>().getLogs(
      schoolOnly: true,
      page: 1,
    )).getOrElse((_) => throw StateError('logs'));
    expect(logs.items.single.actorName, 'Демо Учитель');
    final reports = container<ReportExportService>() as DemoReportExportService;
    final xlsx = Excel.decodeBytes(await reports.buildBytes('xlsx'));
    expect(xlsx.tables.keys, contains('DEMO'));
    final pdf = ascii.decode(await reports.buildBytes('pdf'));
    expect(pdf, startsWith('%PDF-1.4'));
    expect(pdf, contains('Synthetic data only'));
    expect(rootSession.getAccessToken(), 'synthetic-root-token');
  });

  test(
    'deletion proof applies only to demo and never clears root session',
    () async {
      final repo = container<AccountDeletionRepository>();
      expect((await repo.delete('wrong', 'УДАЛИТЬ')).isLeft(), isTrue);
      expect(
        (await repo.delete(
          MockAuthSessionRepository.password,
          'УДАЛИТЬ',
        )).isRight(),
        isTrue,
      );
      expect(rootSession.getAccessToken(), 'synthetic-root-token');
    },
  );
}
