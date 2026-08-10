import 'package:flutter/material.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/features/shell/presentation/widgets/role_placeholder_card.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
import 'package:mobile_template/presentation/widgets/layout/scroll_shell.dart';

class GuardQueuePlaceholderPage extends StatelessWidget {
  const GuardQueuePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final showUserName = AppLayoutItemBuilder<bool>.values(
      narrow: false,
      wide: true,
    )(context);
    return ScrollShell(
      title: context.l10n.guardQueue,
      headerContent: Text(
        context.l10n.guardWorkspace,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Colors.white),
      ),
      actions: [SessionUserMenuButton(showName: showUserName)],
      body: RolePlaceholderCard(
        icon: Icons.verified_user_outlined,
        title: context.l10n.noExitRequests,
        description: context.l10n.guardQueueComingSoon,
      ),
    );
  }
}
