// Isolated screenshot fixture. Never connects to the production database.
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:mobile_template/core/bootstrap.dart';
import 'package:mobile_template/core/mock_di.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/features/moderation_demo/data/demo_dependencies.dart';
import 'package:mobile_template/features/exit_requests/data/request_events_service.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';
import 'package:mobile_template/features/school_console/data/mock_school_buildings_repository.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_buildings_repository.dart';

class DemoEvents extends RequestEventsService {
  DemoEvents() : super(Dio(), 'http://localhost');
  @override
  Stream<void> watch() => const Stream<void>.empty();
}

Future<void> main() async {
  await bootstrap(
    envFileName: 'assets/env/.env.example',
    configureOverrides: () async {
      await configureMockRepositories();
      getIt<Dio>().httpClientAdapter = NoDemoNetwork();
      if (getIt.isRegistered<RequestEventsService>()) {
        await getIt.unregister<RequestEventsService>();
      }
      getIt.registerSingleton<RequestEventsService>(DemoEvents());
      if (getIt.isRegistered<SchoolBuildingsRepository>()) {
        await getIt.unregister<SchoolBuildingsRepository>();
      }
      getIt.registerSingleton<SchoolBuildingsRepository>(MockSchoolBuildingsRepository());
      final repository = getIt<ExitRequestRepository>();
      await repository.createExitRequests(CreateExitRequestCommand(
        classId: 1,
        studentIds: const [1],
        reasonType: ExitReasonType.parentNote,
        scheduledAt: DateTime.now(),
      ));
      await repository.releaseExitRequest(1);
    },
  );
}
