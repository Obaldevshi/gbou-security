import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_colors.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_class.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_teacher.dart';
import 'package:mobile_template/features/school_console/presentation/school_teachers_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/bulk_import_file.dart';
import 'package:mobile_template/features/school_console/presentation/managed_queryable_list.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
import 'package:mobile_template/presentation/widgets/common/confirmation_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/common/global_text_form_field.dart';

class SchoolTeachersPage extends StatelessWidget {
  const SchoolTeachersPage({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<SchoolTeachersCubit, SchoolTeachersState>(
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
        title: const Text('Учителя школы'),
        leading: IconButton(
          tooltip: 'Классы',
          onPressed: () => context.go(AppRoutes.schoolClasses),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.schoolGuards),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Охрана'),
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
        onPressed: state.classes.isEmpty
            ? null
            : () => _form(context, state.classes),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Добавить учителя'),
      ),
      body: RefreshIndicator(
        onRefresh: context.read<SchoolTeachersCubit>().load,
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
              'Учителя',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Создавайте учётные записи и назначайте учителям доступные классы.',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: state.classes.isEmpty
                    ? null
                    : () => _import(context),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Массовая загрузка'),
              ),
            ),
            const SizedBox(height: 24),
            if (state.status == ManagedTeachersStatus.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.status == ManagedTeachersStatus.failure)
              Center(
                child: TextButton.icon(
                  onPressed: context.read<SchoolTeachersCubit>().load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить загрузку'),
                ),
              )
            else if (state.teachers.isEmpty)
              const GlassSurfaceCard(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.co_present_outlined, size: 56),
                    SizedBox(height: 12),
                    Text('Учителей пока нет'),
                  ],
                ),
              )
            else
              ManagedQueryableList<ManagedTeacher>(
                items: state.teachers,
                searchText: (teacher) =>
                    '${teacher.fullName} ${teacher.login} ${teacher.phone ?? ''} ${teacher.classes.map((item) => item.name).join(' ')}',
                isActive: (teacher) => teacher.isActive,
                compare: (a, b) => a.fullName.compareTo(b.fullName),
                searchHint: 'Поиск учителя',
                emptyMessage: 'Учителя не найдены',
                itemBuilder: (context, teacher) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TeacherItem(
                    teacher: teacher,
                    classes: state.classes,
                    busy: state.busyIds.contains(teacher.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  Future<void> _form(
    BuildContext context,
    List<ManagedSchoolClass> classes, [
    ManagedTeacher? teacher,
  ]) => showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<SchoolTeachersCubit>(),
      child: _TeacherForm(classes: classes, teacher: teacher),
    ),
  );

  Future<void> _import(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<SchoolTeachersCubit>(),
      child: const _TeacherImportDialog(),
    ),
  );
}

class _TeacherImportDialog extends StatefulWidget {
  const _TeacherImportDialog();
  @override
  State<_TeacherImportDialog> createState() => _TeacherImportDialogState();
}

class _TeacherImportDialogState extends State<_TeacherImportDialog> {
  final controller = TextEditingController();
  TeacherImportSummary? summary;
  bool isPreview = false;
  String? fileError;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Массовая загрузка учителей',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('Формат строки: ФИО;логин;телефон;пароль;классы'),
            const Text('Классы перечисляйте через запятую, например: 5А,7Б'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Выбрать .txt, .csv или .xlsx'),
                ),
                TextButton.icon(
                  onPressed: () => BulkImportFile.saveTemplate(teachers: true),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Скачать шаблон XLSX'),
                ),
              ],
            ),
            if (fileError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  fileError!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            const SizedBox(height: 12),
            GlobalTextFormField(
              controller: controller,
              labelText: 'Список учителей',
              hintText:
                  'Мария Иванова;teacher.one;+79000000000;Пароль123;5А,7Б',
              keyboardType: TextInputType.multiline,
              maxLines: 10,
              onChanged: (_) => setState(() {}),
            ),
            if (summary != null) ...[
              const SizedBox(height: 16),
              GlassSurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isPreview ? 'Готово к добавлению' : 'Добавлено'}: ${summary!.createdCount}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (summary!.errors.isEmpty)
                      const Text(
                        'Все строки обработаны без ошибок',
                        style: TextStyle(color: AppColors.success),
                      )
                    else ...[
                      Text(
                        'Пропущено: ${summary!.errors.length}',
                        style: const TextStyle(color: AppColors.warning),
                      ),
                      const SizedBox(height: 8),
                      ...summary!.errors.map(
                        (item) => Text('Строка ${item.line}: ${item.message}'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            BlocBuilder<SchoolTeachersCubit, SchoolTeachersState>(
              builder: (context, state) => Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          state.isImporting || controller.text.trim().isEmpty
                          ? null
                          : () => _submit(dryRun: true),
                      child: const Text('Проверить'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlobalButton(
                      text: 'Загрузить',
                      isLoading: state.isImporting,
                      onPressed: controller.text.trim().isEmpty
                          ? null
                          : () => _submit(),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'csv', 'xlsx'],
      withData: true,
    );
    if (result == null || !mounted) return;
    try {
      final text = BulkImportFile.decode(result.files.single);
      setState(() {
        controller.text = text;
        fileError = null;
        summary = null;
      });
    } on FormatException catch (error) {
      setState(() => fileError = error.message.toString());
    }
  }

  Future<void> _submit({bool dryRun = false}) async {
    final result = await context.read<SchoolTeachersCubit>().import(
      controller.text,
      dryRun: dryRun,
    );
    if (mounted && result != null) {
      setState(() {
        summary = result;
        isPreview = dryRun;
      });
    }
  }
}

class _TeacherItem extends StatelessWidget {
  const _TeacherItem({
    required this.teacher,
    required this.classes,
    required this.busy,
  });
  final ManagedTeacher teacher;
  final List<ManagedSchoolClass> classes;
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
      CircleAvatar(child: Text(teacher.fullName.characters.first)),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teacher.fullName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              '@${teacher.login}${teacher.phone == null ? '' : ' · ${teacher.phone}'}',
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...teacher.classes.map(
                  (item) => Chip(
                    label: Text(item.name),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Text(
                  teacher.isActive ? 'Активен' : 'Отключён',
                  style: TextStyle(
                    color: teacher.isActive
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ],
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
                  value: context.read<SchoolTeachersCubit>(),
                  child: _TeacherForm(classes: classes, teacher: teacher),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: teacher.isActive ? 'Отключить' : 'Включить',
              onPressed: () =>
                  context.read<SchoolTeachersCubit>().toggle(teacher),
              icon: Icon(
                teacher.isActive
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
                  title: 'Удалить учителя?',
                  content:
                      'Учётная запись «${teacher.fullName}», назначения и связанные заявки будут удалены.',
                  confirmText: 'Удалить полностью',
                );
                if (ok == true && context.mounted) {
                  await context.read<SchoolTeachersCubit>().delete(teacher);
                }
              },
              icon: const Icon(Icons.delete_forever_outlined),
            ),
          ],
        );
}

class _TeacherForm extends StatefulWidget {
  const _TeacherForm({required this.classes, this.teacher});
  final List<ManagedSchoolClass> classes;
  final ManagedTeacher? teacher;
  @override
  State<_TeacherForm> createState() => _TeacherFormState();
}

class _TeacherFormState extends State<_TeacherForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController fullName;
  late final TextEditingController login;
  late final TextEditingController phone;
  late final TextEditingController password;
  late final Set<int> selected;
  @override
  void initState() {
    super.initState();
    fullName = TextEditingController(text: widget.teacher?.fullName);
    login = TextEditingController(text: widget.teacher?.login);
    phone = TextEditingController(text: widget.teacher?.phone);
    password = TextEditingController();
    selected =
        widget.teacher?.classes.map((item) => item.id).toSet() ??
        {widget.classes.first.id};
  }

  @override
  void dispose() {
    fullName.dispose();
    login.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Заполните поле' : null;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.teacher == null
                    ? 'Новый учитель'
                    : 'Редактирование учителя',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              GlobalTextFormField(
                controller: fullName,
                labelText: 'ФИО',
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
                labelText: widget.teacher == null
                    ? 'Пароль'
                    : 'Новый пароль (необязательно)',
                obscureText: true,
                validator: (value) {
                  if (widget.teacher == null &&
                      (value == null || value.isEmpty)) {
                    return 'Введите пароль';
                  }
                  if (value != null && value.isNotEmpty && value.length < 12) {
                    return 'Минимум 12 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              Text(
                'Назначенные классы',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              ...widget.classes.map(
                (item) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(item.name),
                  value: selected.contains(item.id),
                  onChanged: (value) => setState(
                    () => value == true
                        ? selected.add(item.id)
                        : selected.remove(item.id),
                  ),
                ),
              ),
              if (selected.isEmpty)
                const Text(
                  'Выберите хотя бы один класс',
                  style: TextStyle(color: AppColors.error),
                ),
              const SizedBox(height: 18),
              BlocBuilder<SchoolTeachersCubit, SchoolTeachersState>(
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
    if (!key.currentState!.validate() || selected.isEmpty) {
      setState(() {});
      return;
    }
    final saved = await context.read<SchoolTeachersCubit>().save(
      id: widget.teacher?.id,
      draft: TeacherDraft(
        login: login.text.trim(),
        fullName: fullName.text.trim(),
        phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
        password: password.text.isEmpty ? null : password.text,
        classIds: selected.toList(),
      ),
    );
    if (saved && mounted) Navigator.pop(context);
  }
}
