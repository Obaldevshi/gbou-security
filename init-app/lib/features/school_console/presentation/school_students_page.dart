import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_colors.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_class.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/presentation/school_students_cubit.dart';
import 'package:mobile_template/features/school_console/presentation/bulk_import_file.dart';
import 'package:mobile_template/features/school_console/presentation/managed_queryable_list.dart';
import 'package:mobile_template/features/shell/presentation/widgets/admin_app_bar.dart';
import 'package:mobile_template/presentation/widgets/common/confirmation_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/common/global_text_form_field.dart';

class SchoolStudentsPage extends StatelessWidget {
  const SchoolStudentsPage({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<SchoolStudentsCubit, SchoolStudentsState>(
    listenWhen: (a, b) => a.revision != b.revision,
    listener: (context, state) {
      if (state.feedback != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.feedback!)));
      }
    },
    builder: (context, state) => Scaffold(
      appBar: const AdminAppBar.school(sectionTitle: 'Ученики'),
      floatingActionButton: FloatingActionButton.extended(
        shape: const StadiumBorder(),
        onPressed: state.classes.isEmpty
            ? null
            : () => _form(context, state.classes),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Добавить ученика'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<SchoolStudentsCubit>().load(
          classId: state.classFilter,
          clearFilter: state.classFilter == null,
        ),
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
              'Ученики',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text('Управляйте составом классов и доступностью учеников.'),
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
            const SizedBox(height: 20),
            DropdownButtonFormField<int?>(
              initialValue: state.classFilter,
              decoration: const InputDecoration(
                labelText: 'Класс',
                prefixIcon: Icon(Icons.filter_alt_outlined),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Все классы'),
                ),
                ...state.classes.map(
                  (item) => DropdownMenuItem<int?>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                ),
              ],
              onChanged: (value) => value == null
                  ? context.read<SchoolStudentsCubit>().load(clearFilter: true)
                  : context.read<SchoolStudentsCubit>().load(classId: value),
            ),
            const SizedBox(height: 20),
            if (state.status == ManagedStudentsStatus.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.status == ManagedStudentsStatus.failure)
              Center(
                child: TextButton.icon(
                  onPressed: () => context.read<SchoolStudentsCubit>().load(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              )
            else if (state.students.isEmpty)
              const GlassSurfaceCard(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.people_outline_rounded, size: 56),
                    SizedBox(height: 12),
                    Text('Ученики не найдены'),
                  ],
                ),
              )
            else
              ManagedQueryableList<ManagedStudent>(
                items: state.students,
                searchText: (student) =>
                    '${student.fullName} ${student.className}',
                isActive: (student) => student.isActive,
                compare: (a, b) => a.fullName.compareTo(b.fullName),
                searchHint: 'Поиск ученика',
                emptyMessage: 'Ученики не найдены',
                itemBuilder: (context, student) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StudentItem(
                    student: student,
                    classes: state.classes,
                    busy: state.busyIds.contains(student.id),
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
    ManagedStudent? student,
  ]) => showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<SchoolStudentsCubit>(),
      child: _StudentForm(classes: classes, student: student),
    ),
  );

  Future<void> _import(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<SchoolStudentsCubit>(),
      child: const _StudentImportDialog(),
    ),
  );
}

class _StudentImportDialog extends StatefulWidget {
  const _StudentImportDialog();
  @override
  State<_StudentImportDialog> createState() => _StudentImportDialogState();
}

class _StudentImportDialogState extends State<_StudentImportDialog> {
  final controller = TextEditingController();
  StudentImportSummary? summary;
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
              'Массовая загрузка учеников',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('Формат: ФИО;Класс'),
            const Text('Также можно: Фамилия;Имя;Отчество;Класс'),
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
                  onPressed: () => BulkImportFile.saveTemplate(teachers: false),
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
              labelText: 'Список учеников',
              hintText: 'Иванов Иван Иванович;5А',
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
            BlocBuilder<SchoolStudentsCubit, SchoolStudentsState>(
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
    final result = await context.read<SchoolStudentsCubit>().import(
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

class _StudentItem extends StatelessWidget {
  const _StudentItem({
    required this.student,
    required this.classes,
    required this.busy,
  });
  final ManagedStudent student;
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
      CircleAvatar(child: Text(student.lastName.characters.first)),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              student.fullName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              '${student.className} · ${student.isActive ? 'Активен' : 'Отключён'}',
              style: TextStyle(
                color: student.isActive ? AppColors.success : AppColors.warning,
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
                  value: context.read<SchoolStudentsCubit>(),
                  child: _StudentForm(classes: classes, student: student),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: student.isActive ? 'Отключить' : 'Включить',
              onPressed: () =>
                  context.read<SchoolStudentsCubit>().toggle(student),
              icon: Icon(
                student.isActive
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
                  title: 'Удалить ученика?',
                  content:
                      'Ученик «${student.fullName}» и все его заявки будут удалены.',
                  confirmText: 'Удалить полностью',
                );
                if (ok == true && context.mounted) {
                  await context.read<SchoolStudentsCubit>().delete(student);
                }
              },
              icon: const Icon(Icons.delete_forever_outlined),
            ),
          ],
        );
}

class _StudentForm extends StatefulWidget {
  const _StudentForm({required this.classes, this.student});
  final List<ManagedSchoolClass> classes;
  final ManagedStudent? student;
  @override
  State<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<_StudentForm> {
  final key = GlobalKey<FormState>();
  late int classId;
  late final TextEditingController lastName;
  late final TextEditingController firstName;
  late final TextEditingController middleName;
  @override
  void initState() {
    super.initState();
    classId = widget.student?.classId ?? widget.classes.first.id;
    lastName = TextEditingController(text: widget.student?.lastName);
    firstName = TextEditingController(text: widget.student?.firstName);
    middleName = TextEditingController(text: widget.student?.middleName);
  }

  @override
  void dispose() {
    lastName.dispose();
    firstName.dispose();
    middleName.dispose();
    super.dispose();
  }

  String? requiredName(String? value) =>
      value == null || value.trim().isEmpty ? 'Заполните поле' : null;
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
                widget.student == null
                    ? 'Новый ученик'
                    : 'Редактирование ученика',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                initialValue: classId,
                decoration: const InputDecoration(labelText: 'Класс'),
                items: widget.classes
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => classId = value!),
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: lastName,
                labelText: 'Фамилия',
                validator: requiredName,
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: firstName,
                labelText: 'Имя',
                validator: requiredName,
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: middleName,
                labelText: 'Отчество (необязательно)',
              ),
              const SizedBox(height: 20),
              BlocBuilder<SchoolStudentsCubit, SchoolStudentsState>(
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
    final saved = await context.read<SchoolStudentsCubit>().save(
      id: widget.student?.id,
      draft: StudentDraft(
        classId: classId,
        lastName: lastName.text.trim(),
        firstName: firstName.text.trim(),
        middleName: middleName.text.trim().isEmpty
            ? null
            : middleName.text.trim(),
      ),
    );
    if (saved && mounted) Navigator.pop(context);
  }
}
