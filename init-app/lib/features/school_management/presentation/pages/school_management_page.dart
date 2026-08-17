import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/app/theme/app_colors.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/features/school_management/domain/entities/school.dart';
import 'package:mobile_template/features/school_management/presentation/cubit/school_management_cubit.dart';
import 'package:mobile_template/features/school_management/presentation/cubit/school_management_state.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
import 'package:mobile_template/presentation/widgets/common/confirmation_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/common/global_text_form_field.dart';

class SchoolManagementPage extends StatelessWidget {
  const SchoolManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SchoolManagementCubit, SchoolManagementState>(
      listenWhen: (previous, current) =>
          previous.feedbackRevision != current.feedbackRevision,
      listener: (context, state) {
        final message = state.feedback;
        if (message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Центр управления'),
              Text(
                'Главный администратор',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.systemReports),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Отчёты'),
            ),
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.systemAudit),
              icon: const Icon(Icons.history_rounded),
              label: const Text('Аудит'),
            ),
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.systemSchoolAdmins),
              icon: const Icon(Icons.manage_accounts_rounded),
              label: const Text('Администраторы'),
            ),
            const SessionUserMenuButton(showName: true),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Добавить школу'),
        ),
        body: RefreshIndicator(
          onRefresh: context.read<SchoolManagementCubit>().load,
          child: _Body(state: state),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, [School? school]) =>
      showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => BlocProvider.value(
          value: context.read<SchoolManagementCubit>(),
          child: _SchoolFormDialog(school: school),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.state});
  final SchoolManagementState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == SchoolManagementStatus.loading &&
        state.schools.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == SchoolManagementStatus.failure &&
        state.schools.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * .25),
          const Icon(Icons.cloud_off_rounded, size: 56),
          const SizedBox(height: 16),
          const Center(child: Text('Не удалось загрузить список школ')),
          Center(
            child: TextButton.icon(
              onPressed: context.read<SchoolManagementCubit>().load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ),
        ],
      );
    }

    final horizontal = AppDimensions.getResponsivePadding(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 104),
      children: [
        Text(
          'Школы системы',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Создавайте школы, управляйте доступом и переходите к настройке сотрудников.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              label: 'Всего школ',
              value: state.stats?.schools ?? state.schools.length,
              icon: Icons.apartment_rounded,
            ),
            _MetricCard(
              label: 'Активные',
              value: state.stats?.activeSchools ?? state.activeCount,
              icon: Icons.verified_rounded,
              color: AppColors.success,
            ),
            _MetricCard(
              label: 'Администраторы',
              value: state.stats?.schoolAdmins ?? 0,
              icon: Icons.admin_panel_settings_rounded,
              color: AppColors.info,
            ),
            _MetricCard(
              label: 'Пользователи',
              value: state.stats?.users ?? 0,
              icon: Icons.groups_rounded,
            ),
          ],
        ),
        const SizedBox(height: 28),
        if (state.schools.isEmpty)
          const _EmptySchools()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 920 ? 2 : 1;
              final width = columns == 2
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: state.schools
                    .map(
                      (school) => SizedBox(
                        width: width,
                        child: _SchoolCard(
                          school: school,
                          busy: state.busyIds.contains(school.id),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: GlassSurfaceCard(
      child: Row(
        children: [
          GlassIconBadge(
            color: color,
            child: Icon(icon, color: color ?? AppColors.primary),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.school, required this.busy});
  final School school;
  final bool busy;

  @override
  Widget build(BuildContext context) => GlassSurfaceCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassIconBadge(
              child: Text(
                school.shortName.characters.first,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    school.shortName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    school.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'Действия со школой',
                onSelected: (value) => _onAction(context, value),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_rounded),
                      title: Text('Изменить'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: ListTile(
                      leading: Icon(
                        school.isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                      ),
                      title: Text(school.isActive ? 'Отключить' : 'Включить'),
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_forever_rounded,
                        color: AppColors.error,
                      ),
                      title: Text(
                        'Удалить полностью',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                school.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _StatusBadge(active: school.isActive),
      ],
    ),
  );

  Future<void> _onAction(BuildContext context, String action) async {
    final cubit = context.read<SchoolManagementCubit>();
    if (action == 'edit') {
      await showDialog<void>(
        context: context,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: _SchoolFormDialog(school: school),
        ),
      );
    } else if (action == 'status') {
      await cubit.toggleStatus(school);
    } else if (action == 'delete') {
      final confirmed = await ConfirmationDialog.show(
        context,
        title: 'Удалить школу полностью?',
        content:
            'Школа «${school.shortName}», её пользователи, классы, ученики и заявки будут удалены без возможности восстановления.',
        confirmText: 'Удалить полностью',
      );
      if (confirmed == true) await cubit.delete(school);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Активна' : 'Отключена',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptySchools extends StatelessWidget {
  const _EmptySchools();
  @override
  Widget build(BuildContext context) => const GlassSurfaceCard(
    padding: EdgeInsets.all(40),
    child: Column(
      children: [
        Icon(Icons.domain_add_rounded, size: 56),
        SizedBox(height: 16),
        Text(
          'Школ пока нет',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 6),
        Text(
          'Нажмите «Добавить школу», чтобы начать настройку системы.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _SchoolFormDialog extends StatefulWidget {
  const _SchoolFormDialog({this.school});
  final School? school;
  @override
  State<_SchoolFormDialog> createState() => _SchoolFormDialogState();
}

class _SchoolFormDialogState extends State<_SchoolFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _shortName;
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: widget.school?.fullName);
    _shortName = TextEditingController(text: widget.school?.shortName);
    _address = TextEditingController(text: widget.school?.address);
  }

  @override
  void dispose() {
    _fullName.dispose();
    _shortName.dispose();
    _address.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().length < 2 ? 'Заполните поле' : null;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.school == null ? 'Новая школа' : 'Редактирование школы',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Укажите официальное и короткое название, а также адрес.',
              ),
              const SizedBox(height: 24),
              GlobalTextFormField(
                controller: _fullName,
                labelText: 'Полное название',
                hintText:
                    'Государственное бюджетное образовательное учреждение…',
                validator: _required,
              ),
              const SizedBox(height: 14),
              GlobalTextFormField(
                controller: _shortName,
                labelText: 'Короткое название',
                hintText: 'ГБОУ Школа № 1',
                validator: _required,
              ),
              const SizedBox(height: 14),
              GlobalTextFormField(
                controller: _address,
                labelText: 'Адрес',
                hintText: 'Город, улица, дом',
                validator: _required,
              ),
              const SizedBox(height: 24),
              BlocBuilder<SchoolManagementCubit, SchoolManagementState>(
                builder: (context, state) => GlobalButton(
                  text: widget.school == null
                      ? 'Создать школу'
                      : 'Сохранить изменения',
                  isLoading: state.isSaving,
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: 8),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await context.read<SchoolManagementCubit>().save(
      id: widget.school?.id,
      draft: SchoolDraft(
        fullName: _fullName.text.trim(),
        shortName: _shortName.text.trim(),
        address: _address.text.trim(),
      ),
    );
    if (saved && mounted) Navigator.pop(context);
  }
}
