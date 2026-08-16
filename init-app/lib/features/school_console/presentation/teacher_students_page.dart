import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_colors.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/presentation/teacher_students_cubit.dart';
import 'package:mobile_template/presentation/widgets/common/confirmation_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/common/global_text_form_field.dart';

class TeacherStudentsPage extends StatelessWidget {
  const TeacherStudentsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocConsumer<TeacherStudentsCubit, TeacherStudentsState>(
        listenWhen: (a, b) => a.revision != b.revision,
        listener: (context, s) {
          if (s.feedback != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(s.feedback!)));
          }
        },
        builder: (context, s) => Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: s.classes.isEmpty
                ? null
                : () => _form(context, s.classes),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Добавить ученика'),
          ),
          body: RefreshIndicator(
            onRefresh: context.read<TeacherStudentsCubit>().load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppDimensions.getResponsivePadding(context),
                24,
                AppDimensions.getResponsivePadding(context),
                110,
              ),
              children: [
                Text(
                  'Мои ученики',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Ученики назначенных вам классов.'),
                const SizedBox(height: 24),
                if (s.status == TeacherStudentsStatus.loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (s.status == TeacherStudentsStatus.failure)
                  Center(
                    child: TextButton.icon(
                      onPressed: context.read<TeacherStudentsCubit>().load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  )
                else if (s.students.isEmpty)
                  const GlassSurfaceCard(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('Ученики не найдены')),
                  )
                else
                  ...s.students.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _Item(student: e, busy: s.busyIds.contains(e.id)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
  Future<void> _form(BuildContext context, List<TeacherClass> classes) =>
      showDialog<void>(
        context: context,
        builder: (_) => BlocProvider.value(
          value: context.read<TeacherStudentsCubit>(),
          child: _Form(classes: classes),
        ),
      );
}

class _Item extends StatelessWidget {
  const _Item({required this.student, required this.busy});
  final ManagedStudent student;
  final bool busy;
  @override
  Widget build(BuildContext context) => GlassSurfaceCard(
    padding: const EdgeInsets.all(18),
    child: AppLayoutItemBuilder<Widget>(
      narrow: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_info(context), _actions(context)],
      ),
      wide: () => Row(
        children: [
          Expanded(child: _info(context)),
          _actions(context),
        ],
      ),
    )(context),
  );
  Widget _info(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(child: Text(student.lastName.characters.first)),
    title: Text(
      student.fullName,
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
    subtitle: Text(
      '${student.className} · ${student.isActive ? 'Активен' : 'Отключён'}',
    ),
  );
  Widget _actions(BuildContext context) => busy
      ? const CircularProgressIndicator()
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: student.isActive ? 'Отключить' : 'Включить',
              onPressed: () =>
                  context.read<TeacherStudentsCubit>().toggle(student),
              icon: Icon(
                student.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
            ),
            IconButton(
              color: AppColors.error,
              tooltip: 'Удалить',
              onPressed: () async {
                final ok = await ConfirmationDialog.show(
                  context,
                  title: 'Удалить ученика?',
                  content:
                      'Ученик «${student.fullName}» и связанные заявки будут удалены.',
                  confirmText: 'Удалить полностью',
                );
                if (ok == true && context.mounted) {
                  await context.read<TeacherStudentsCubit>().delete(student);
                }
              },
              icon: const Icon(Icons.delete_forever_outlined),
            ),
          ],
        );
}

class _Form extends StatefulWidget {
  const _Form({required this.classes});
  final List<TeacherClass> classes;
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final key = GlobalKey<FormState>();
  late int classId;
  final last = TextEditingController(),
      first = TextEditingController(),
      middle = TextEditingController();
  @override
  void initState() {
    super.initState();
    classId = widget.classes.first.id;
  }

  @override
  void dispose() {
    last.dispose();
    first.dispose();
    middle.dispose();
    super.dispose();
  }

  String? req(String? v) =>
      v == null || v.trim().isEmpty ? 'Заполните поле' : null;
  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Новый ученик',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: classId,
                items: widget.classes
                    .map(
                      (e) => DropdownMenuItem(value: e.id, child: Text(e.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => classId = v!),
                decoration: const InputDecoration(labelText: 'Класс'),
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: last,
                labelText: 'Фамилия',
                validator: req,
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: first,
                labelText: 'Имя',
                validator: req,
              ),
              const SizedBox(height: 12),
              GlobalTextFormField(
                controller: middle,
                labelText: 'Отчество (необязательно)',
              ),
              const SizedBox(height: 20),
              BlocBuilder<TeacherStudentsCubit, TeacherStudentsState>(
                builder: (context, s) => GlobalButton(
                  text: 'Добавить',
                  isLoading: s.saving,
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
    final ok = await context.read<TeacherStudentsCubit>().create(
      StudentDraft(
        classId: classId,
        lastName: last.text.trim(),
        firstName: first.text.trim(),
        middleName: middle.text.trim().isEmpty ? null : middle.text.trim(),
      ),
    );
    if (ok && mounted) Navigator.pop(context);
  }
}
