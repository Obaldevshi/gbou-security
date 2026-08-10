import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_requests/teacher_requests_cubit.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_requests/teacher_requests_state.dart';
import 'package:mobile_template/features/exit_requests/presentation/widgets/teacher_request_card.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/layout/scroll_shell.dart';

enum TeacherRequestsView { active, history }

class TeacherActiveRequestsPage extends StatelessWidget {
  const TeacherActiveRequestsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const TeacherRequestsPage(view: TeacherRequestsView.active);
}

class TeacherRequestHistoryPage extends StatelessWidget {
  const TeacherRequestHistoryPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const TeacherRequestsPage(view: TeacherRequestsView.history);
}

class TeacherRequestsPage extends StatelessWidget {
  const TeacherRequestsPage({required this.view, super.key});

  final TeacherRequestsView view;

  @override
  Widget build(BuildContext context) {
    final activeView = view == TeacherRequestsView.active;
    final actions = AppLayoutItemBuilder<List<Widget>>.values(
      narrow: const [SessionUserMenuButton()],
      wide: const [],
    )(context);
    return ScrollShell(
      title: activeView
          ? context.l10n.activeRequests
          : context.l10n.requestHistory,
      headerContent: Text(
        activeView
            ? context.l10n.teacherActiveDescription
            : context.l10n.teacherHistoryDescription,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Colors.white),
      ),
      actions: actions,
      body: BlocBuilder<TeacherRequestsCubit, TeacherRequestsState>(
        builder: (context, state) => _RequestsBody(view: view, state: state),
      ),
    );
  }
}

class _RequestsBody extends StatelessWidget {
  const _RequestsBody({required this.view, required this.state});

  final TeacherRequestsView view;
  final TeacherRequestsState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == TeacherRequestsStatus.initial ||
        state.status == TeacherRequestsStatus.loading) {
      return const _LoadingCards();
    }
    if (state.status == TeacherRequestsStatus.failure) {
      return _ErrorCard(
        onRetry: () => context.read<TeacherRequestsCubit>().load(),
      );
    }

    final requests = view == TeacherRequestsView.active
        ? state.active
        : state.history;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isRefreshing) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: AppDimensions.spaceS),
        ],
        if (requests.isEmpty)
          _EmptyCard(view: view)
        else
          _RequestCards(requests: requests),
      ],
    );
  }
}

class _RequestCards extends StatelessWidget {
  const _RequestCards({required this.requests});

  final List<ExitRequest> requests;

  @override
  Widget build(BuildContext context) {
    final isWide = AppLayoutItemBuilder<bool>.values(narrow: false, wide: true)(
      context,
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: isWide
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth =
                      (constraints.maxWidth - AppDimensions.spaceM) / 2;
                  return Wrap(
                    spacing: AppDimensions.spaceM,
                    runSpacing: AppDimensions.spaceM,
                    children: [
                      for (final request in requests)
                        SizedBox(
                          width: cardWidth,
                          child: TeacherRequestCard(
                            key: ValueKey(request.id),
                            request: request,
                          ),
                        ),
                    ],
                  );
                },
              )
            : Column(
                children: [
                  for (var index = 0; index < requests.length; index++) ...[
                    TeacherRequestCard(
                      key: ValueKey(requests[index].id),
                      request: requests[index],
                    ),
                    if (index != requests.length - 1)
                      const SizedBox(height: AppDimensions.spaceM),
                  ],
                ],
              ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.view});

  final TeacherRequestsView view;

  @override
  Widget build(BuildContext context) {
    final active = view == TeacherRequestsView.active;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimensions.feedMaxWidth),
        child: GlassSurfaceCard(
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                Icon(
                  active ? Icons.schedule_rounded : Icons.history_rounded,
                  size: AppDimensions.iconXL,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppDimensions.spaceM),
                Text(
                  active
                      ? context.l10n.noActiveRequests
                      : context.l10n.noRequestHistory,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spaceL),
                FilledButton.icon(
                  onPressed: () => context.go(
                    active ? '/teacher/request' : '/teacher/active',
                  ),
                  icon: Icon(
                    active ? Icons.add_rounded : Icons.schedule_rounded,
                  ),
                  label: Text(
                    active
                        ? context.l10n.createRequestAction
                        : context.l10n.openActiveRequests,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => GlassSurfaceCard(
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: AppDimensions.iconXL,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppDimensions.spaceM),
          Text(
            context.l10n.teacherRequestsLoadFailed,
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

class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) => Column(
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
