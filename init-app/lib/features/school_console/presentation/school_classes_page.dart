import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_colors.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_class.dart';
import 'package:mobile_template/features/school_console/presentation/school_classes_cubit.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
import 'package:mobile_template/presentation/widgets/common/confirmation_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/common/global_text_form_field.dart';

class SchoolClassesPage extends StatelessWidget {
  const SchoolClassesPage({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<SchoolClassesCubit, SchoolClassesState>(
    listenWhen: (a, b) => a.revision != b.revision,
    listener: (context, state) {
      if (state.feedback != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.feedback!)));
      }
    },
    builder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Управление школой'),
            Text(
              'Классы',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Журнал аудита',
            onPressed: () => context.go(AppRoutes.schoolAudit),
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'Отчёты',
            onPressed: () => context.go(AppRoutes.schoolReports),
            icon: const Icon(Icons.analytics_outlined),
          ),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.schoolRequests),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Заявки'),
          ),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.schoolGuards),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Охрана'),
          ),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.schoolTeachers),
            icon: const Icon(Icons.co_present_outlined),
            label: const Text('Учителя'),
          ),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.schoolStudents),
            icon: const Icon(Icons.people_alt_outlined),
            label: const Text('Ученики'),
          ),
          const SessionUserMenuButton(showName: true),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить класс'),
      ),
      body: RefreshIndicator(
        onRefresh: context.read<SchoolClassesCubit>().load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppDimensions.getResponsivePadding(context),
            24,
            AppDimensions.getResponsivePadding(context),
            104,
          ),
          children: [
            Text(
              'Классы школы',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Создавайте классы и управляйте их доступностью для учителей.',
            ),
            const SizedBox(height: 24),
            if (state.status == ManagedClassesStatus.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.status == ManagedClassesStatus.failure)
              Center(
                child: TextButton.icon(
                  onPressed: context.read<SchoolClassesCubit>().load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить загрузку'),
                ),
              )
            else if (state.classes.isEmpty)
              const GlassSurfaceCard(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.school_outlined, size: 56),
                    SizedBox(height: 12),
                    Text('Классов пока нет'),
                  ],
                ),
              )
            else
              ...state.classes.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ClassItem(
                    item: item,
                    busy: state.busyIds.contains(item.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  Future<void> _form(BuildContext context, [ManagedSchoolClass? item]) =>
      showDialog<void>(
        context: context,
        builder: (_) => BlocProvider.value(
          value: context.read<SchoolClassesCubit>(),
          child: _ClassForm(item: item),
        ),
      );
}

class _ClassItem extends StatelessWidget {
  const _ClassItem({required this.item, required this.busy});
  final ManagedSchoolClass item;
  final bool busy;
  @override
  Widget build(BuildContext context) => GlassSurfaceCard(
    padding: const EdgeInsets.all(18),
    child: AppLayoutItemBuilder<Widget>(
      narrow: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context),
          const SizedBox(height: 12),
          _actions(context),
        ],
      ),
      wide: () => Row(
        children: [
          Expanded(child: _title(context)),
          _actions(context),
        ],
      ),
    )(context),
  );
  Widget _title(BuildContext context) => Row(
    children: [
      GlassIconBadge(child: const Icon(Icons.class_rounded)),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              item.isActive ? 'Доступен' : 'Отключён',
              style: TextStyle(
                color: item.isActive ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _actions(BuildContext context) => busy
      ? const SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Изменить',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: context.read<SchoolClassesCubit>(),
                  child: _ClassForm(item: item),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: item.isActive ? 'Отключить' : 'Включить',
              onPressed: () => context.read<SchoolClassesCubit>().toggle(item),
              icon: Icon(
                item.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
            ),
            IconButton(
              tooltip: 'Удалить полностью',
              color: AppColors.error,
              onPressed: () async {
                final ok = await ConfirmationDialog.show(
                  context,
                  title: 'Удалить класс?',
                  content:
                      'Класс «${item.name}», его ученики, назначения учителей и заявки будут удалены.',
                  confirmText: 'Удалить полностью',
                );
                if (ok == true && context.mounted) {
                  await context.read<SchoolClassesCubit>().delete(item);
                }
              },
              icon: const Icon(Icons.delete_forever_outlined),
            ),
          ],
        );
}

class _ClassForm extends StatefulWidget {
  const _ClassForm({this.item});
  final ManagedSchoolClass? item;
  @override
  State<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<_ClassForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.item?.name);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.item == null ? 'Новый класс' : 'Изменить класс',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              GlobalTextFormField(
                controller: controller,
                labelText: 'Название класса',
                hintText: 'Например, 5А',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите название'
                    : null,
              ),
              const SizedBox(height: 20),
              BlocBuilder<SchoolClassesCubit, SchoolClassesState>(
                builder: (context, state) => GlobalButton(
                  text: 'Сохранить',
                  isLoading: state.isSaving,
                  onPressed: _save,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> _save() async {
    if (!key.currentState!.validate()) return;
    final saved = await context.read<SchoolClassesCubit>().save(
      id: widget.item?.id,
      name: controller.text.trim(),
    );
    if (saved && mounted) Navigator.pop(context);
  }
}
