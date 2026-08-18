import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/features/exit_requests/data/request_events_service.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/guard_queue/guard_queue_cubit.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/guard_queue/guard_queue_state.dart';
import 'package:mobile_template/features/exit_requests/presentation/widgets/guard_request_card.dart';
import 'package:mobile_template/features/shell/presentation/widgets/role_placeholder_card.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/layout/scroll_shell.dart';

class GuardQueuePage extends StatefulWidget {
  const GuardQueuePage({super.key});

  @override
  State<GuardQueuePage> createState() => _GuardQueuePageState();
}

class _GuardQueuePageState extends State<GuardQueuePage>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _events;
  Timer? _pollTimer;
  final _search = TextEditingController();
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startEvents();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => context.read<GuardQueueCubit>().loadQueue(background: true),
    );
  }

  @override
  void dispose() {
    _events?.cancel();
    _pollTimer?.cancel();
    _search.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        context.read<GuardQueueCubit>().loadQueue(background: true);
        _startEvents();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _events?.cancel();
    }
  }

  void _startEvents() {
    final cubit = context.read<GuardQueueCubit>();
    unawaited(_events?.cancel());
    _events = getIt<RequestEventsService>().watch().listen(
      (_) => cubit.loadQueue(background: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showUserName = AppLayoutItemBuilder<bool>.values(
      narrow: false,
      wide: true,
    )(context);
    return ScrollShell(
      title: context.l10n.guardQueue,
      headerContent: Text(
        context.l10n.guardQueueDescription,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Colors.white),
      ),
      actions: [SessionUserMenuButton(showName: showUserName)],
      body: BlocConsumer<GuardQueueCubit, GuardQueueState>(
        listenWhen: (previous, current) =>
            previous.feedbackRevision != current.feedbackRevision,
        listener: (context, state) {
          final message = _feedbackMessage(context, state.feedbackCode);
          if (message == null) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) {
          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Фильтр по ученику, классу или учителю',
                        prefixIcon: Icon(Icons.filter_alt_outlined),
                      ),
                    ),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Ожидают выхода'),
                        icon: Icon(Icons.schedule_rounded),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('История'),
                        icon: Icon(Icons.history_rounded),
                      ),
                    ],
                    selected: {_showHistory},
                    onSelectionChanged: (value) =>
                        setState(() => _showHistory = value.first),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceL),
              _GuardQueueBody(
                state: state,
                showHistory: _showHistory,
                query: _search.text,
              ),
            ],
          );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: body,
            ),
          );
        },
      ),
    );
  }
}

class _GuardQueueBody extends StatelessWidget {
  const _GuardQueueBody({
    required this.state,
    required this.showHistory,
    required this.query,
  });

  final GuardQueueState state;
  final bool showHistory;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (state.status == GuardQueueStatus.initial ||
        state.status == GuardQueueStatus.loading) {
      return const _QueueLoading();
    }
    if (state.status == GuardQueueStatus.failure && state.requests.isEmpty) {
      return _QueueError(
        onRetry: () => context.read<GuardQueueCubit>().loadQueue(),
      );
    }
    final normalized = query.trim().toLowerCase();
    final source = showHistory ? state.history : state.requests;
    final requests = source.where((request) {
      if (normalized.isEmpty) return true;
      return '${request.studentFullName} ${request.className} ${request.teacherFullName}'
          .toLowerCase()
          .contains(normalized);
    }).toList();
    if (requests.isEmpty) {
      return RolePlaceholderCard(
        icon: showHistory
            ? Icons.history_rounded
            : Icons.verified_user_outlined,
        title: showHistory ? 'История пока пуста' : context.l10n.noExitRequests,
        description: normalized.isEmpty
            ? context.l10n.guardQueueAutoRefresh
            : 'По заданному фильтру ничего не найдено',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final request in requests) ...[
          GuardRequestCard(
            key: ValueKey(request.id),
            request: request,
            isReleasing: state.releasingIds.contains(request.id),
            onRelease: () =>
                context.read<GuardQueueCubit>().release(request.id),
            readOnly: showHistory,
          ),
          const SizedBox(height: AppDimensions.spaceM),
        ],
      ],
    );
  }
}

class _QueueLoading extends StatelessWidget {
  const _QueueLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < 3; index++) ...[
          GlassSurfaceCard(
            child: SizedBox(
              height: 128,
              child: Center(
                child: index == 0
                    ? const CircularProgressIndicator()
                    : Icon(
                        Icons.hourglass_empty_rounded,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceM),
        ],
      ],
    );
  }
}

class _QueueError extends StatelessWidget {
  const _QueueError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassSurfaceCard(
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppDimensions.spaceM),
            Text(
              context.l10n.guardQueueLoadFailed,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceM),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

String? _feedbackMessage(BuildContext context, String? code) => switch (code) {
  'release_success' => context.l10n.guardReleaseSuccess,
  'request_already_processed' => context.l10n.guardAlreadyProcessed,
  'request_not_available' => context.l10n.guardRequestUnavailable,
  'release_failed' => context.l10n.guardReleaseFailed,
  'queue_refresh_failed' => context.l10n.guardQueueRefreshFailed,
  _ => null,
};
