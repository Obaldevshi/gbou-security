// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:connectivity_plus/connectivity_plus.dart' as _i895;
import 'package:dio/dio.dart' as _i361;
import 'package:flutter/material.dart' as _i409;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:mobile_template/core/di/di_module.dart' as _i583;
import 'package:mobile_template/core/interceptors/auth_interceptor.dart'
    as _i508;
import 'package:mobile_template/core/services/connectivity_service.dart'
    as _i112;
import 'package:mobile_template/core/services/locale_service.dart' as _i997;
import 'package:mobile_template/core/services/session_service.dart' as _i922;
import 'package:mobile_template/core/services/theme_service.dart' as _i940;
import 'package:mobile_template/data/datasources/remote/api_service.dart'
    as _i1037;
import 'package:mobile_template/data/repositories/auth_repository_impl.dart'
    as _i134;
import 'package:mobile_template/data/repositories/main_repository_impl.dart'
    as _i602;
import 'package:mobile_template/domain/repositories/auth_repository.dart'
    as _i886;
import 'package:mobile_template/domain/repositories/main_repository.dart'
    as _i293;
import 'package:mobile_template/features/auth/domain/usecases/login_usecase.dart'
    as _i290;
import 'package:mobile_template/features/auth/domain/usecases/register_usecase.dart'
    as _i759;
import 'package:mobile_template/features/auth/presentation/pages/login/bloc/login_bloc.dart'
    as _i765;
import 'package:mobile_template/features/auth/presentation/pages/register/bloc/register_bloc.dart'
    as _i321;
import 'package:mobile_template/features/category/domain/usecases/create_category_usecase.dart'
    as _i406;
import 'package:mobile_template/features/category/domain/usecases/delete_category_usecase.dart'
    as _i236;
import 'package:mobile_template/features/category/domain/usecases/get_category_usecase.dart'
    as _i513;
import 'package:mobile_template/features/category/domain/usecases/update_category_usecase.dart'
    as _i164;
import 'package:mobile_template/features/category/presentation/pages/bloc/category_bloc.dart'
    as _i949;
import 'package:mobile_template/features/profile/domain/usecases/change_password_usecase.dart'
    as _i61;
import 'package:mobile_template/features/profile/domain/usecases/delete_account_usecase.dart'
    as _i754;
import 'package:mobile_template/features/profile/domain/usecases/get_profile_usecase.dart'
    as _i789;
import 'package:mobile_template/features/profile/domain/usecases/update_profile_usecase.dart'
    as _i802;
import 'package:mobile_template/features/profile/presentation/pages/bloc/profile_bloc.dart'
    as _i361;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final diModule = _$DiModule();
    gh.lazySingleton<_i895.Connectivity>(() => diModule.connectivity());
    await gh.lazySingletonAsync<_i460.SharedPreferences>(
      () => diModule.sharedPreferences(),
      preResolve: true,
    );
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => diModule.secureStorage(),
    );
    gh.lazySingleton<_i997.LocaleService>(
      () => _i997.LocaleService(gh<_i460.SharedPreferences>())..init(),
    );
    gh.lazySingleton<_i940.ThemeService>(
      () => _i940.ThemeService(gh<_i460.SharedPreferences>())..init(),
    );
    gh.factory<String>(() => diModule.baseUrl(), instanceName: 'baseUrl');
    gh.lazySingleton<_i409.GlobalKey<_i409.NavigatorState>>(
      () => diModule.navigatorKey(),
      instanceName: 'navigatorKey',
    );
    await gh.lazySingletonAsync<_i922.SessionService>(
      () => _i922.SessionService.create(
        gh<_i558.FlutterSecureStorage>(),
        gh<_i460.SharedPreferences>(),
      ),
      preResolve: true,
    );
    gh.lazySingleton<_i112.ConnectivityService>(
      () => _i112.ConnectivityService(gh<_i895.Connectivity>())..init(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i508.AuthInterceptor>(
      () => _i508.AuthInterceptor(gh<_i922.SessionService>()),
    );
    gh.lazySingleton<_i361.Dio>(
      () => diModule.dio(gh<_i508.AuthInterceptor>()),
    );
    gh.lazySingleton<_i1037.ApiService>(
      () => _i1037.ApiService(
        gh<_i361.Dio>(),
        baseUrl: gh<String>(instanceName: 'baseUrl'),
      ),
    );
    gh.lazySingleton<_i886.AuthRepository>(
      () => _i134.AuthRepositoryImpl(
        gh<_i1037.ApiService>(),
        gh<_i922.SessionService>(),
      ),
    );
    gh.factory<_i290.LoginUsecase>(
      () => _i290.LoginUsecase(gh<_i886.AuthRepository>()),
    );
    gh.factory<_i759.RegisterUsecase>(
      () => _i759.RegisterUsecase(gh<_i886.AuthRepository>()),
    );
    gh.factory<_i61.ChangePasswordUsecase>(
      () => _i61.ChangePasswordUsecase(gh<_i886.AuthRepository>()),
    );
    gh.factory<_i754.DeleteAccountUsecase>(
      () => _i754.DeleteAccountUsecase(gh<_i886.AuthRepository>()),
    );
    gh.factory<_i789.GetProfileUsecase>(
      () => _i789.GetProfileUsecase(gh<_i886.AuthRepository>()),
    );
    gh.factory<_i802.UpdateProfileUsecase>(
      () => _i802.UpdateProfileUsecase(gh<_i886.AuthRepository>()),
    );
    gh.factory<_i361.ProfileBloc>(
      () => _i361.ProfileBloc(
        gh<_i789.GetProfileUsecase>(),
        gh<_i802.UpdateProfileUsecase>(),
        gh<_i754.DeleteAccountUsecase>(),
        gh<_i61.ChangePasswordUsecase>(),
      ),
    );
    gh.lazySingleton<_i293.MainRepository>(
      () => _i602.MainRepositoryImpl(gh<_i1037.ApiService>()),
    );
    gh.factory<_i406.CreateCategoryUseCase>(
      () => _i406.CreateCategoryUseCase(gh<_i293.MainRepository>()),
    );
    gh.factory<_i236.DeleteCategoryUsecase>(
      () => _i236.DeleteCategoryUsecase(gh<_i293.MainRepository>()),
    );
    gh.factory<_i513.GetCategoryUsecase>(
      () => _i513.GetCategoryUsecase(gh<_i293.MainRepository>()),
    );
    gh.factory<_i164.UpdateCategoryUsecase>(
      () => _i164.UpdateCategoryUsecase(gh<_i293.MainRepository>()),
    );
    gh.factory<_i321.RegisterBloc>(
      () => _i321.RegisterBloc(gh<_i759.RegisterUsecase>()),
    );
    gh.factory<_i765.LoginBloc>(
      () => _i765.LoginBloc(loginUsecase: gh<_i290.LoginUsecase>()),
    );
    gh.factory<_i949.CategoryBloc>(
      () => _i949.CategoryBloc(
        gh<_i513.GetCategoryUsecase>(),
        gh<_i406.CreateCategoryUseCase>(),
        gh<_i164.UpdateCategoryUsecase>(),
        gh<_i236.DeleteCategoryUsecase>(),
      ),
    );
    return this;
  }
}

class _$DiModule extends _i583.DiModule {}
