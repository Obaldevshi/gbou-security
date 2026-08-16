import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_router.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_colors.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_class.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/presentation/school_students_cubit.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
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
      appBar: AppBar(
        title: const Text('Ученики школы'),
        leading: IconButton(
          tooltip: 'Классы',
          onPressed: () => context.go(AppRoutes.schoolClasses),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: const [SessionUserMenuButton(showName: true)],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
              ...state.students.map(
                (student) => Padding(
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
              tooltip: 'Удалить',
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
