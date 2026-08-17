import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/app/role_loading/deferred_role_page.dart';
import 'package:mobile_template/app/role_loading/role_destination.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';
import 'package:mobile_template/features/auth/presentation/pages/login/bloc/login_bloc.dart';
import 'package:mobile_template/features/auth/presentation/pages/login/login_page.dart';
import 'package:mobile_template/features/auth/presentation/pages/splash/bloc/session_bootstrap_cubit.dart';
import 'package:mobile_template/features/auth/presentation/pages/splash_page.dart';
import 'package:mobile_template/features/auth/presentation/pages/unsupported_role_page.dart';
import 'package:mobile_template/features/profile/presentation/pages/bloc/profile_bloc.dart';
import 'package:mobile_template/features/profile/presentation/pages/required_password_change_page.dart';

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

      if (user.mustChangePassword) {
        return location == AppRoutes.requiredPasswordChange
            ? null
            : AppRoutes.requiredPasswordChange;
      }

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
        path: AppRoutes.requiredPasswordChange,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<ProfileBloc>(),
          child: const RequiredPasswordChangePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.unsupportedRole,
        builder: (context, state) => const UnsupportedRolePage(),
      ),
      GoRoute(
        path: AppRoutes.systemAudit,
        builder: (context, state) => const DeferredRolePage(
          role: UserRole.superAdmin,
          destination: RoleDestination.systemAudit,
        ),
      ),
      GoRoute(
        path: AppRoutes.schoolAudit,
        builder: (context, state) => const DeferredRolePage(
          role: UserRole.schoolAdmin,
          destination: RoleDestination.schoolAudit,
        ),
      ),
      GoRoute(
        path: AppRoutes.systemReports,
        builder: (context, state) => const DeferredRolePage(
          role: UserRole.superAdmin,
          destination: RoleDestination.systemReports,
        ),
      ),
      GoRoute(
        path: AppRoutes.schoolReports,
        builder: (context, state) => const DeferredRolePage(
          role: UserRole.schoolAdmin,
          destination: RoleDestination.schoolReports,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => DeferredRolePage(
          role: UserRole.teacher,
          destination: RoleDestination.teacherShell,
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherRequest,
                builder: (context, state) => const DeferredRolePage(
                  role: UserRole.teacher,
                  destination: RoleDestination.teacherRequest,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherActive,
                builder: (context, state) => const DeferredRolePage(
                  role: UserRole.teacher,
                  destination: RoleDestination.teacherActive,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherHistory,
                builder: (context, state) => const DeferredRolePage(
                  role: UserRole.teacher,
                  destination: RoleDestination.teacherHistory,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherStudents,
                builder: (context, state) => const DeferredRolePage(
                  role: UserRole.teacher,
                  destination: RoleDestination.teacherStudents,
                ),
              ),
            ],
          ),
        ],
      ),
      _roleRoute(
        AppRoutes.guardQueue,
        UserRole.guard,
        RoleDestination.guardQueue,
      ),
      _roleRoute(
        AppRoutes.teacherProfile,
        UserRole.teacher,
        RoleDestination.teacherProfile,
      ),
      _roleRoute(
        AppRoutes.guardProfile,
        UserRole.guard,
        RoleDestination.guardProfile,
      ),
      _roleRoute(
        AppRoutes.systemProfile,
        UserRole.superAdmin,
        RoleDestination.systemProfile,
      ),
      _roleRoute(
        AppRoutes.schoolProfile,
        UserRole.schoolAdmin,
        RoleDestination.schoolProfile,
      ),
      _roleRoute(
        AppRoutes.systemSchools,
        UserRole.superAdmin,
        RoleDestination.systemSchools,
      ),
      _roleRoute(
        AppRoutes.systemSchoolAdmins,
        UserRole.superAdmin,
        RoleDestination.systemSchoolAdmins,
      ),
      _roleRoute(
        AppRoutes.schoolBuildings,
        UserRole.schoolAdmin,
        RoleDestination.schoolBuildings,
      ),
      _roleRoute(
        AppRoutes.schoolClasses,
        UserRole.schoolAdmin,
        RoleDestination.schoolClasses,
      ),
      _roleRoute(
        AppRoutes.schoolStudents,
        UserRole.schoolAdmin,
        RoleDestination.schoolStudents,
      ),
      _roleRoute(
        AppRoutes.schoolTeachers,
        UserRole.schoolAdmin,
        RoleDestination.schoolTeachers,
      ),
      _roleRoute(
        AppRoutes.schoolGuards,
        UserRole.schoolAdmin,
        RoleDestination.schoolGuards,
      ),
      _roleRoute(
        AppRoutes.schoolRequests,
        UserRole.schoolAdmin,
        RoleDestination.schoolRequests,
      ),
    ],
  );
}

GoRoute _roleRoute(String path, UserRole role, RoleDestination destination) =>
    GoRoute(
      path: path,
      builder: (context, state) =>
          DeferredRolePage(role: role, destination: destination),
    );
