import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mobile_template/app/theme/app_colors.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/features/audit/domain/audit_log_entry.dart';
import 'package:mobile_template/features/audit/presentation/audit_log_cubit.dart';
import 'package:mobile_template/features/shell/presentation/widgets/admin_app_bar.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({required this.schoolOnly, super.key});
  final bool schoolOnly;
  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final search = TextEditingController();
  String method = '';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AuditLogCubit, AuditLogState>(
    builder: (context, state) => Scaffold(
      appBar: widget.schoolOnly
          ? const AdminAppBar.school(sectionTitle: 'Журнал аудита')
          : const AdminAppBar.system(sectionTitle: 'Журнал аудита'),
      body: RefreshIndicator(
        onRefresh: () => context.read<AuditLogCubit>().load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(AppDimensions.getResponsivePadding(context)),
          children: [
            Text(
              'История действий',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Записей: ${state.total}. Пароли и содержимое форм в журнал не попадают.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: 'Поиск по пользователю или пути',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onSubmitted: (value) => context.read<AuditLogCubit>().load(
                      page: 1,
                      query: value,
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Действие'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Все')),
                      DropdownMenuItem(value: 'POST', child: Text('Создание')),
                      DropdownMenuItem(
                        value: 'PATCH',
                        child: Text('Изменение'),
                      ),
                      DropdownMenuItem(
                        value: 'DELETE',
                        child: Text('Удаление'),
                      ),
                    ],
                    onChanged: (value) {
                      method = value ?? '';
                      context.read<AuditLogCubit>().load(
                        page: 1,
                        methodFilter: method,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (state.loading && state.items.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (state.failure != null && state.items.isEmpty)
              Center(child: Text(state.failure!.message))
            else if (state.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: Text('Записей не найдено')),
              )
            else
              ...state.items.map((item) => _AuditCard(item: item)),
            if (state.total > 25)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: state.page <= 1
                        ? null
                        : () => context.read<AuditLogCubit>().load(
                            page: state.page - 1,
                          ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text(
                    'Страница ${state.page} из ${(state.total / 25).ceil()}',
                  ),
                  IconButton(
                    onPressed: state.page * 25 >= state.total
                        ? null
                        : () => context.read<AuditLogCubit>().load(
                            page: state.page + 1,
                          ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.item});
  final AuditLogEntry item;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassSurfaceCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: item.statusCode < 400
                ? AppColors.primaryDark
                : AppColors.error,
            child: Icon(_icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_verb · ${item.actorName}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(item.path, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(
                  '${item.schoolName ?? 'Вся система'} · HTTP ${item.statusCode} · ${DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  String get _verb => switch (item.method) {
    'POST' => 'Создание',
    'PATCH' || 'PUT' => 'Изменение',
    'DELETE' => 'Удаление',
    _ => item.method,
  };
  IconData get _icon => switch (item.method) {
    'POST' => Icons.add_rounded,
    'DELETE' => Icons.delete_outline_rounded,
    _ => Icons.edit_outlined,
  };
}
