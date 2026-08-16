import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';
import 'package:mobile_template/features/auth/presentation/pages/login/bloc/login_bloc.dart';
import 'package:mobile_template/features/auth/presentation/pages/login/login_page.dart';
import 'package:mobile_template/features/auth/presentation/pages/splash/bloc/session_bootstrap_cubit.dart';
import 'package:mobile_template/features/auth/presentation/pages/splash_page.dart';
import 'package:mobile_template/features/auth/presentation/pages/unsupported_role_page.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_request/teacher_request_cubit.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_request/teacher_request_page.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/guard_queue/guard_queue_cubit.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/guard_queue/guard_queue_page.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_requests/teacher_requests_page.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_requests/teacher_requests_shell.dart';
import 'package:mobile_template/features/school_management/presentation/cubit/school_management_cubit.dart';
import 'package:mobile_template/features/school_management/presentation/cubit/school_admins_cubit.dart';
import 'package:mobile_template/features/school_management/presentation/pages/school_admins_page.dart';
import 'package:mobile_template/features/school_management/presentation/pages/school_management_page.dart';
import 'package:mobile_template/features/school_console/presentation/school_classes_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/school_classes_page.dart';
import 'package:mobile_template/features/school_console/presentation/school_students_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/school_students_page.dart';
import 'package:mobile_template/features/school_console/presentation/school_teachers_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/school_teachers_page.dart';
import 'package:mobile_template/features/school_console/presentation/school_guards_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/school_guards_page.dart';
import 'package:mobile_template/features/school_console/presentation/school_requests_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/school_requests_page.dart';
import 'package:mobile_template/features/school_console/presentation/teacher_students_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/teacher_students_page.dart';
import 'package:mobile_template/features/profile/presentation/pages/bloc/profile_bloc.dart';
import 'package:mobile_template/features/profile/presentation/pages/profile_page.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const unsupportedRole = '/unsupported-role';
  static const teacherRequest = '/teacher/request';
  static const teacherActive = '/teacher/active';
  static const teacherHistory = '/teacher/history';
  static const teacherStudents = '/teacher/students';
  static const guardQueue = '/guard/queue';
  static const systemSchools = '/system/schools';
  static const systemSchoolAdmins = '/system/school-admins';
  static const schoolClasses = '/school/classes';
  static const schoolStudents = '/school/students';
  static const schoolTeachers = '/school/teachers';
  static const schoolGuards = '/school/guards';
  static const schoolRequests = '/school/requests';
  static const teacherProfile = '/teacher/profile';
  static const guardProfile = '/guard/profile';
  static const systemProfile = '/system/profile';
  static const schoolProfile = '/school/profile';

  // Kept only so deferred template profile code continues to compile.
  static const editProfile = '/profile/edit';
}

GoRouter createAppRouter() {
  final sessionService = getIt<SessionService>();
  final navigatorKey = getIt<GlobalKey<NavigatorState>>(
    instanceName: 'navigatorKey',
  );

  return GoRouter(
    navigatorKey: navigatorKey,
    refreshListenable: sessionService,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final sessionStatus = sessionService.status;

      if (sessionStatus == SessionStatus.bootstrapping ||
          sessionStatus == SessionStatus.temporarilyUnavailable) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (sessionStatus == SessionStatus.unauthenticated) {
        return location == AppRoutes.login ? null : AppRoutes.login;
      }

      final user = sessionService.currentUser;
      if (user == null) return AppRoutes.splash;

      return switch (user.role) {
        UserRole.teacher =>
          location.startsWith('/teacher/') ? null : AppRoutes.teacherRequest,
        UserRole.guard =>
          location.startsWith('/guard/') ? null : AppRoutes.guardQueue,
        UserRole.superAdmin =>
          location.startsWith('/system/') ? null : AppRoutes.systemSchools,
        UserRole.schoolAdmin =>
          location.startsWith('/school/') ? null : AppRoutes.schoolClasses,
      };
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<SessionBootstrapCubit>(),
          child: const SplashPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<LoginBloc>(),
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.unsupportedRole,
        builder: (context, state) => const UnsupportedRolePage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            TeacherRequestsShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherRequest,
                builder: (context, state) => BlocProvider(
                  create: (_) => getIt<TeacherRequestCubit>()..loadClasses(),
                  child: const TeacherRequestPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherActive,
                builder: (context, state) => const TeacherActiveRequestsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherHistory,
                builder: (context, state) => const TeacherRequestHistoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherStudents,
                builder: (context, state) => BlocProvider(
                  create: (_) => getIt<TeacherStudentsCubit>()..load(),
                  child: const TeacherStudentsPage(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.guardQueue,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<GuardQueueCubit>()..loadQueue(),
          child: const GuardQueuePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherProfile,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<ProfileBloc>()..add(GetProfileEvent()),
          child: const ProfilePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.guardProfile,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<ProfileBloc>()..add(GetProfileEvent()),
          child: const ProfilePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.systemProfile,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<ProfileBloc>()..add(GetProfileEvent()),
          child: const ProfilePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.schoolProfile,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<ProfileBloc>()..add(GetProfileEvent()),
          child: const ProfilePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.systemSchools,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<SchoolManagementCubit>()..load(),
          child: const SchoolManagementPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.systemSchoolAdmins,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<SchoolAdminsCubit>()..load(),
          child: const SchoolAdminsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.schoolClasses,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<SchoolClassesCubit>()..load(),
          child: const SchoolClassesPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.schoolStudents,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<SchoolStudentsCubit>()..load(),
          child: const SchoolStudentsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.schoolTeachers,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<SchoolTeachersCubit>()..load(),
          child: const SchoolTeachersPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.schoolGuards,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<SchoolGuardsCubit>()..load(),
          child: const SchoolGuardsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.schoolRequests,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<SchoolRequestsCubit>()..start(),
          child: const SchoolRequestsPage(),
        ),
      ),
    ],
  );
}
