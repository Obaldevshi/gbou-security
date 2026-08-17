import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/role_loading/role_destination.dart';
import 'package:mobile_template/app/role_loading/roles/admin_common_dependencies.dart';
import 'package:mobile_template/app/role_loading/roles/exit_request_dependencies.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/features/audit/presentation/audit_log_cubit.dart';
import 'package:mobile_template/features/audit/presentation/audit_log_page.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/cancel_school_exit_request_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_school_exit_requests_usecase.dart';
import 'package:mobile_template/features/profile/presentation/pages/bloc/profile_bloc.dart';
import 'package:mobile_template/features/profile/presentation/pages/profile_page.dart';
import 'package:mobile_template/features/reports/presentation/reports_page.dart';
import 'package:mobile_template/features/school_console/data/school_classes_data.dart';
import 'package:mobile_template/features/school_console/data/school_buildings_data.dart';
import 'package:mobile_template/features/school_console/data/school_guards_data.dart';
import 'package:mobile_template/features/school_console/data/school_students_data.dart';
import 'package:mobile_template/features/school_console/data/school_teachers_data.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_classes_repository.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_buildings_repository.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_guards_repository.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_students_repository.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_teachers_repository.dart';
import 'package:mobile_template/features/school_console/domain/usecases/guard_usecases.dart';
import 'package:mobile_template/features/school_console/domain/usecases/school_class_usecases.dart';
import 'package:mobile_template/features/school_console/domain/usecases/school_building_usecases.dart';
import 'package:mobile_template/features/school_console/domain/usecases/student_usecases.dart';
import 'package:mobile_template/features/school_console/domain/usecases/teacher_usecases.dart';
import 'package:mobile_template/features/school_console/presentation/school_classes_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/school_buildings_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/school_buildings_page.dart';
import 'package:mobile_template/features/school_console/presentation/school_classes_page.dart';
import 'package:mobile_template/features/school_console/presentation/school_guards_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/school_guards_page.dart';
import 'package:mobile_template/features/school_console/presentation/school_requests_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/school_requests_page.dart';
import 'package:mobile_template/features/school_console/presentation/school_students_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/school_students_page.dart';
import 'package:mobile_template/features/school_console/presentation/school_teachers_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/school_teachers_page.dart';

void _ensureRepositories() {
  final dio = getIt<Dio>();
  final baseUrl = getIt<String>(instanceName: 'baseUrl');
  if (!getIt.isRegistered<SchoolBuildingsRepository>()) {
    getIt.registerLazySingleton<SchoolBuildingsRepository>(
      () => SchoolBuildingsRepositoryImpl(
        SchoolBuildingsApiDataSource(dio, baseUrl),
      ),
    );
  }
  if (!getIt.isRegistered<SchoolClassesRepository>()) {
    getIt.registerLazySingleton<SchoolClassesRepository>(
      () =>
          SchoolClassesRepositoryImpl(SchoolClassesApiDataSource(dio, baseUrl)),
    );
  }
  if (!getIt.isRegistered<SchoolStudentsRepository>()) {
    getIt.registerLazySingleton<SchoolStudentsRepository>(
      () => SchoolStudentsRepositoryImpl(
        SchoolStudentsApiDataSource(dio, baseUrl),
      ),
    );
  }
  if (!getIt.isRegistered<SchoolTeachersRepository>()) {
    getIt.registerLazySingleton<SchoolTeachersRepository>(
      () => SchoolTeachersRepositoryImpl(
        SchoolTeachersApiDataSource(dio, baseUrl),
      ),
    );
  }
  if (!getIt.isRegistered<SchoolGuardsRepository>()) {
    getIt.registerLazySingleton<SchoolGuardsRepository>(
      () => SchoolGuardsRepositoryImpl(SchoolGuardsApiDataSource(dio, baseUrl)),
    );
  }
}

void _ensureCubits() {
  final buildings = getIt<SchoolBuildingsRepository>();
  final classes = getIt<SchoolClassesRepository>();
  final students = getIt<SchoolStudentsRepository>();
  final teachers = getIt<SchoolTeachersRepository>();
  final guards = getIt<SchoolGuardsRepository>();

  if (!getIt.isRegistered<SchoolBuildingsCubit>()) {
    getIt.registerFactory<SchoolBuildingsCubit>(
      () => SchoolBuildingsCubit(
        GetManagedBuildingsUsecase(buildings),
        SaveManagedBuildingUsecase(buildings),
        SetManagedBuildingStatusUsecase(buildings),
        DeleteManagedBuildingUsecase(buildings),
      ),
    );
  }

  if (!getIt.isRegistered<SchoolClassesCubit>()) {
    getIt.registerFactory<SchoolClassesCubit>(
      () => SchoolClassesCubit(
        GetManagedBuildingsUsecase(buildings),
        GetManagedClassesUsecase(classes),
        CreateManagedClassUsecase(classes),
        UpdateManagedClassUsecase(classes),
        SetManagedClassStatusUsecase(classes),
        DeleteManagedClassUsecase(classes),
      ),
    );
  }
  if (!getIt.isRegistered<SchoolStudentsCubit>()) {
    getIt.registerFactory<SchoolStudentsCubit>(
      () => SchoolStudentsCubit(
        GetManagedClassesUsecase(classes),
        GetManagedStudentsUsecase(students),
        CreateManagedStudentUsecase(students),
        UpdateManagedStudentUsecase(students),
        SetManagedStudentStatusUsecase(students),
        DeleteManagedStudentUsecase(students),
        ImportManagedStudentsUsecase(students),
      ),
    );
  }
  if (!getIt.isRegistered<SchoolTeachersCubit>()) {
    getIt.registerFactory<SchoolTeachersCubit>(
      () => SchoolTeachersCubit(
        GetManagedBuildingsUsecase(buildings),
        GetManagedClassesUsecase(classes),
        GetManagedTeachersUsecase(teachers),
        CreateManagedTeacherUsecase(teachers),
        UpdateManagedTeacherUsecase(teachers),
        SetManagedTeacherStatusUsecase(teachers),
        DeleteManagedTeacherUsecase(teachers),
        ImportManagedTeachersUsecase(teachers),
      ),
    );
  }
  if (!getIt.isRegistered<SchoolGuardsCubit>()) {
    getIt.registerFactory<SchoolGuardsCubit>(
      () => SchoolGuardsCubit(
        GetManagedBuildingsUsecase(buildings),
        GetManagedGuardsUsecase(guards),
        CreateManagedGuardUsecase(guards),
        UpdateManagedGuardUsecase(guards),
        SetManagedGuardStatusUsecase(guards),
        DeleteManagedGuardUsecase(guards),
      ),
    );
  }
  if (!getIt.isRegistered<SchoolRequestsCubit>()) {
    final requests = getIt<ExitRequestRepository>();
    getIt.registerFactory<SchoolRequestsCubit>(
      () => SchoolRequestsCubit(
        GetSchoolExitRequestsUsecase(requests),
        CancelSchoolExitRequestUsecase(requests),
      ),
    );
  }
}

void _ensureDependencies() {
  ensureExitRequestDependencies();
  ensureAdminCommonDependencies();
  _ensureRepositories();
  _ensureCubits();
}

Widget buildSchoolAdminDestination(RoleDestination destination) {
  _ensureDependencies();
  return switch (destination) {
    RoleDestination.schoolBuildings => BlocProvider(
      create: (_) => getIt<SchoolBuildingsCubit>()..load(),
      child: const SchoolBuildingsPage(),
    ),
    RoleDestination.schoolClasses => BlocProvider(
      create: (_) => getIt<SchoolClassesCubit>()..load(),
      child: const SchoolClassesPage(),
    ),
    RoleDestination.schoolStudents => BlocProvider(
      create: (_) => getIt<SchoolStudentsCubit>()..load(),
      child: const SchoolStudentsPage(),
    ),
    RoleDestination.schoolTeachers => BlocProvider(
      create: (_) => getIt<SchoolTeachersCubit>()..load(),
      child: const SchoolTeachersPage(),
    ),
    RoleDestination.schoolGuards => BlocProvider(
      create: (_) => getIt<SchoolGuardsCubit>()..load(),
      child: const SchoolGuardsPage(),
    ),
    RoleDestination.schoolRequests => BlocProvider(
      create: (_) => getIt<SchoolRequestsCubit>()..start(),
      child: const SchoolRequestsPage(),
    ),
    RoleDestination.schoolAudit => BlocProvider(
      create: (_) => getIt<AuditLogCubit>()..load(schoolScope: true),
      child: const AuditLogPage(schoolOnly: true),
    ),
    RoleDestination.schoolReports => const ReportsPage(schoolOnly: true),
    RoleDestination.schoolProfile => BlocProvider(
      create: (_) => getIt<ProfileBloc>()..add(GetProfileEvent()),
      child: const ProfilePage(),
    ),
    _ => throw StateError('Маршрут не относится к администратору школы'),
  };
}
