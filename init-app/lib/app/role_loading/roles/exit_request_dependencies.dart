import 'package:dio/dio.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/features/exit_requests/data/datasources/exit_request_api_data_source.dart';
import 'package:mobile_template/features/exit_requests/data/repositories/exit_request_repository_impl.dart';
import 'package:mobile_template/features/exit_requests/data/request_events_service.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';

void ensureExitRequestDependencies() {
  final baseUrl = getIt<String>(instanceName: 'baseUrl');
  if (!getIt.isRegistered<ExitRequestApiDataSource>()) {
    getIt.registerLazySingleton<ExitRequestApiDataSource>(
      () => ExitRequestApiDataSource(getIt<Dio>(), baseUrl: baseUrl),
    );
  }
  if (!getIt.isRegistered<ExitRequestRepository>()) {
    getIt.registerLazySingleton<ExitRequestRepository>(
      () => ExitRequestRepositoryImpl(getIt<ExitRequestApiDataSource>()),
    );
  }
  if (!getIt.isRegistered<RequestEventsService>()) {
    getIt.registerLazySingleton<RequestEventsService>(
      () => RequestEventsService(getIt<Dio>(), baseUrl),
    );
  }
}
