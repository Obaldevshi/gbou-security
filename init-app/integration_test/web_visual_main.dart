// Browser-only visual fixture. Never used by production main.dart or a release.
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

class _NoBrowserEvents extends RequestEventsService {
  _NoBrowserEvents() : super(Dio(), 'http://localhost');
  @override
  Stream<void> watch() => const Stream<void>.empty();
}

Future<void> main() async {
  await bootstrap(
    envFileName: 'assets/env/.env.example',
    configureOverrides: () async {
      await configureMockRepositories();
      getIt<Dio>().interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.reject(
            DioException(
              requestOptions: request,
              type: DioExceptionType.cancel,
              message: 'Network blocked in local browser fixture',
            ),
          ),
        ),
      );
      if (getIt.isRegistered<RequestEventsService>()) {
        await getIt.unregister<RequestEventsService>();
      }
      getIt.registerSingleton<RequestEventsService>(_NoBrowserEvents());
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
      await getIt<SessionService>().clearSession();
      final role = Uri.base.queryParameters['auditRole'];
      if (const [
        'teacher.demo',
        'guard.demo',
        'school.admin',
        'superadmin',
      ].contains(role)) {
        await getIt<AuthSessionRepository>().login(
          login: role!,
          password: MockAuthSessionRepository.password,
        );
      }
      await getIt<ThemeService>().setThemeMode(
        Uri.base.queryParameters['dark'] == '1'
            ? ThemeMode.dark
            : ThemeMode.light,
      );
    },
  );
}
