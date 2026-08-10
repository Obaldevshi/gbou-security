import 'package:flutter/material.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/features/shell/presentation/widgets/role_placeholder_card.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
import 'package:mobile_template/presentation/widgets/layout/scroll_shell.dart';

enum TeacherSection { request, active, history }

class TeacherPlaceholderPage extends StatelessWidget {
  const TeacherPlaceholderPage({required this.section, super.key});

  final TeacherSection section;

  @override
  Widget build(BuildContext context) {
    final title = switch (section) {
      TeacherSection.request => context.l10n.newRequest,
      TeacherSection.active => context.l10n.activeRequests,
      TeacherSection.history => context.l10n.requestHistory,
    };
    final description = switch (section) {
      TeacherSection.request => context.l10n.teacherRequestComingSoon,
      TeacherSection.active => context.l10n.activeRequestsComingSoon,
      TeacherSection.history => context.l10n.historyComingSoon,
    };
    final icon = switch (section) {
      TeacherSection.request => Icons.add_task_rounded,
      TeacherSection.active => Icons.schedule_rounded,
      TeacherSection.history => Icons.history_rounded,
    };
    final actions = AppLayoutItemBuilder<List<Widget>>.values(
      narrow: const [SessionUserMenuButton()],
      wide: const [],
    )(context);

    return ScrollShell(
      title: title,
      headerContent: Text(
        context.l10n.teacherWorkspace,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Colors.white),
      ),
      actions: actions,
      body: RolePlaceholderCard(
        icon: icon,
        title: title,
        description: description,
      ),
    );
  }
}
