import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/data/repositories/mock_auth_repository.dart';
import 'package:mobile_template/data/repositories/mock_main_repository.dart';
import 'package:mobile_template/domain/repositories/auth_repository.dart';
import 'package:mobile_template/domain/repositories/main_repository.dart';

Future<void> configureMockRepositories() async {
  if (getIt.isRegistered<AuthRepository>()) {
    await getIt.unregister<AuthRepository>();
  }
  getIt.registerLazySingleton<AuthRepository>(
    () => MockAuthRepository(getIt<SessionService>()),
  );

  if (getIt.isRegistered<MainRepository>()) {
    await getIt.unregister<MainRepository>();
  }
  getIt.registerLazySingleton<MainRepository>(() => MockMainRepository());
}
