import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
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

class _RequestList extends StatefulWidget {
  const _RequestList({
    required this.items,
    required this.empty,
    this.allowCancel = false,
  });

  final List<ExitRequest> items;
  final String empty;
  final bool allowCancel;

  @override
  State<_RequestList> createState() => _RequestListState();
}

class _RequestListState extends State<_RequestList> {
  static const pageSize = 10;
  final search = TextEditingController();
  String status = 'all';
  String period = 'all';
  bool newestFirst = true;
  int page = 0;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final now = DateTime.now();
    final filtered =
        widget.items.where((item) {
          final haystack =
              '${item.studentFullName} ${item.className} '
                      '${item.teacherFullName} ${item.customReason ?? ''}'
                  .toLowerCase();
          final matchesStatus =
              status == 'all' || item.status.wireName == status;
          final days = period == '7'
              ? 7
              : period == '30'
              ? 30
              : null;
          final matchesPeriod =
              days == null ||
              item.createdAt.isAfter(now.subtract(Duration(days: days)));
          return matchesStatus &&
              matchesPeriod &&
              (query.isEmpty || haystack.contains(query));
        }).toList()..sort(
          (a, b) => newestFirst
              ? b.createdAt.compareTo(a.createdAt)
              : a.createdAt.compareTo(b.createdAt),
        );
    final pageCount = math.max(1, (filtered.length / pageSize).ceil());
    if (page >= pageCount) page = pageCount - 1;
    final visible = filtered.skip(page * pageSize).take(pageSize).toList();

    return RefreshIndicator(
      onRefresh: () => context.read<SchoolRequestsCubit>().load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppDimensions.getResponsivePadding(context)),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() => page = 0),
                  decoration: const InputDecoration(
                    labelText: 'Поиск по ученику, классу или учителю',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Статус'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Все статусы')),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('Ожидает выхода'),
                    ),
                    DropdownMenuItem(
                      value: 'released',
                      child: Text('Отпустил'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Отменена'),
                    ),
                    DropdownMenuItem(
                      value: 'expired',
                      child: Text('Просрочена'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    status = value ?? 'all';
                    page = 0;
                  }),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: period,
                  decoration: const InputDecoration(labelText: 'Период'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('За всё время')),
                    DropdownMenuItem(
                      value: '7',
                      child: Text('Последние 7 дней'),
                    ),
                    DropdownMenuItem(
                      value: '30',
                      child: Text('Последние 30 дней'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    period = value ?? 'all';
                    page = 0;
                  }),
                ),
              ),
              IconButton.outlined(
                tooltip: newestFirst ? 'Сначала новые' : 'Сначала старые',
                onPressed: () => setState(() => newestFirst = !newestFirst),
                icon: Icon(
                  newestFirst
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Text(
                  widget.items.isEmpty ? widget.empty : 'Ничего не найдено',
                ),
              ),
            )
          else
            ...visible.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TeacherRequestCard(
                      request: item,
                      onCancel: widget.allowCancel
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
          if (filtered.length > pageSize)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: page == 0 ? null : () => setState(() => page--),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('Страница ${page + 1} из $pageCount'),
                IconButton(
                  onPressed: page + 1 >= pageCount
                      ? null
                      : () => setState(() => page++),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
