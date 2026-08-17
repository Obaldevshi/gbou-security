import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/role_loading/role_destination.dart';
import 'package:mobile_template/app/role_loading/roles/admin_common_dependencies.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/features/audit/presentation/audit_log_cubit.dart';
import 'package:mobile_template/features/audit/presentation/audit_log_page.dart';
import 'package:mobile_template/features/profile/presentation/pages/bloc/profile_bloc.dart';
import 'package:mobile_template/features/profile/presentation/pages/profile_page.dart';
import 'package:mobile_template/features/reports/presentation/reports_page.dart';
import 'package:mobile_template/features/school_management/data/datasources/school_management_api_data_source.dart';
import 'package:mobile_template/features/school_management/data/repositories/school_management_repository_impl.dart';
import 'package:mobile_template/features/school_management/domain/repositories/school_management_repository.dart';
import 'package:mobile_template/features/school_management/domain/usecases/school_usecases.dart';
import 'package:mobile_template/features/school_management/presentation/cubit/school_admins_cubit.dart';
import 'package:mobile_template/features/school_management/presentation/cubit/school_management_cubit.dart';
import 'package:mobile_template/features/school_management/presentation/pages/school_admins_page.dart';
import 'package:mobile_template/features/school_management/presentation/pages/school_management_page.dart';

void _ensureDependencies() {
  ensureAdminCommonDependencies();
  if (!getIt.isRegistered<SchoolManagementRepository>()) {
    getIt.registerLazySingleton<SchoolManagementRepository>(
      () => SchoolManagementRepositoryImpl(
        SchoolManagementApiDataSource(
          getIt<Dio>(),
          getIt<String>(instanceName: 'baseUrl'),
        ),
      ),
    );
  }
  final repository = getIt<SchoolManagementRepository>();
  if (!getIt.isRegistered<SchoolManagementCubit>()) {
    getIt.registerFactory<SchoolManagementCubit>(
      () => SchoolManagementCubit(
        GetSchoolsUsecase(repository),
        GetSystemStatsUsecase(repository),
        CreateSchoolUsecase(repository),
        UpdateSchoolUsecase(repository),
        SetSchoolStatusUsecase(repository),
        DeleteSchoolUsecase(repository),
      ),
    );
  }
  if (!getIt.isRegistered<SchoolAdminsCubit>()) {
    getIt.registerFactory<SchoolAdminsCubit>(
      () => SchoolAdminsCubit(
        GetSchoolsUsecase(repository),
        GetSchoolAdminsUsecase(repository),
        CreateSchoolAdminUsecase(repository),
        UpdateSchoolAdminUsecase(repository),
        SetSchoolAdminStatusUsecase(repository),
        DeleteSchoolAdminUsecase(repository),
      ),
    );
  }
}

Widget buildSuperAdminDestination(RoleDestination destination) {
  _ensureDependencies();
  return switch (destination) {
    RoleDestination.systemSchools => BlocProvider(
      create: (_) => getIt<SchoolManagementCubit>()..load(),
      child: const SchoolManagementPage(),
    ),
    RoleDestination.systemSchoolAdmins => BlocProvider(
      create: (_) => getIt<SchoolAdminsCubit>()..load(),
      child: const SchoolAdminsPage(),
    ),
    RoleDestination.systemAudit => BlocProvider(
      create: (_) => getIt<AuditLogCubit>()..load(schoolScope: false),
      child: const AuditLogPage(schoolOnly: false),
    ),
    RoleDestination.systemReports => const ReportsPage(schoolOnly: false),
    RoleDestination.systemProfile => BlocProvider(
      create: (_) => getIt<ProfileBloc>()..add(GetProfileEvent()),
      child: const ProfilePage(),
    ),
    _ => throw StateError('Маршрут не относится к главному администратору'),
  };
}
