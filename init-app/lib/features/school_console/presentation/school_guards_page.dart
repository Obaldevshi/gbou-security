import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_router.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_colors.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_guard.dart';
import 'package:mobile_template/features/school_console/presentation/school_guards_cubit.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
import 'package:mobile_template/presentation/widgets/common/confirmation_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/common/global_text_form_field.dart';

class SchoolGuardsPage extends StatelessWidget {
  const SchoolGuardsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocConsumer<SchoolGuardsCubit, SchoolGuardsState>(
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
            title: const Text('Охрана школы'),
            leading: IconButton(
              tooltip: 'Классы',
              onPressed: () => context.go(AppRoutes.schoolClasses),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            actions: const [SessionUserMenuButton(showName: true)],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _form(context),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Добавить охранника'),
          ),
          body: RefreshIndicator(
            onRefresh: context.read<SchoolGuardsCubit>().load,
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
                  'Пользователи охраны',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Управляйте доступом сотрудников и постов охраны.'),
                const SizedBox(height: 24),
                if (state.status == ManagedGuardsStatus.loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.status == ManagedGuardsStatus.failure)
                  Center(
                    child: TextButton.icon(
                      onPressed: context.read<SchoolGuardsCubit>().load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить загрузку'),
                    ),
                  )
                else if (state.guards.isEmpty)
                  const GlassSurfaceCard(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.shield_outlined, size: 56),
                        SizedBox(height: 12),
                        Text('Пользователей охраны пока нет'),
                      ],
                    ),
                  )
                else
                  ...state.guards.map(
                    (guard) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GuardItem(
                        guard: guard,
                        busy: state.busyIds.contains(guard.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
  Future<void> _form(BuildContext context, [ManagedGuard? guard]) =>
      showDialog<void>(
        context: context,
        builder: (_) => BlocProvider.value(
          value: context.read<SchoolGuardsCubit>(),
          child: _GuardForm(guard: guard),
        ),
      );
}

class _GuardItem extends StatelessWidget {
  const _GuardItem({required this.guard, required this.busy});
  final ManagedGuard guard;
  final bool busy;
  @override
  Widget build(BuildContext context) => GlassSurfaceCard(
    padding: const EdgeInsets.all(18),
    child: AppLayoutItemBuilder<Widget>(
      narrow: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _info(context),
          const SizedBox(height: 12),
          _actions(context),
        ],
      ),
      wide: () => Row(
        children: [
          Expanded(child: _info(context)),
          _actions(context),
        ],
      ),
    )(context),
  );
  Widget _info(BuildContext context) => Row(
    children: [
      CircleAvatar(child: const Icon(Icons.shield_outlined)),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              guard.fullName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              '@${guard.login}${guard.phone == null ? '' : ' · ${guard.phone}'}',
            ),
            Text(
              guard.isActive ? 'Активен' : 'Отключён',
              style: TextStyle(
                color: guard.isActive ? AppColors.success : AppColors.warning,
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
                  value: context.read<SchoolGuardsCubit>(),
                  child: _GuardForm(guard: guard),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: guard.isActive ? 'Отключить' : 'Включить',
              onPressed: () => context.read<SchoolGuardsCubit>().toggle(guard),
              icon: Icon(
                guard.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
            ),
            IconButton(
              tooltip: 'Удалить',
              color: AppColors.error,
              onPressed: () async {
                final ok = await ConfirmationDialog.show(
                  context,
                  title: 'Удалить охранника?',
                  content:
                      'Учётная запись «${guard.fullName}» будет удалена. История выходов сохранится.',
                  confirmText: 'Удалить полностью',
                );
                if (ok == true && context.mounted) {
                  await context.read<SchoolGuardsCubit>().delete(guard);
                }
              },
              icon: const Icon(Icons.delete_forever_outlined),
            ),
          ],
        );
}

class _GuardForm extends StatefulWidget {
  const _GuardForm({this.guard});
  final ManagedGuard? guard;
  @override
  State<_GuardForm> createState() => _GuardFormState();
}

class _GuardFormState extends State<_GuardForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name, login, phone, password;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.guard?.fullName);
    login = TextEditingController(text: widget.guard?.login);
    phone = TextEditingController(text: widget.guard?.phone);
    password = TextEditingController();
  }

  @override
  void dispose() {
    name.dispose();
    login.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  String? requiredText(String? v) =>
      v == null || v.trim().isEmpty ? 'Заполните поле' : null;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.guard == null
                    ? 'Новый охранник'
                    : 'Редактирование охранника',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              GlobalTextFormField(
                controller: name,
                labelText: 'ФИО или название поста',
                validator: requiredText,
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: login,
                labelText: 'Логин',
                validator: requiredText,
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: phone,
                labelText: 'Телефон (необязательно)',
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: password,
                labelText: widget.guard == null
                    ? 'Пароль'
                    : 'Новый пароль (необязательно)',
                obscureText: true,
                validator: (v) {
                  if (widget.guard == null && (v == null || v.isEmpty)) {
                    return 'Введите пароль';
                  }
                  if (v != null && v.isNotEmpty && v.length < 8) {
                    return 'Минимум 8 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              BlocBuilder<SchoolGuardsCubit, SchoolGuardsState>(
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
    final saved = await context.read<SchoolGuardsCubit>().save(
      id: widget.guard?.id,
      draft: GuardDraft(
        login: login.text.trim(),
        fullName: name.text.trim(),
        phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
        password: password.text.isEmpty ? null : password.text,
      ),
    );
    if (saved && mounted) Navigator.pop(context);
  }
}
