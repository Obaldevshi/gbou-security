import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_requests/teacher_requests_cubit.dart';
import 'package:mobile_template/features/exit_requests/data/request_events_service.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_requests/teacher_requests_state.dart';
import 'package:mobile_template/features/shell/presentation/pages/main_navigation.dart';

class TeacherRequestsShell extends StatefulWidget {
  const TeacherRequestsShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<TeacherRequestsShell> createState() => _TeacherRequestsShellState();
}

class _TeacherRequestsShellState extends State<TeacherRequestsShell>
    with WidgetsBindingObserver {
  late final TeacherRequestsCubit _cubit;
  StreamSubscription<void>? _events;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<TeacherRequestsCubit>()..load();
    WidgetsBinding.instance.addObserver(this);
    _startEvents();
  }

  @override
  void dispose() {
    _events?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _cubit.load(background: true);
        _startEvents();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _events?.cancel();
    }
  }

  void _startEvents() {
    _events?.cancel();
    _events = getIt<RequestEventsService>().watch().listen(
      (_) => _cubit.load(background: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocListener<TeacherRequestsCubit, TeacherRequestsState>(
        listenWhen: (previous, current) =>
            previous.feedbackRevision != current.feedbackRevision,
        listener: (context, state) {
          final message = switch (state.feedbackCode) {
            'request_released' => context.l10n.teacherRequestReleasedNotice,
            'refresh_failed' => context.l10n.teacherRequestsRefreshFailed,
            'request_cancelled' => 'Заявка отменена',
            'cancel_failed' =>
              state.failure?.message ?? 'Не удалось отменить заявку',
            _ => null,
          };
          if (message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
        },
        child: MainNavigation(navigationShell: widget.navigationShell),
      ),
    );
  }
}
