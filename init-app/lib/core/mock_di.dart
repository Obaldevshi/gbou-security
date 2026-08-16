import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/data/repositories/mock_auth_repository.dart';
import 'package:mobile_template/data/repositories/mock_main_repository.dart';
import 'package:mobile_template/domain/repositories/auth_repository.dart';
import 'package:mobile_template/domain/repositories/main_repository.dart';
import 'package:mobile_template/features/auth/data/repositories/mock_auth_session_repository.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:mobile_template/features/exit_requests/data/repositories/mock_exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';
import 'package:mobile_template/features/school_management/data/repositories/mock_school_management_repository.dart';
import 'package:mobile_template/features/school_management/domain/repositories/school_management_repository.dart';
import 'package:mobile_template/features/school_console/data/mock_school_classes_repository.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_classes_repository.dart';
import 'package:mobile_template/features/school_console/data/mock_school_students_repository.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_students_repository.dart';
import 'package:mobile_template/features/school_console/data/mock_school_teachers_repository.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_teachers_repository.dart';

Future<void> configureMockRepositories() async {
  if (getIt.isRegistered<AuthRepository>()) {
    await getIt.unregister<AuthRepository>();
  }
  getIt.registerLazySingleton<AuthRepository>(
    () => MockAuthRepository(getIt<SessionService>()),
  );

  if (getIt.isRegistered<AuthSessionRepository>()) {
    await getIt.unregister<AuthSessionRepository>();
  }
  getIt.registerLazySingleton<AuthSessionRepository>(
    () => MockAuthSessionRepository(getIt<SessionService>()),
  );

  if (getIt.isRegistered<MainRepository>()) {
    await getIt.unregister<MainRepository>();
  }
  getIt.registerLazySingleton<MainRepository>(() => MockMainRepository());

  if (getIt.isRegistered<ExitRequestRepository>()) {
    await getIt.unregister<ExitRequestRepository>();
  }
  getIt.registerLazySingleton<ExitRequestRepository>(
    MockExitRequestRepository.new,
  );

  if (getIt.isRegistered<SchoolManagementRepository>()) {
    await getIt.unregister<SchoolManagementRepository>();
  }
  getIt.registerLazySingleton<SchoolManagementRepository>(
    MockSchoolManagementRepository.new,
  );
  if (getIt.isRegistered<SchoolClassesRepository>()) {
    await getIt.unregister<SchoolClassesRepository>();
  }
  getIt.registerLazySingleton<SchoolClassesRepository>(
    MockSchoolClassesRepository.new,
  );
  if (getIt.isRegistered<SchoolStudentsRepository>()) {
    await getIt.unregister<SchoolStudentsRepository>();
  }
  getIt.registerLazySingleton<SchoolStudentsRepository>(
    MockSchoolStudentsRepository.new,
  );
  if (getIt.isRegistered<SchoolTeachersRepository>()) {
    await getIt.unregister<SchoolTeachersRepository>();
  }
  getIt.registerLazySingleton<SchoolTeachersRepository>(
    MockSchoolTeachersRepository.new,
  );
}
