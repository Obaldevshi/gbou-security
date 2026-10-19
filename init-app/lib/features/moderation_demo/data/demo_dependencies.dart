import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/mock_di.dart';
import 'package:mobile_template/core/services/connectivity_service.dart';
import 'package:mobile_template/core/services/locale_service.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/core/services/theme_service.dart';
import 'package:mobile_template/domain/repositories/auth_repository.dart';
import 'package:mobile_template/features/moderation_demo/data/demo_profile_repository.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:mobile_template/features/auth/data/repositories/mock_auth_session_repository.dart';
import 'package:mobile_template/features/auth/domain/usecases/login_usecase.dart';
import 'package:mobile_template/features/auth/domain/usecases/logout_usecase.dart';
import 'package:mobile_template/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:mobile_template/features/auth/presentation/pages/login/bloc/login_bloc.dart';
import 'package:mobile_template/features/auth/presentation/pages/splash/bloc/session_bootstrap_cubit.dart';
import 'package:mobile_template/features/profile/domain/usecases/change_password_usecase.dart';
import 'package:mobile_template/features/profile/domain/usecases/delete_account_usecase.dart';
import 'package:mobile_template/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:mobile_template/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:mobile_template/features/profile/presentation/pages/bloc/profile_bloc.dart';
import 'package:mobile_template/features/exit_requests/data/request_events_service.dart';
import 'package:mobile_template/features/exit_requests/data/repositories/mock_exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/school_console/data/mock_teacher_students_repository.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/domain/repositories/teacher_students_repository.dart';
import 'package:mobile_template/features/privacy/data/bundled_privacy_repository.dart';
import 'package:mobile_template/features/privacy/domain/privacy_policy.dart';
import 'package:mobile_template/features/moderation_demo/data/demo_admin_services.dart';
import 'package:mobile_template/features/audit/domain/audit_log_repository.dart';
import 'package:mobile_template/features/reports/data/report_export_service.dart';
import 'package:mobile_template/features/school_console/data/mock_school_buildings_repository.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_buildings_repository.dart';

/// Final transport barrier. There is no real HTTP adapter in the demo container.
class NoDemoNetwork implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) => Future.error(
    DioException(
      requestOptions: options,
      type: DioExceptionType.cancel,
      message: 'Network disabled in demonstration',
    ),
  );
  @override
  void close({bool force = false}) {}
}

class _DemoEvents extends RequestEventsService {
  _DemoEvents(Dio dio) : super(dio, 'https://demo.invalid/api/v1');
  @override
  Stream<void> watch() => const Stream.empty();
}

Future<void> prepareDemoDependencies(
  GetIt container,
  ConnectivityService connectivity,
) async {
  final session = SessionService.inMemory();
  final dio = Dio()..httpClientAdapter = NoDemoNetwork();
  container
    ..registerSingleton<SessionService>(session)
    ..registerSingleton<ConnectivityService>(connectivity)
    ..registerSingleton<ThemeService>(ThemeService.inMemory())
    ..registerSingleton<LocaleService>(LocaleService.inMemory())
    ..registerSingleton<Dio>(dio, dispose: (value) => value.close(force: true))
    ..registerSingleton<String>(
      'https://demo.invalid/api/v1',
      instanceName: 'baseUrl',
    )
    ..registerSingleton<GlobalKey<NavigatorState>>(
      GlobalKey<NavigatorState>(),
      instanceName: 'navigatorKey',
    )
    ..registerSingleton<PrivacyPolicyRepository>(BundledPrivacyRepository())
    ..registerSingleton<RequestEventsService>(_DemoEvents(dio));
  // configureMockRepositories now sees ONLY the isolated container, never parent registrations.
  activateDemoContainer(container);
  await configureMockRepositories();
  container
    ..registerSingleton<SchoolBuildingsRepository>(
      MockSchoolBuildingsRepository(),
    )
    ..registerSingleton<AuditLogRepository>(DemoAuditRepository());
  await container.unregister<AuthRepository>();
  container.registerSingleton<AuthRepository>(DemoProfileRepository(session));
  final students =
      container<TeacherStudentsRepository>() as MockTeacherStudentsRepository;
  students.items.clear();
  for (final child in [
    MockExitRequestRepository.demoStudent,
    MockExitRequestRepository.demoStudentTwo,
  ]) {
    students.items.add(
      ManagedStudent(
        id: child.id,
        classId: 1,
        className: '5А',
        lastName: child.lastName,
        firstName: child.firstName,
        middleName: child.middleName,
        isActive: true,
      ),
    );
  }
  students.nextId = 3;
  await container.unregister<ExitRequestRepository>();
  container.registerSingleton<ExitRequestRepository>(
    MockExitRequestRepository(
      studentsProvider: () => students.items
          .where((e) => e.isActive)
          .map(
            (e) => Student(
              id: e.id,
              classId: e.classId,
              firstName: e.firstName,
              lastName: e.lastName,
              middleName: e.middleName,
              fullName: e.fullName,
            ),
          )
          .toList(),
    ),
  );
  container
    ..registerSingleton<ReportExportService>(
      DemoReportExportService(container<ExitRequestRepository>(), dio),
    )
    ..registerFactory<LoginUsecase>(
      () => LoginUsecase(container<AuthSessionRepository>()),
    )
    ..registerFactory<LogoutUsecase>(
      () => LogoutUsecase(container<AuthSessionRepository>()),
    )
    ..registerFactory<RestoreSessionUsecase>(
      () => RestoreSessionUsecase(container<AuthSessionRepository>()),
    )
    ..registerFactory<LoginBloc>(
      () => LoginBloc(loginUsecase: container<LoginUsecase>()),
    )
    ..registerFactory<SessionBootstrapCubit>(
      () => SessionBootstrapCubit(container<RestoreSessionUsecase>()),
    )
    ..registerFactory<ProfileBloc>(
      () => ProfileBloc(
        GetProfileUsecase(container<AuthRepository>()),
        UpdateProfileUsecase(container<AuthRepository>()),
        DeleteAccountUsecase(container<AuthRepository>()),
        ChangePasswordUsecase(container<AuthRepository>()),
      ),
    );
  await container<AuthSessionRepository>().login(
    login: 'teacher.demo',
    password: MockAuthSessionRepository.password,
  );
}
