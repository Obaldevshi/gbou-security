import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_router.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_colors.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/features/school_management/domain/entities/school.dart';
import 'package:mobile_template/features/school_management/presentation/cubit/school_admins_cubit.dart';
import 'package:mobile_template/features/school_management/presentation/cubit/school_admins_state.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
import 'package:mobile_template/presentation/widgets/common/confirmation_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/common/global_text_form_field.dart';

class SchoolAdminsPage extends StatefulWidget {
  const SchoolAdminsPage({super.key});
  @override
  State<SchoolAdminsPage> createState() => _SchoolAdminsPageState();
}

class _SchoolAdminsPageState extends State<SchoolAdminsPage> {
  int? _schoolFilter;

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<SchoolAdminsCubit, SchoolAdminsState>(
    listenWhen: (a, b) => a.feedbackRevision != b.feedbackRevision,
    listener: (context, state) {
      if (state.feedback != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.feedback!)));
      }
    },
    builder: (context, state) {
      final admins = _schoolFilter == null
          ? state.admins
          : state.admins
                .where((item) => item.schoolId == _schoolFilter)
                .toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Администраторы школ'),
          leading: IconButton(
            tooltip: 'Школы',
            onPressed: () => context.go(AppRoutes.systemSchools),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          actions: const [SessionUserMenuButton(showName: true)],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: state.schools.isEmpty
              ? null
              : () => _openForm(context, state.schools),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Создать учётную запись'),
        ),
        body: RefreshIndicator(
          onRefresh: context.read<SchoolAdminsCubit>().load,
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
                'Локальные администраторы',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Каждая учётная запись управляет данными только своей школы.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int?>(
                initialValue: _schoolFilter,
                decoration: const InputDecoration(
                  labelText: 'Фильтр по школе',
                  prefixIcon: Icon(Icons.filter_alt_outlined),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Все школы'),
                  ),
                  ...state.schools.map(
                    (school) => DropdownMenuItem<int?>(
                      value: school.id,
                      child: Text(school.shortName),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _schoolFilter = value),
              ),
              const SizedBox(height: 20),
              if (state.status == SchoolAdminsStatus.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (state.status == SchoolAdminsStatus.failure)
                _MessageCard(
                  icon: Icons.cloud_off_rounded,
                  text: 'Не удалось загрузить учётные записи',
                  action: () => context.read<SchoolAdminsCubit>().load(),
                )
              else if (admins.isEmpty)
                const _MessageCard(
                  icon: Icons.manage_accounts_outlined,
                  text: 'Администраторов пока нет',
                )
              else
                ...admins.map(
                  (admin) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AdminItem(
                      admin: admin,
                      school: state.schools
                          .where((item) => item.id == admin.schoolId)
                          .firstOrNull,
                      busy: state.busyIds.contains(admin.id),
                      schools: state.schools,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _openForm(
    BuildContext context,
    List<School> schools, [
    SchoolAdmin? admin,
  ]) => showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => BlocProvider.value(
      value: context.read<SchoolAdminsCubit>(),
      child: _AdminFormDialog(schools: schools, admin: admin),
    ),
  );
}

class _AdminItem extends StatelessWidget {
  const _AdminItem({
    required this.admin,
    required this.school,
    required this.busy,
    required this.schools,
  });
  final SchoolAdmin admin;
  final School? school;
  final bool busy;
  final List<School> schools;

  @override
  Widget build(BuildContext context) => AppLayoutItemBuilder<Widget>(
    narrow: () => _content(context, vertical: true),
    wide: () => _content(context, vertical: false),
  )(context);

  Widget _content(
    BuildContext context, {
    required bool vertical,
  }) => GlassSurfaceCard(
    padding: const EdgeInsets.all(18),
    child: Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: vertical
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        CircleAvatar(child: Text(admin.fullName.characters.first)),
        SizedBox(width: vertical ? 0 : 14, height: vertical ? 12 : 0),
        if (vertical)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                admin.fullName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text('${school?.shortName ?? 'Школа удалена'} · ${admin.login}'),
              if (admin.phone?.isNotEmpty == true) Text(admin.phone!),
            ],
          )
        else
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin.fullName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${school?.shortName ?? 'Школа удалена'} · ${admin.login}',
                ),
                if (admin.phone?.isNotEmpty == true) Text(admin.phone!),
              ],
            ),
          ),
        SizedBox(width: vertical ? 0 : 12, height: vertical ? 12 : 0),
        _Status(active: admin.isActive),
        const SizedBox(width: 8),
        if (busy)
          const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          PopupMenuButton<String>(
            tooltip: 'Действия',
            onSelected: (action) => _action(context, action),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Изменить')),
              PopupMenuItem(
                value: 'status',
                child: Text(admin.isActive ? 'Отключить' : 'Включить'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Удалить полностью',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
      ],
    ),
  );

  Future<void> _action(BuildContext context, String action) async {
    final cubit = context.read<SchoolAdminsCubit>();
    if (action == 'edit') {
      await showDialog<void>(
        context: context,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: _AdminFormDialog(schools: schools, admin: admin),
        ),
      );
    } else if (action == 'status') {
      await cubit.toggle(admin);
    } else {
      final ok = await ConfirmationDialog.show(
        context,
        title: 'Удалить администратора?',
        content:
            'Учётная запись ${admin.login} будет удалена без возможности восстановления.',
        confirmText: 'Удалить полностью',
      );
      if (ok == true) await cubit.delete(admin);
    }
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => GlassSurfaceCard(
    padding: const EdgeInsets.all(36),
    child: Column(
      children: [
        Icon(icon, size: 52),
        const SizedBox(height: 12),
        Text(text),
        if (action != null)
          TextButton(onPressed: action, child: const Text('Повторить')),
      ],
    ),
  );
}

class _AdminFormDialog extends StatefulWidget {
  const _AdminFormDialog({required this.schools, this.admin});
  final List<School> schools;
  final SchoolAdmin? admin;
  @override
  State<_AdminFormDialog> createState() => _AdminFormDialogState();
}

class _AdminFormDialogState extends State<_AdminFormDialog> {
  final _key = GlobalKey<FormState>();
  late int _schoolId;
  late final TextEditingController _name;
  late final TextEditingController _login;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  @override
  void initState() {
    super.initState();
    _schoolId = widget.admin?.schoolId ?? widget.schools.first.id;
    _name = TextEditingController(text: widget.admin?.fullName);
    _login = TextEditingController(text: widget.admin?.login);
    _phone = TextEditingController(text: widget.admin?.phone);
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().length < 3 ? 'Заполните поле' : null;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.admin == null
                    ? 'Новый администратор школы'
                    : 'Редактирование администратора',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                initialValue: _schoolId,
                decoration: const InputDecoration(labelText: 'Школа'),
                items: widget.schools
                    .map(
                      (school) => DropdownMenuItem(
                        value: school.id,
                        child: Text(school.shortName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _schoolId = value!),
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: _name,
                labelText: 'ФИО',
                validator: _required,
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: _login,
                labelText: 'Логин',
                validator: _required,
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: _phone,
                labelText: 'Телефон (необязательно)',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: _password,
                labelText: widget.admin == null
                    ? 'Пароль'
                    : 'Новый пароль (необязательно)',
                obscureText: true,
                validator: (value) =>
                    widget.admin == null && (value?.length ?? 0) < 8
                    ? 'Минимум 8 символов'
                    : value!.isNotEmpty && value.length < 8
                    ? 'Минимум 8 символов'
                    : null,
              ),
              const SizedBox(height: 22),
              BlocBuilder<SchoolAdminsCubit, SchoolAdminsState>(
                builder: (context, state) => GlobalButton(
                  text: widget.admin == null ? 'Создать' : 'Сохранить',
                  isLoading: state.isSaving,
                  onPressed: _submit,
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
  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    final saved = await context.read<SchoolAdminsCubit>().save(
      id: widget.admin?.id,
      draft: SchoolAdminDraft(
        schoolId: _schoolId,
        login: _login.text.trim(),
        fullName: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        password: _password.text,
      ),
    );
    if (saved && mounted) Navigator.pop(context);
  }
}
