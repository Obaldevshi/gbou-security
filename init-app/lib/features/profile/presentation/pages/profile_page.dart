import 'package:flutter/material.dart';
import 'package:mobile_template/core/utils/app_navigator.dart';
import 'package:mobile_template/features/account_deletion/domain/account_deletion.dart';
import 'package:mobile_template/features/account_deletion/presentation/account_deletion_cubit.dart';
import 'package:mobile_template/features/account_deletion/presentation/account_deletion_page.dart';
import 'package:mobile_template/core/utils/app_licenses.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/core/services/theme_service.dart';
import 'package:mobile_template/core/utils/package_info_utils.dart';
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';
import 'package:mobile_template/features/auth/presentation/pages/pin/pin_pages.dart';
import 'package:mobile_template/features/profile/domain/dto/profile_dto.dart';
import 'package:mobile_template/features/profile/presentation/pages/bloc/profile_bloc.dart';
import 'package:mobile_template/features/profile/presentation/widgets/change_password_bottom_sheet.dart';
import 'package:mobile_template/features/profile/presentation/widgets/profile_action_tile.dart';
import 'package:mobile_template/features/profile/presentation/widgets/profile_header_card.dart';
import 'package:mobile_template/presentation/widgets/common/confirmation_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/error_dialog.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';
import 'package:mobile_template/presentation/widgets/layout/scroll_shell.dart';
import 'package:mobile_template/presentation/widgets/ui_kit/ui_kit_section_title.dart';
import 'package:mobile_template/presentation/widgets/ui_kit/ui_kit_theme_switcher.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = getIt<ThemeService>();
    final sessionService = getIt<SessionService>();

    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is GetProfileFailure) {
          ErrorDialog.show(context, state.failure);
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        final isLoading = state is GetProfileLoading;
        final profile = state.data.profile;

        if (!isLoading && profile == null) {
          return Center(child: Text(context.l10n.error));
        }

        return ScrollShell(
          isLoading: isLoading,
          title: context.l10n.profile,
          leading: IconButton(
            tooltip: 'Назад',
            onPressed: () =>
                context.go(_homeRoute(sessionService.currentUser?.role)),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          headerContent: isLoading
              ? const SizedBox.shrink()
              : Text(
                  profile!.login,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
          body: isLoading
              ? const SizedBox.shrink()
              : AppLayoutItemBuilder<Widget>(
                  narrow: () => _buildNarrow(
                    context,
                    profile!,
                    themeService,
                    sessionService,
                  ),
                  wide: () => _buildWide(
                    context,
                    profile!,
                    themeService,
                    sessionService,
                  ),
                )(context),
        );
      },
    );
  }

  Widget _buildNarrow(
    BuildContext context,
    ProfileDto profile,
    ThemeService themeService,
    SessionService sessionService,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileHeaderCard(profile: profile),
        const SizedBox(height: AppDimensions.spaceL),
        _buildAccount(context, profile),
        const SizedBox(height: AppDimensions.spaceS),
        _buildAppearance(context, themeService),
        const SizedBox(height: AppDimensions.spaceL),
        _buildVersion(context),
        const SizedBox(height: AppDimensions.spaceXL),
        _buildLogout(context, sessionService),
      ],
    );
  }

  Widget _buildWide(
    BuildContext context,
    ProfileDto profile,
    ThemeService themeService,
    SessionService sessionService,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileHeaderCard(profile: profile),
              const SizedBox(height: AppDimensions.spaceL),
              _buildVersion(context),
              const SizedBox(height: AppDimensions.spaceL),
              _buildLogout(context, sessionService),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spaceL),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAccount(context, profile),
              const SizedBox(height: AppDimensions.spaceL),
              _buildAppearance(context, themeService),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccount(BuildContext context, ProfileDto profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiKitSectionTitle(title: context.l10n.profileSectionAccount),
        if (!getIt<SessionService>().isDemo &&
            const [
              UserRole.schoolAdmin,
              UserRole.superAdmin,
            ].contains(getIt<SessionService>().currentUser?.role))
          ProfileActionTile(
            icon: Icons.qr_code_scanner,
            title: context.l10n.qrScannerTitle,
            subtitle: '',
            onTap: () => context.push(AppRoutes.scanDevice),
          ),
        ProfileActionTile(
          icon: Icons.delete_forever_outlined,
          title: context.l10n.accountDeletionTitle,
          subtitle: '',
          onTap: () async {
            final session = getIt<SessionService>();
            final repository = getIt<AccountDeletionRepository>();
            final deleted = await appNavigator(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (_) => AccountDeletionCubit(repository)..load(),
                  child: const AccountDeletionPage(),
                ),
              ),
            );
            if (deleted == true) await session.clearSession();
          },
        ),
        ProfileActionTile(
          icon: Icons.privacy_tip_outlined,
          title: context.l10n.privacyTitle,
          subtitle: '',
          onTap: () => context.push(AppRoutes.privacy),
        ),
        ProfileActionTile(
          icon: Icons.description_outlined,
          title: 'Лицензии компонентов',
          subtitle: 'Шрифты и открытое программное обеспечение',
          onTap: () => showAppLicenses(context),
        ),
        ProfileActionTile(
          icon: Icons.badge_outlined,
          title: profile.login,
          subtitle: _roleLabel(profile.role),
          onTap: () {},
        ),
        ProfileActionTile(
          icon: Icons.security_outlined,
          title: context.l10n.changePassword,
          subtitle: context.l10n.security,
          onTap: () => ChangePasswordBottomSheet.show(context),
        ),
        if (getIt<SessionService>().supportsPin)
          ProfileActionTile(
            icon: Icons.pin_outlined,
            title: 'Быстрый вход по PIN',
            subtitle: getIt<SessionService>().hasPinConfigured
                ? 'Включён на этом устройстве'
                : 'Не настроен',
            onTap: () => PinSettingsSheet.show(context),
          ),
      ],
    );
  }

  String _roleLabel(String role) => switch (role) {
    'super_admin' => 'Главный администратор',
    'school_admin' => 'Администратор школы',
    'teacher' => 'Учитель',
    'guard' => 'Охранник',
    _ => 'Пользователь',
  };

  String _homeRoute(UserRole? role) => switch (role) {
    UserRole.superAdmin => AppRoutes.systemSchools,
    UserRole.schoolAdmin => AppRoutes.schoolClasses,
    UserRole.teacher => AppRoutes.teacherRequest,
    UserRole.guard => AppRoutes.guardQueue,
    null => AppRoutes.login,
  };

  Widget _buildAppearance(BuildContext context, ThemeService themeService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiKitSectionTitle(title: context.l10n.homeSectionAppearance),
        UiKitThemeSwitcher(themeService: themeService),
      ],
    );
  }

  Widget _buildVersion(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder(
      future: PackageInfoUtils.appVersion(),
      builder: (context, snapshot) => GlassSurfaceCard(
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppDimensions.spaceM),
            Text(
              '${context.l10n.version} ${snapshot.data ?? '—'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogout(BuildContext context, SessionService sessionService) {
    return GlobalButton(
      text: context.l10n.logout,
      onPressed: () => _handleLogout(context, sessionService),
    );
  }

  Future<void> _handleLogout(
    BuildContext context,
    SessionService sessionService,
  ) async {
    final shouldLogout = await ConfirmationDialog.show(
      context,
      title: context.l10n.logout,
      content: context.l10n.logoutConfirmation,
      confirmText: context.l10n.logout,
      isDestructive: true,
    );

    if (shouldLogout == true) {
      await sessionService.clearSession();
    }
  }
}
