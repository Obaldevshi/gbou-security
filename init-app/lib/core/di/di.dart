import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile_template/core/di/di_module.dart';
import 'package:mobile_template/core/interceptors/auth_interceptor.dart';
import 'package:mobile_template/core/services/connectivity_service.dart';
import 'package:mobile_template/core/services/locale_service.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/core/services/theme_service.dart';
import 'package:mobile_template/data/datasources/remote/api_service.dart';
import 'package:mobile_template/data/repositories/auth_repository_impl.dart';
import 'package:mobile_template/domain/repositories/auth_repository.dart';
import 'package:mobile_template/features/auth/data/datasources/auth_api_data_source.dart';
import 'package:mobile_template/features/auth/data/repositories/auth_session_repository_impl.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:mobile_template/features/auth/domain/usecases/login_usecase.dart';
import 'package:mobile_template/features/auth/domain/usecases/logout_usecase.dart';
import 'package:mobile_template/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:mobile_template/features/auth/presentation/pages/login/bloc/login_bloc.dart';
import 'package:mobile_template/features/auth/presentation/pages/splash/bloc/session_bootstrap_cubit.dart';
import 'package:mobile_template/features/profile/domain/usecases/change_password_usecase.dart';
import 'package:mobile_template/features/profile/domain/usecases/delete_account_usecase.dart';
import 'package:mobile_template/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:mobile_template/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:mobile_template/features/profile/presentation/pages/bloc/profile_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

class _RuntimeDiModule extends DiModule {}

Future<void> configureDependencies() async {
  final module = _RuntimeDiModule();
  final preferences = await module.sharedPreferences();
  final secureStorage = module.secureStorage();
  final sessionService = await SessionService.create(
    secureStorage,
    preferences,
  );

  getIt
    ..registerLazySingleton<Connectivity>(module.connectivity)
    ..registerSingleton<SharedPreferences>(preferences)
    ..registerSingleton<FlutterSecureStorage>(secureStorage)
    ..registerSingleton<SessionService>(sessionService)
    ..registerSingleton<String>(module.baseUrl(), instanceName: 'baseUrl')
    ..registerLazySingleton<GlobalKey<NavigatorState>>(
      module.navigatorKey,
      instanceName: 'navigatorKey',
    )
    ..registerLazySingleton<ConnectivityService>(
      () => ConnectivityService(getIt<Connectivity>())..init(),
      dispose: (service) => service.dispose(),
    )
    ..registerLazySingleton<LocaleService>(
      () => LocaleService(preferences)..init(),
    )
    ..registerLazySingleton<ThemeService>(
      () => ThemeService(preferences)..init(),
    )
    ..registerLazySingleton<AuthInterceptor>(
      () => AuthInterceptor(sessionService),
    )
    ..registerLazySingleton<Dio>(() => module.dio(getIt<AuthInterceptor>()))
    ..registerLazySingleton<AuthApiDataSource>(
      () => AuthApiDataSource(
        getIt<Dio>(),
        baseUrl: getIt<String>(instanceName: 'baseUrl'),
      ),
    )
    ..registerLazySingleton<AuthSessionRepository>(
      () =>
          AuthSessionRepositoryImpl(getIt<AuthApiDataSource>(), sessionService),
    )
    ..registerFactory<LoginUsecase>(
      () => LoginUsecase(getIt<AuthSessionRepository>()),
    )
    ..registerFactory<LogoutUsecase>(
      () => LogoutUsecase(getIt<AuthSessionRepository>()),
    )
    ..registerFactory<RestoreSessionUsecase>(
      () => RestoreSessionUsecase(getIt<AuthSessionRepository>()),
    )
    ..registerFactory<LoginBloc>(
      () => LoginBloc(loginUsecase: getIt<LoginUsecase>()),
    )
    ..registerFactory<SessionBootstrapCubit>(
      () => SessionBootstrapCubit(getIt<RestoreSessionUsecase>()),
    )
    ..registerLazySingleton<ApiService>(
      () => ApiService(
        getIt<Dio>(),
        baseUrl: getIt<String>(instanceName: 'baseUrl'),
      ),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(getIt<ApiService>(), sessionService),
    )
    ..registerFactory<GetProfileUsecase>(
      () => GetProfileUsecase(getIt<AuthRepository>()),
    )
    ..registerFactory<UpdateProfileUsecase>(
      () => UpdateProfileUsecase(getIt<AuthRepository>()),
    )
    ..registerFactory<DeleteAccountUsecase>(
      () => DeleteAccountUsecase(getIt<AuthRepository>()),
    )
    ..registerFactory<ChangePasswordUsecase>(
      () => ChangePasswordUsecase(getIt<AuthRepository>()),
    )
    ..registerFactory<ProfileBloc>(
      () => ProfileBloc(
        getIt<GetProfileUsecase>(),
        getIt<UpdateProfileUsecase>(),
        getIt<DeleteAccountUsecase>(),
        getIt<ChangePasswordUsecase>(),
      ),
    );
}
