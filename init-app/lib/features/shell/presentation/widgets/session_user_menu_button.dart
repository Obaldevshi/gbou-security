import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/domain/usecases/logout_usecase.dart';
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';

class SessionUserMenuButton extends StatelessWidget {
  const SessionUserMenuButton({this.showName = false, super.key});

  final bool showName;

  @override
  Widget build(BuildContext context) {
    final user = getIt<SessionService>().currentUser;
    return Material(
      type: MaterialType.transparency,
      child: PopupMenuButton<String>(
        tooltip: context.l10n.userMenu,
        onSelected: (value) async {
          if (value == 'profile') {
            final route = switch (user?.role) {
              UserRole.superAdmin => AppRoutes.systemProfile,
              UserRole.schoolAdmin => AppRoutes.schoolProfile,
              UserRole.teacher => AppRoutes.teacherProfile,
              UserRole.guard => AppRoutes.guardProfile,
              null => AppRoutes.login,
            };
            if (context.mounted) context.go(route);
          }
          if (value == 'logout') await getIt<LogoutUsecase>()();
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                user?.fullName ?? user?.login ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'profile',
            child: Row(
              children: [
                const Icon(Icons.manage_accounts_outlined),
                const SizedBox(width: AppDimensions.spaceS),
                Text(context.l10n.profile),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                const Icon(Icons.logout_rounded),
                const SizedBox(width: AppDimensions.spaceS),
                Text(context.l10n.logout),
              ],
            ),
          ),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppDimensions.minTouchTarget,
            minHeight: AppDimensions.minTouchTarget,
          ),
          child: Semantics(
            button: true,
            label: context.l10n.userMenu,
            child: Padding(
              padding: AppDimensions.paddingAllS,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_circle_outlined),
                  if (showName) ...[
                    const SizedBox(width: AppDimensions.spaceS),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        user?.fullName ?? user?.login ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
