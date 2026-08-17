abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const unsupportedRole = '/unsupported-role';
  static const teacherRequest = '/teacher/request';
  static const teacherActive = '/teacher/active';
  static const teacherHistory = '/teacher/history';
  static const teacherStudents = '/teacher/students';
  static const guardQueue = '/guard/queue';
  static const systemSchools = '/system/schools';
  static const systemSchoolAdmins = '/system/school-admins';
  static const schoolClasses = '/school/classes';
  static const schoolStudents = '/school/students';
  static const schoolTeachers = '/school/teachers';
  static const schoolGuards = '/school/guards';
  static const schoolRequests = '/school/requests';
  static const teacherProfile = '/teacher/profile';
  static const guardProfile = '/guard/profile';
  static const systemProfile = '/system/profile';
  static const schoolProfile = '/school/profile';
  static const requiredPasswordChange = '/change-password-required';
  static const systemAudit = '/system/audit';
  static const schoolAudit = '/school/audit';
  static const systemReports = '/system/reports';
  static const schoolReports = '/school/reports';

  // Kept only so deferred template profile code continues to compile.
  static const editProfile = '/profile/edit';
}
