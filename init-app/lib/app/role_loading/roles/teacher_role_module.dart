import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/role_loading/role_destination.dart';
import 'package:mobile_template/app/role_loading/roles/exit_request_dependencies.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/cancel_teacher_exit_request_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/create_exit_request_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_class_students_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_teacher_classes_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_teacher_exit_requests_usecase.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_request/teacher_request_cubit.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_request/teacher_request_page.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_requests/teacher_requests_cubit.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_requests/teacher_requests_page.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_requests/teacher_requests_shell.dart';
import 'package:mobile_template/features/profile/presentation/pages/bloc/profile_bloc.dart';
import 'package:mobile_template/features/profile/presentation/pages/profile_page.dart';
import 'package:mobile_template/features/school_console/data/teacher_students_data.dart';
import 'package:mobile_template/features/school_console/domain/repositories/teacher_students_repository.dart';
import 'package:mobile_template/features/school_console/domain/usecases/teacher_student_usecases.dart';
import 'package:mobile_template/features/school_console/presentation/teacher_students_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/teacher_students_page.dart';

void _ensureDependencies() {
  ensureExitRequestDependencies();
  final exitRepository = getIt<ExitRequestRepository>();
  if (!getIt.isRegistered<TeacherStudentsRepository>()) {
    getIt.registerLazySingleton<TeacherStudentsRepository>(() {
      final api = TeacherStudentsApiDataSource(
        getIt<Dio>(),
        getIt<String>(instanceName: 'baseUrl'),
      );
      return TeacherStudentsRepositoryImpl(api);
    });
  }
  if (!getIt.isRegistered<TeacherRequestCubit>()) {
    getIt.registerFactory<TeacherRequestCubit>(
      () => TeacherRequestCubit(
        GetTeacherClassesUsecase(exitRepository),
        GetClassStudentsUsecase(exitRepository),
        CreateExitRequestUsecase(exitRepository),
      ),
    );
  }
  if (!getIt.isRegistered<TeacherRequestsCubit>()) {
    getIt.registerFactory<TeacherRequestsCubit>(
      () => TeacherRequestsCubit(
        GetTeacherExitRequestsUsecase(exitRepository),
        CancelTeacherExitRequestUsecase(exitRepository),
      ),
    );
  }
  if (!getIt.isRegistered<TeacherStudentsCubit>()) {
    getIt.registerFactory<TeacherStudentsCubit>(() {
      final repository = getIt<TeacherStudentsRepository>();
      return TeacherStudentsCubit(
        GetTeacherClassesUsecase(exitRepository),
        GetTeacherStudentsUsecase(repository),
        CreateTeacherStudentUsecase(repository),
        SetTeacherStudentStatusUsecase(repository),
        DeleteTeacherStudentUsecase(repository),
      );
    });
  }
}

Widget buildTeacherDestination(
  RoleDestination destination, {
  StatefulNavigationShell? navigationShell,
}) {
  _ensureDependencies();
  return switch (destination) {
    RoleDestination.teacherShell => TeacherRequestsShell(
      navigationShell: navigationShell!,
    ),
    RoleDestination.teacherRequest => BlocProvider(
      create: (_) => getIt<TeacherRequestCubit>()..loadClasses(),
      child: const TeacherRequestPage(),
    ),
    RoleDestination.teacherActive => const TeacherActiveRequestsPage(),
    RoleDestination.teacherHistory => const TeacherRequestHistoryPage(),
    RoleDestination.teacherStudents => BlocProvider(
      create: (_) => getIt<TeacherStudentsCubit>()..load(),
      child: const TeacherStudentsPage(),
    ),
    RoleDestination.teacherProfile => BlocProvider(
      create: (_) => getIt<ProfileBloc>()..add(GetProfileEvent()),
      child: const ProfilePage(),
    ),
    _ => throw StateError('Маршрут не относится к кабинету учителя'),
  };
}
