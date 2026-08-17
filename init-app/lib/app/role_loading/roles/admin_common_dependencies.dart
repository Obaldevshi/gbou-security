import 'package:dio/dio.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/features/audit/data/audit_log_data.dart';
import 'package:mobile_template/features/audit/domain/audit_log_repository.dart';
import 'package:mobile_template/features/audit/presentation/audit_log_cubit.dart';
import 'package:mobile_template/features/reports/data/report_export_service.dart';

void ensureAdminCommonDependencies() {
  final baseUrl = getIt<String>(instanceName: 'baseUrl');
  if (!getIt.isRegistered<AuditLogApiDataSource>()) {
    getIt.registerLazySingleton<AuditLogApiDataSource>(
      () => AuditLogApiDataSource(getIt<Dio>(), baseUrl),
    );
  }
  if (!getIt.isRegistered<AuditLogRepository>()) {
    getIt.registerLazySingleton<AuditLogRepository>(
      () => AuditLogRepositoryImpl(getIt<AuditLogApiDataSource>()),
    );
  }
  if (!getIt.isRegistered<AuditLogCubit>()) {
    getIt.registerFactory<AuditLogCubit>(
      () => AuditLogCubit(getIt<AuditLogRepository>()),
    );
  }
  if (!getIt.isRegistered<ReportExportService>()) {
    getIt.registerLazySingleton<ReportExportService>(
      () => ReportExportService(getIt<Dio>(), baseUrl),
    );
  }
}
