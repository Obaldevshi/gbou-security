import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/role_loading/role_destination.dart';
import 'package:mobile_template/app/role_loading/roles/exit_request_dependencies.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_guard_queue_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/release_exit_request_usecase.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/guard_queue/guard_queue_cubit.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/guard_queue/guard_queue_page.dart';
import 'package:mobile_template/features/profile/presentation/pages/bloc/profile_bloc.dart';
import 'package:mobile_template/features/profile/presentation/pages/profile_page.dart';

void _ensureDependencies() {
  ensureExitRequestDependencies();
  if (!getIt.isRegistered<GuardQueueCubit>()) {
    getIt.registerFactory<GuardQueueCubit>(() {
      final repository = getIt<ExitRequestRepository>();
      return GuardQueueCubit(
        GetGuardQueueUsecase(repository),
        ReleaseExitRequestUsecase(repository),
      );
    });
  }
}

Widget buildGuardDestination(RoleDestination destination) {
  _ensureDependencies();
  return switch (destination) {
    RoleDestination.guardQueue => BlocProvider(
      create: (_) => getIt<GuardQueueCubit>()..loadQueue(),
      child: const GuardQueuePage(),
    ),
    RoleDestination.guardProfile => BlocProvider(
      create: (_) => getIt<ProfileBloc>()..add(GetProfileEvent()),
      child: const ProfilePage(),
    ),
    _ => throw StateError('Маршрут не относится к кабинету охраны'),
  };
}
