import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/role_loading/role_destination.dart';
import 'package:mobile_template/app/role_loading/roles/guard_role_module.dart'
    as guard;
import 'package:mobile_template/app/role_loading/roles/school_admin_role_module.dart'
    as school_admin;
import 'package:mobile_template/app/role_loading/roles/super_admin_role_module.dart'
    as super_admin;
import 'package:mobile_template/app/role_loading/roles/teacher_role_module.dart'
    as teacher;
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';

Future<void> loadRoleModule(UserRole role) async {}

Future<void> preloadFastRoleModules() async {}

Widget buildRoleDestination(
  UserRole role,
  RoleDestination destination, {
  StatefulNavigationShell? navigationShell,
}) => switch (role) {
  UserRole.teacher => teacher.buildTeacherDestination(
    destination,
    navigationShell: navigationShell,
  ),
  UserRole.guard => guard.buildGuardDestination(destination),
  UserRole.schoolAdmin => school_admin.buildSchoolAdminDestination(destination),
  UserRole.superAdmin => super_admin.buildSuperAdminDestination(destination),
};
