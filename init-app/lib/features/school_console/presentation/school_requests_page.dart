import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_router.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/presentation/widgets/teacher_request_card.dart';
import 'package:mobile_template/features/school_console/presentation/school_requests_cubit.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';

class SchoolRequestsPage extends StatelessWidget {
  const SchoolRequestsPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Заявки школы'),
        leading: IconButton(
          tooltip: 'Классы',
          onPressed: () => context.go(AppRoutes.schoolClasses),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: const [SessionUserMenuButton(showName: true)],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Активные'),
            Tab(text: 'История'),
          ],
        ),
      ),
      body: BlocConsumer<SchoolRequestsCubit, SchoolRequestsState>(
        listenWhen: (previous, current) =>
            previous.feedbackRevision != current.feedbackRevision,
        listener: (context, state) {
          if (state.feedback != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.feedback!)));
          }
        },
        builder: (context, state) {
          if (state.status == SchoolRequestsStatus.loading &&
              state.active.isEmpty &&
              state.history.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == SchoolRequestsStatus.failure &&
              state.active.isEmpty &&
              state.history.isEmpty) {
            return Center(
              child: TextButton.icon(
                onPressed: () => context.read<SchoolRequestsCubit>().load(),
                icon: const Icon(Icons.refresh),
                label: Text(state.failure?.message ?? 'Повторить'),
              ),
            );
          }
          return TabBarView(
            children: [
              _RequestList(
                items: state.active,
                empty: 'Активных заявок нет',
                allowCancel: true,
              ),
              _RequestList(items: state.history, empty: 'История заявок пуста'),
            ],
          );
        },
      ),
    ),
  );
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.items,
    required this.empty,
    this.allowCancel = false,
  });

  final List<ExitRequest> items;
  final String empty;
  final bool allowCancel;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => context.read<SchoolRequestsCubit>().load(),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(AppDimensions.getResponsivePadding(context)),
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(48),
            child: Center(child: Text(empty)),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TeacherRequestCard(
                    request: item,
                    onCancel: allowCancel
                        ? () => context.read<SchoolRequestsCubit>().cancel(
                            item.id,
                          )
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text(
                      'Учитель: ${item.teacherFullName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
