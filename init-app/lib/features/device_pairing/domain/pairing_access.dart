import 'package:mobile_template/features/auth/domain/entities/current_user.dart';
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';

bool canManageDevicePairing(CurrentUser? user) =>
    user != null &&
    user.isActive &&
    !user.mustChangePassword &&
    const [UserRole.schoolAdmin, UserRole.superAdmin].contains(user.role);
