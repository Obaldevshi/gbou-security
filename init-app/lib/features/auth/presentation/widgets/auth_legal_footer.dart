import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/core/utils/app_licenses.dart';

/// Secondary links remain readable, accessible and available before sign-in.
class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({this.systemLogin = false, super.key});
  final bool systemLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = TextButton.styleFrom(
      foregroundColor: theme.colorScheme.onSurfaceVariant,
      textStyle: theme.textTheme.labelSmall,
      minimumSize: const Size(48, 48),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        TextButton(
          style: style,
          onPressed: () => context.push(AppRoutes.privacy),
          child: Text(context.l10n.privacyTitle),
        ),
        TextButton(
          style: style,
          onPressed: () => showAppLicenses(context),
          child: Text(context.l10n.componentLicensesTitle),
        ),
        // Keep explicit central authentication reachable on Android as well as
        // web, without restoring the large school/settings/QR buttons.
        PopupMenuButton<String>(
          tooltip: systemLogin
              ? context.l10n.schoolLoginAction
              : context.l10n.systemLoginAction,
          icon: Icon(
            Icons.more_horiz,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onSelected: (_) =>
              context.go(systemLogin ? AppRoutes.login : AppRoutes.systemLogin),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'login',
              child: Text(
                systemLogin
                    ? context.l10n.schoolLoginAction
                    : context.l10n.systemLoginAction,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
