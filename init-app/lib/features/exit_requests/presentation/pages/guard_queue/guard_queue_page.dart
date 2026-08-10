import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
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
  static const _pollInterval = Duration(seconds: 5);
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        context.read<GuardQueueCubit>().loadQueue(background: true);
        _startPolling();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => context.read<GuardQueueCubit>().loadQueue(background: true),
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
          final body = _GuardQueueBody(state: state);
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
  const _GuardQueueBody({required this.state});

  final GuardQueueState state;

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
    if (state.requests.isEmpty) {
      return RolePlaceholderCard(
        icon: Icons.verified_user_outlined,
        title: context.l10n.noExitRequests,
        description: context.l10n.guardQueueAutoRefresh,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isRefreshing) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: AppDimensions.spaceS),
        ],
        for (final request in state.requests) ...[
          GuardRequestCard(
            key: ValueKey(request.id),
            request: request,
            isReleasing: state.releasingIds.contains(request.id),
            onRelease: () =>
                context.read<GuardQueueCubit>().release(request.id),
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
