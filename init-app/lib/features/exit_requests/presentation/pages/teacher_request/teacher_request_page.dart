import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_request/teacher_request_cubit.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_request/teacher_request_state.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_requests/teacher_requests_cubit.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/common/global_text_form_field.dart';
import 'package:mobile_template/presentation/widgets/layout/scroll_shell.dart';

class TeacherRequestPage extends StatefulWidget {
  const TeacherRequestPage({super.key});

  @override
  State<TeacherRequestPage> createState() => _TeacherRequestPageState();
}

class _TeacherRequestPageState extends State<TeacherRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _customReasonController = TextEditingController();
  bool _showValidation = false;

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = AppLayoutItemBuilder<List<Widget>>.values(
      narrow: const [SessionUserMenuButton()],
      wide: const [],
    )(context);

    return ScrollShell(
      title: context.l10n.newRequest,
      headerContent: Text(
        context.l10n.teacherRequestIntro,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Colors.white),
      ),
      actions: actions,
      body: BlocConsumer<TeacherRequestCubit, TeacherRequestState>(
        listenWhen: (previous, current) =>
            previous.submissionStatus != current.submissionStatus ||
            previous.selectedReason != current.selectedReason,
        listener: (context, state) {
          if (state.selectedReason != ExitReasonType.other &&
              _customReasonController.text.isNotEmpty) {
            _customReasonController.clear();
          }
          if (state.submissionStatus == RequestSubmissionStatus.success) {
            final created = state.lastCreated;
            if (created != null) {
              context.read<TeacherRequestsCubit>().addCreatedRequest(created);
            }
            _customReasonController.clear();
            _formKey.currentState?.reset();
            setState(() => _showValidation = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(context.l10n.requestSent)));
            context.go(AppRoutes.teacherActive);
          }
        },
        builder: (context, state) {
          final content = _RequestForm(
            formKey: _formKey,
            customReasonController: _customReasonController,
            showValidation: _showValidation,
            state: state,
            onPickDateTime: () => _pickExitTime(state),
            onSubmit: _submit,
          );
          return AppLayoutItemBuilder<Widget>(
            narrow: () => content,
            wide: () => Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: content,
              ),
            ),
          )(context);
        },
      ),
    );
  }

  Future<void> _pickExitTime(TeacherRequestState state) async {
    if (state.isSubmitting) return;
    final now = DateTime.now();
    final initial = state.scheduledAt ?? _roundedFutureTime(now);
    final controller = TextEditingController(
      text:
          '${initial.hour.toString().padLeft(2, '0')}:${initial.minute.toString().padLeft(2, '0')}',
    );
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Время выхода'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            labelText: 'Время сегодня',
            hintText: 'Например, 14:30',
            prefixIcon: Icon(Icons.schedule_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, DateTime.now()),
            child: const Text('Сейчас'),
          ),
          FilledButton(
            onPressed: () {
              final match = RegExp(
                r'^(\d{1,2}):(\d{2})$',
              ).firstMatch(controller.text.trim());
              if (match == null) return;
              final hour = int.parse(match.group(1)!);
              final minute = int.parse(match.group(2)!);
              if (hour > 23 || minute > 59) return;
              Navigator.pop(
                dialogContext,
                DateTime(now.year, now.month, now.day, hour, minute),
              );
            },
            child: const Text('Указать время'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (selected == null || !mounted) return;
    if (selected.isBefore(
      DateTime.now().subtract(const Duration(minutes: 1)),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите текущее или будущее время сегодня'),
        ),
      );
      return;
    }
    context.read<TeacherRequestCubit>().setScheduledAt(selected);
    if (_showValidation) _formKey.currentState?.validate();
  }

  DateTime _roundedFutureTime(DateTime now) {
    final base = now.add(const Duration(minutes: 5));
    final remainder = base.minute % 5;
    return DateTime(
      base.year,
      base.month,
      base.day,
      base.hour,
      remainder == 0 ? base.minute : base.minute + (5 - remainder),
    );
  }

  void _submit() {
    setState(() => _showValidation = true);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    context.read<TeacherRequestCubit>().submit();
  }
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.formKey,
    required this.customReasonController,
    required this.showValidation,
    required this.state,
    required this.onPickDateTime,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController customReasonController;
  final bool showValidation;
  final TeacherRequestState state;
  final VoidCallback onPickDateTime;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TeacherRequestCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSurfaceCard(
          child: Material(
            type: MaterialType.transparency,
            child: Form(
              key: formKey,
              autovalidateMode: showValidation
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.requestFormTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceS),
                  Text(
                    context.l10n.requestFormDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceL),
                  if (state.classesStatus == RequestLoadStatus.loading)
                    const LinearProgressIndicator(),
                  if (state.classesStatus == RequestLoadStatus.failure)
                    _LoadError(
                      message: _localizedFailure(context, state.failure),
                      onRetry: cubit.loadClasses,
                    )
                  else if (state.classesStatus == RequestLoadStatus.success &&
                      state.classes.isEmpty)
                    _InlineMessage(
                      icon: Icons.school_outlined,
                      message: context.l10n.requestNoClasses,
                    )
                  else
                    DropdownButtonFormField<TeacherClass>(
                      key: ValueKey(state.selectedClass?.id),
                      initialValue: state.selectedClass,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.requestClass,
                        prefixIcon: const Icon(Icons.school_outlined),
                      ),
                      hint: Text(context.l10n.requestSelectClass),
                      items: state.classes
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: state.isSubmitting ? null : cubit.selectClass,
                      validator: (value) => value == null
                          ? context.l10n.requestClassRequired
                          : null,
                    ),
                  const SizedBox(height: AppDimensions.spaceM),
                  if (state.studentsStatus == RequestLoadStatus.loading)
                    const LinearProgressIndicator()
                  else if (state.studentsStatus == RequestLoadStatus.failure)
                    _LoadError(
                      message: _localizedFailure(context, state.failure),
                      onRetry: () => cubit.selectClass(state.selectedClass),
                    )
                  else if (state.selectedClass != null &&
                      state.studentsStatus == RequestLoadStatus.success &&
                      state.students.isEmpty)
                    _InlineMessage(
                      icon: Icons.person_search_outlined,
                      message: context.l10n.requestNoStudents,
                    )
                  else
                    DropdownButtonFormField<Student>(
                      key: ValueKey(state.selectedStudent?.id),
                      initialValue: state.selectedStudent,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.requestStudent,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      hint: Text(context.l10n.requestSelectStudent),
                      items: state.students
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged:
                          state.isSubmitting || state.selectedClass == null
                          ? null
                          : cubit.selectStudent,
                      validator: (value) => value == null
                          ? context.l10n.requestStudentRequired
                          : null,
                    ),
                  const SizedBox(height: AppDimensions.spaceM),
                  DropdownButtonFormField<ExitReasonType>(
                    initialValue: state.selectedReason,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.requestReason,
                      prefixIcon: const Icon(Icons.description_outlined),
                    ),
                    hint: Text(context.l10n.requestSelectReason),
                    items: ExitReasonType.values
                        .map(
                          (reason) => DropdownMenuItem(
                            value: reason,
                            child: Text(_reasonLabel(context, reason)),
                          ),
                        )
                        .toList(),
                    onChanged: state.isSubmitting ? null : cubit.selectReason,
                    validator: (value) => value == null
                        ? context.l10n.requestReasonRequired
                        : null,
                  ),
                  if (state.selectedReason == ExitReasonType.other) ...[
                    const SizedBox(height: AppDimensions.spaceM),
                    GlobalTextFormField(
                      controller: customReasonController,
                      labelText: context.l10n.requestCustomReason,
                      hintText: context.l10n.requestCustomReasonHint,
                      maxLines: 3,
                      maxLength: 500,
                      enabled: !state.isSubmitting,
                      textInputAction: TextInputAction.newline,
                      onChanged: cubit.setCustomReason,
                      validator: (value) {
                        final normalized = value?.trim() ?? '';
                        if (normalized.isEmpty) {
                          return context.l10n.requestCustomReasonRequired;
                        }
                        if (normalized.length < 3) {
                          return context.l10n.requestCustomReasonTooShort;
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spaceM),
                  _DateTimeField(
                    value: state.scheduledAt,
                    enabled: !state.isSubmitting,
                    showValidation: showValidation,
                    onTap: onPickDateTime,
                  ),
                  if (state.submissionStatus ==
                          RequestSubmissionStatus.failure &&
                      state.failure != null) ...[
                    const SizedBox(height: AppDimensions.spaceM),
                    _InlineMessage(
                      icon: Icons.error_outline_rounded,
                      message: _localizedFailure(context, state.failure),
                      isError: true,
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spaceL),
                  GlobalButton(
                    text: context.l10n.requestSubmit,
                    onPressed: onSubmit,
                    isLoading: state.isSubmitting,
                    isEnabled:
                        state.classesStatus == RequestLoadStatus.success &&
                        state.classes.isNotEmpty &&
                        !state.isSubmitting,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.value,
    required this.enabled,
    required this.showValidation,
    required this.onTap,
  });

  final DateTime? value;
  final bool enabled;
  final bool showValidation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPast =
        value != null &&
        value!.isBefore(DateTime.now().subtract(const Duration(minutes: 1)));
    final hasError = showValidation && (value == null || isPast);
    final display = value == null
        ? 'Сейчас или укажите время'
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(value!));
    return Semantics(
      button: true,
      label: context.l10n.requestScheduledAt,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppDimensions.borderRadiusM,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: context.l10n.requestScheduledAt,
            prefixIcon: const Icon(Icons.schedule_outlined),
            suffixIcon: const Icon(Icons.schedule_rounded),
            enabled: enabled,
            errorText: hasError
                ? (isPast
                      ? context.l10n.requestScheduledInPast
                      : context.l10n.requestScheduledRequired)
                : null,
          ),
          child: Text(display),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _InlineMessage(
      icon: Icons.error_outline_rounded,
      message: message,
      isError: true,
      action: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(context.l10n.retry),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.message,
    this.isError = false,
    this.action,
  });

  final IconData icon;
  final String message;
  final bool isError;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: AppDimensions.spaceS),
        Expanded(
          child: Text(message, style: TextStyle(color: color)),
        ),
        ?action,
      ],
    );
  }
}

String _reasonLabel(BuildContext context, ExitReasonType reason) =>
    switch (reason) {
      ExitReasonType.parentNote => context.l10n.requestReasonParentNote,
      ExitReasonType.health => context.l10n.requestReasonHealth,
      ExitReasonType.other => context.l10n.requestReasonOther,
    };

String _localizedFailure(BuildContext context, Failure? failure) {
  return switch (failure?.errorCode) {
    'class_not_available' => context.l10n.requestClassUnavailable,
    'student_not_available' => context.l10n.requestStudentUnavailable,
    'custom_reason_required' => context.l10n.requestCustomReasonRequired,
    'custom_reason_not_allowed' => context.l10n.requestCustomReasonNotAllowed,
    'scheduled_at_in_past' => context.l10n.requestScheduledInPast,
    'scheduled_at_timezone_required' =>
      context.l10n.requestScheduledTimezoneRequired,
    'active_request_exists' => context.l10n.requestActiveExists,
    'no_internet' => context.l10n.offlineBanner,
    'timeout' => context.l10n.errorTimeout,
    'access_forbidden' => context.l10n.errorAccessDenied,
    _ => context.l10n.requestSendFailed,
  };
}
