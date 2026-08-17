import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminAppBar.school({
    required this.sectionTitle,
    this.bottom,
    super.key,
  }) : schoolOnly = true;

  const AdminAppBar.system({
    required this.sectionTitle,
    this.bottom,
    super.key,
  }) : schoolOnly = false;

  final String sectionTitle;
  final bool schoolOnly;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final foreground = colors.onPrimary;
    final destinations = schoolOnly
        ? _schoolDestinations
        : _systemDestinations;
    final compact = width < (schoolOnly ? 900 : 760);

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: colors.primary,
      foregroundColor: foreground,
      iconTheme: IconThemeData(color: foreground),
      actionsIconTheme: IconThemeData(color: foreground),
      leading: IconButton(
        tooltip: 'Главная',
        onPressed: () => context.go(
          schoolOnly ? AppRoutes.schoolClasses : AppRoutes.systemSchools,
        ),
        icon: const Icon(Icons.home_rounded),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schoolOnly ? 'Управление школой' : 'Центр управления',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            sectionTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground.withValues(alpha: .88),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        if (compact)
          PopupMenuButton<String>(
            tooltip: 'Разделы',
            icon: Icon(Icons.menu_rounded, color: foreground),
            onSelected: (route) => context.go(route),
            itemBuilder: (_) => destinations
                .map(
                  (item) => PopupMenuItem(
                    value: item.route,
                    child: ListTile(
                      leading: Icon(item.icon),
                      title: Text(item.label),
                    ),
                  ),
                )
                .toList(),
          )
        else if (schoolOnly)
          for (final item in destinations)
            IconButton(
              tooltip: item.label,
              onPressed: () => context.go(item.route),
              icon: Icon(item.icon, color: foreground),
            )
        else
          for (final item in destinations)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: foreground),
              onPressed: () => context.go(item.route),
              icon: Icon(item.icon),
              label: Text(item.label),
            ),
        SessionUserMenuButton(
          showName: width >= (schoolOnly ? 1180 : 980),
          foregroundColor: foreground,
        ),
        const SizedBox(width: 8),
      ],
      bottom: bottom,
    );
  }
}

class _AdminDestination {
  const _AdminDestination(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

const _systemDestinations = [
  _AdminDestination('Школы', Icons.apartment_rounded, AppRoutes.systemSchools),
  _AdminDestination(
    'Администраторы',
    Icons.manage_accounts_rounded,
    AppRoutes.systemSchoolAdmins,
  ),
  _AdminDestination('Отчёты', Icons.analytics_outlined, AppRoutes.systemReports),
  _AdminDestination('Аудит', Icons.history_rounded, AppRoutes.systemAudit),
];

const _schoolDestinations = [
  _AdminDestination('Корпуса', Icons.apartment_rounded, AppRoutes.schoolBuildings),
  _AdminDestination('Классы', Icons.class_outlined, AppRoutes.schoolClasses),
  _AdminDestination('Ученики', Icons.people_alt_outlined, AppRoutes.schoolStudents),
  _AdminDestination('Учителя', Icons.co_present_outlined, AppRoutes.schoolTeachers),
  _AdminDestination('Охрана', Icons.shield_outlined, AppRoutes.schoolGuards),
  _AdminDestination('Заявки', Icons.fact_check_outlined, AppRoutes.schoolRequests),
  _AdminDestination('Отчёты', Icons.analytics_outlined, AppRoutes.schoolReports),
  _AdminDestination('Аудит', Icons.history_rounded, AppRoutes.schoolAudit),
];
