// Local visual fixture only. Never publish this entrypoint as a school client.
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:mobile_template/core/bootstrap.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/mock_di.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/exit_requests/data/request_events_service.dart';
import 'package:mobile_template/features/school_console/data/mock_school_buildings_repository.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_buildings_repository.dart';

class _NoEvents extends RequestEventsService {
  _NoEvents() : super(Dio(), 'http://localhost');
  @override
  Stream<void> watch() => const Stream<void>.empty();
}

Future<void> main() => bootstrap(
  envFileName: 'assets/env/.env.example',
  configureOverrides: () async {
    await configureMockRepositories();
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
              message: 'Network disabled in visual fixture',
            ),
          );
        },
      ),
    );
    await getIt<SessionService>().clearSession();
  },
);
