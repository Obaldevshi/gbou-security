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
import 'package:mobile_template/features/auth/data/datasources/auth_api_data_source.dart'
    as _i672;
import 'package:mobile_template/features/auth/data/repositories/auth_session_repository_impl.dart'
    as _i602;
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart'
    as _i144;
import 'package:mobile_template/features/auth/domain/usecases/login_usecase.dart'
    as _i290;
import 'package:mobile_template/features/auth/domain/usecases/logout_usecase.dart'
    as _i714;
import 'package:mobile_template/features/auth/domain/usecases/register_usecase.dart'
    as _i759;
import 'package:mobile_template/features/auth/domain/usecases/restore_session_usecase.dart'
    as _i593;
import 'package:mobile_template/features/auth/presentation/pages/login/bloc/login_bloc.dart'
    as _i765;
import 'package:mobile_template/features/auth/presentation/pages/register/bloc/register_bloc.dart'
    as _i321;
import 'package:mobile_template/features/auth/presentation/pages/splash/bloc/session_bootstrap_cubit.dart'
    as _i863;
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
import 'package:mobile_template/features/exit_requests/data/datasources/exit_request_api_data_source.dart'
    as _i698;
import 'package:mobile_template/features/exit_requests/data/repositories/exit_request_repository_impl.dart'
    as _i343;
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart'
    as _i199;
import 'package:mobile_template/features/exit_requests/domain/usecases/create_exit_request_usecase.dart'
    as _i800;
import 'package:mobile_template/features/exit_requests/domain/usecases/get_class_students_usecase.dart'
    as _i336;
import 'package:mobile_template/features/exit_requests/domain/usecases/get_guard_queue_usecase.dart'
    as _i1004;
import 'package:mobile_template/features/exit_requests/domain/usecases/get_school_exit_requests_usecase.dart'
    as _i79;
import 'package:mobile_template/features/exit_requests/domain/usecases/get_teacher_classes_usecase.dart'
    as _i513;
import 'package:mobile_template/features/exit_requests/domain/usecases/get_teacher_exit_requests_usecase.dart'
    as _i12;
import 'package:mobile_template/features/exit_requests/domain/usecases/release_exit_request_usecase.dart'
    as _i520;
import 'package:mobile_template/features/exit_requests/presentation/pages/guard_queue/guard_queue_cubit.dart'
    as _i260;
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_request/teacher_request_cubit.dart'
    as _i1034;
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_requests/teacher_requests_cubit.dart'
    as _i1043;
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
import 'package:mobile_template/features/school_console/data/school_classes_data.dart'
    as _i921;
import 'package:mobile_template/features/school_console/data/school_guards_data.dart'
    as _i25;
import 'package:mobile_template/features/school_console/data/school_students_data.dart'
    as _i951;
import 'package:mobile_template/features/school_console/data/school_teachers_data.dart'
    as _i599;
import 'package:mobile_template/features/school_console/data/teacher_students_data.dart'
    as _i186;
import 'package:mobile_template/features/school_console/domain/repositories/school_classes_repository.dart'
    as _i51;
import 'package:mobile_template/features/school_console/domain/repositories/school_guards_repository.dart'
    as _i593;
import 'package:mobile_template/features/school_console/domain/repositories/school_students_repository.dart'
    as _i916;
import 'package:mobile_template/features/school_console/domain/repositories/school_teachers_repository.dart'
    as _i898;
import 'package:mobile_template/features/school_console/domain/repositories/teacher_students_repository.dart'
    as _i921;
import 'package:mobile_template/features/school_console/domain/usecases/guard_usecases.dart'
    as _i117;
import 'package:mobile_template/features/school_console/domain/usecases/school_class_usecases.dart'
    as _i117;
import 'package:mobile_template/features/school_console/domain/usecases/student_usecases.dart'
    as _i648;
import 'package:mobile_template/features/school_console/domain/usecases/teacher_student_usecases.dart'
    as _i39;
import 'package:mobile_template/features/school_console/domain/usecases/teacher_usecases.dart'
    as _i992;
import 'package:mobile_template/features/school_console/presentation/school_classes_cubit.dart'
    as _i381;
import 'package:mobile_template/features/school_console/presentation/school_guards_cubit.dart'
    as _i334;
import 'package:mobile_template/features/school_console/presentation/school_requests_cubit.dart'
    as _i184;
import 'package:mobile_template/features/school_console/presentation/school_students_cubit.dart'
    as _i878;
import 'package:mobile_template/features/school_console/presentation/school_teachers_cubit.dart'
    as _i88;
import 'package:mobile_template/features/school_console/presentation/teacher_students_cubit.dart'
    as _i570;
import 'package:mobile_template/features/school_management/data/datasources/school_management_api_data_source.dart'
    as _i323;
import 'package:mobile_template/features/school_management/data/repositories/school_management_repository_impl.dart'
    as _i830;
import 'package:mobile_template/features/school_management/domain/repositories/school_management_repository.dart'
    as _i778;
import 'package:mobile_template/features/school_management/domain/usecases/school_usecases.dart'
    as _i194;
import 'package:mobile_template/features/school_management/presentation/cubit/school_admins_cubit.dart'
    as _i629;
import 'package:mobile_template/features/school_management/presentation/cubit/school_management_cubit.dart'
    as _i794;
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
    await gh.lazySingletonAsync<_i922.SessionService>(
      () => _i922.SessionService.create(
        gh<_i558.FlutterSecureStorage>(),
        gh<_i460.SharedPreferences>(),
      ),
      preResolve: true,
    );
    gh.factory<String>(() => diModule.baseUrl(), instanceName: 'baseUrl');
    gh.lazySingleton<_i409.GlobalKey<_i409.NavigatorState>>(
      () => diModule.navigatorKey(),
      instanceName: 'navigatorKey',
    );
    gh.lazySingleton<_i112.ConnectivityService>(
      () => _i112.ConnectivityService(gh<_i895.Connectivity>())..init(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i997.LocaleService>(
      () => _i997.LocaleService(gh<_i460.SharedPreferences>())..init(),
    );
    gh.lazySingleton<_i940.ThemeService>(
      () => _i940.ThemeService(gh<_i460.SharedPreferences>())..init(),
    );
    gh.lazySingleton<_i508.AuthInterceptor>(
      () => _i508.AuthInterceptor(gh<_i922.SessionService>()),
    );
    gh.lazySingleton<_i361.Dio>(
      () => diModule.dio(gh<_i508.AuthInterceptor>()),
    );
    gh.lazySingleton<_i323.SchoolManagementApiDataSource>(
      () => _i323.SchoolManagementApiDataSource(
        gh<_i361.Dio>(),
        gh<String>(instanceName: 'baseUrl'),
      ),
    );
    gh.lazySingleton<_i1037.ApiService>(
      () => _i1037.ApiService(
        gh<_i361.Dio>(),
        baseUrl: gh<String>(instanceName: 'baseUrl'),
      ),
    );
    gh.lazySingleton<_i672.AuthApiDataSource>(
      () => _i672.AuthApiDataSource(
        gh<_i361.Dio>(),
        baseUrl: gh<String>(instanceName: 'baseUrl'),
      ),
    );
    gh.lazySingleton<_i698.ExitRequestApiDataSource>(
      () => _i698.ExitRequestApiDataSource(
        gh<_i361.Dio>(),
        baseUrl: gh<String>(instanceName: 'baseUrl'),
      ),
    );
    gh.lazySingleton<_i921.SchoolClassesApiDataSource>(
      () => _i921.SchoolClassesApiDataSource(
        gh<_i361.Dio>(),
        gh<String>(instanceName: 'baseUrl'),
      ),
    );
    gh.lazySingleton<_i25.SchoolGuardsApiDataSource>(
      () => _i25.SchoolGuardsApiDataSource(
        gh<_i361.Dio>(),
        gh<String>(instanceName: 'baseUrl'),
      ),
    );
    gh.lazySingleton<_i951.SchoolStudentsApiDataSource>(
      () => _i951.SchoolStudentsApiDataSource(
        gh<_i361.Dio>(),
        gh<String>(instanceName: 'baseUrl'),
      ),
    );
    gh.lazySingleton<_i599.SchoolTeachersApiDataSource>(
      () => _i599.SchoolTeachersApiDataSource(
        gh<_i361.Dio>(),
        gh<String>(instanceName: 'baseUrl'),
      ),
    );
    gh.lazySingleton<_i186.TeacherStudentsApiDataSource>(
      () => _i186.TeacherStudentsApiDataSource(
        gh<_i361.Dio>(),
        gh<String>(instanceName: 'baseUrl'),
      ),
    );
    gh.lazySingleton<_i778.SchoolManagementRepository>(
      () => _i830.SchoolManagementRepositoryImpl(
        gh<_i323.SchoolManagementApiDataSource>(),
      ),
    );
    gh.lazySingleton<_i199.ExitRequestRepository>(
      () =>
          _i343.ExitRequestRepositoryImpl(gh<_i698.ExitRequestApiDataSource>()),
    );
    gh.lazySingleton<_i921.TeacherStudentsRepository>(
      () => _i186.TeacherStudentsRepositoryImpl(
        gh<_i186.TeacherStudentsApiDataSource>(),
      ),
    );
    gh.lazySingleton<_i144.AuthSessionRepository>(
      () => _i602.AuthSessionRepositoryImpl(
        gh<_i672.AuthApiDataSource>(),
        gh<_i922.SessionService>(),
      ),
    );
    gh.factory<_i800.CreateExitRequestUsecase>(
      () => _i800.CreateExitRequestUsecase(gh<_i199.ExitRequestRepository>()),
    );
    gh.factory<_i336.GetClassStudentsUsecase>(
      () => _i336.GetClassStudentsUsecase(gh<_i199.ExitRequestRepository>()),
    );
    gh.factory<_i1004.GetGuardQueueUsecase>(
      () => _i1004.GetGuardQueueUsecase(gh<_i199.ExitRequestRepository>()),
    );
    gh.factory<_i513.GetTeacherClassesUsecase>(
      () => _i513.GetTeacherClassesUsecase(gh<_i199.ExitRequestRepository>()),
    );
    gh.factory<_i12.GetTeacherExitRequestsUsecase>(
      () =>
          _i12.GetTeacherExitRequestsUsecase(gh<_i199.ExitRequestRepository>()),
    );
    gh.factory<_i520.ReleaseExitRequestUsecase>(
      () => _i520.ReleaseExitRequestUsecase(gh<_i199.ExitRequestRepository>()),
    );
    gh.factory<_i194.GetSchoolsUsecase>(
      () => _i194.GetSchoolsUsecase(gh<_i778.SchoolManagementRepository>()),
    );
    gh.factory<_i194.CreateSchoolUsecase>(
      () => _i194.CreateSchoolUsecase(gh<_i778.SchoolManagementRepository>()),
    );
    gh.factory<_i194.UpdateSchoolUsecase>(
      () => _i194.UpdateSchoolUsecase(gh<_i778.SchoolManagementRepository>()),
    );
    gh.factory<_i194.SetSchoolStatusUsecase>(
      () =>
          _i194.SetSchoolStatusUsecase(gh<_i778.SchoolManagementRepository>()),
    );
    gh.factory<_i194.DeleteSchoolUsecase>(
      () => _i194.DeleteSchoolUsecase(gh<_i778.SchoolManagementRepository>()),
    );
    gh.factory<_i194.GetSchoolAdminsUsecase>(
      () =>
          _i194.GetSchoolAdminsUsecase(gh<_i778.SchoolManagementRepository>()),
    );
    gh.factory<_i194.CreateSchoolAdminUsecase>(
      () => _i194.CreateSchoolAdminUsecase(
        gh<_i778.SchoolManagementRepository>(),
      ),
    );
    gh.factory<_i194.UpdateSchoolAdminUsecase>(
      () => _i194.UpdateSchoolAdminUsecase(
        gh<_i778.SchoolManagementRepository>(),
      ),
    );
    gh.factory<_i194.SetSchoolAdminStatusUsecase>(
      () => _i194.SetSchoolAdminStatusUsecase(
        gh<_i778.SchoolManagementRepository>(),
      ),
    );
    gh.factory<_i194.DeleteSchoolAdminUsecase>(
      () => _i194.DeleteSchoolAdminUsecase(
        gh<_i778.SchoolManagementRepository>(),
      ),
    );
    gh.factory<_i194.GetSystemStatsUsecase>(
      () => _i194.GetSystemStatsUsecase(gh<_i778.SchoolManagementRepository>()),
    );
    gh.factory<_i290.LoginUsecase>(
      () => _i290.LoginUsecase(gh<_i144.AuthSessionRepository>()),
    );
    gh.factory<_i714.LogoutUsecase>(
      () => _i714.LogoutUsecase(gh<_i144.AuthSessionRepository>()),
    );
    gh.factory<_i593.RestoreSessionUsecase>(
      () => _i593.RestoreSessionUsecase(gh<_i144.AuthSessionRepository>()),
    );
    gh.lazySingleton<_i898.SchoolTeachersRepository>(
      () => _i599.SchoolTeachersRepositoryImpl(
        gh<_i599.SchoolTeachersApiDataSource>(),
      ),
    );
    gh.lazySingleton<_i293.MainRepository>(
      () => _i602.MainRepositoryImpl(gh<_i1037.ApiService>()),
    );
    gh.lazySingleton<_i51.SchoolClassesRepository>(
      () => _i921.SchoolClassesRepositoryImpl(
        gh<_i921.SchoolClassesApiDataSource>(),
      ),
    );
    gh.factory<_i1034.TeacherRequestCubit>(
      () => _i1034.TeacherRequestCubit(
        gh<_i513.GetTeacherClassesUsecase>(),
        gh<_i336.GetClassStudentsUsecase>(),
        gh<_i800.CreateExitRequestUsecase>(),
      ),
    );
    gh.factory<_i260.GuardQueueCubit>(
      () => _i260.GuardQueueCubit(
        gh<_i1004.GetGuardQueueUsecase>(),
        gh<_i520.ReleaseExitRequestUsecase>(),
      ),
    );
    gh.factory<_i79.GetSchoolExitRequestsUsecase>(
      () =>
          _i79.GetSchoolExitRequestsUsecase(gh<_i199.ExitRequestRepository>()),
    );
    gh.factory<_i184.SchoolRequestsCubit>(
      () => _i184.SchoolRequestsCubit(gh<_i79.GetSchoolExitRequestsUsecase>()),
    );
    gh.factory<_i765.LoginBloc>(
      () => _i765.LoginBloc(loginUsecase: gh<_i290.LoginUsecase>()),
    );
    gh.factory<_i992.GetManagedTeachersUsecase>(
      () =>
          _i992.GetManagedTeachersUsecase(gh<_i898.SchoolTeachersRepository>()),
    );
    gh.factory<_i992.CreateManagedTeacherUsecase>(
      () => _i992.CreateManagedTeacherUsecase(
        gh<_i898.SchoolTeachersRepository>(),
      ),
    );
    gh.factory<_i992.UpdateManagedTeacherUsecase>(
      () => _i992.UpdateManagedTeacherUsecase(
        gh<_i898.SchoolTeachersRepository>(),
      ),
    );
    gh.factory<_i992.SetManagedTeacherStatusUsecase>(
      () => _i992.SetManagedTeacherStatusUsecase(
        gh<_i898.SchoolTeachersRepository>(),
      ),
    );
    gh.factory<_i992.DeleteManagedTeacherUsecase>(
      () => _i992.DeleteManagedTeacherUsecase(
        gh<_i898.SchoolTeachersRepository>(),
      ),
    );
    gh.factory<_i992.ImportManagedTeachersUsecase>(
      () => _i992.ImportManagedTeachersUsecase(
        gh<_i898.SchoolTeachersRepository>(),
      ),
    );
    gh.factory<_i117.GetManagedClassesUsecase>(
      () => _i117.GetManagedClassesUsecase(gh<_i51.SchoolClassesRepository>()),
    );
    gh.factory<_i117.CreateManagedClassUsecase>(
      () => _i117.CreateManagedClassUsecase(gh<_i51.SchoolClassesRepository>()),
    );
    gh.factory<_i117.UpdateManagedClassUsecase>(
      () => _i117.UpdateManagedClassUsecase(gh<_i51.SchoolClassesRepository>()),
    );
    gh.factory<_i117.SetManagedClassStatusUsecase>(
      () => _i117.SetManagedClassStatusUsecase(
        gh<_i51.SchoolClassesRepository>(),
      ),
    );
    gh.factory<_i117.DeleteManagedClassUsecase>(
      () => _i117.DeleteManagedClassUsecase(gh<_i51.SchoolClassesRepository>()),
    );
    gh.factory<_i39.GetTeacherStudentsUsecase>(
      () =>
          _i39.GetTeacherStudentsUsecase(gh<_i921.TeacherStudentsRepository>()),
    );
    gh.factory<_i39.CreateTeacherStudentUsecase>(
      () => _i39.CreateTeacherStudentUsecase(
        gh<_i921.TeacherStudentsRepository>(),
      ),
    );
    gh.factory<_i39.SetTeacherStudentStatusUsecase>(
      () => _i39.SetTeacherStudentStatusUsecase(
        gh<_i921.TeacherStudentsRepository>(),
      ),
    );
    gh.factory<_i39.DeleteTeacherStudentUsecase>(
      () => _i39.DeleteTeacherStudentUsecase(
        gh<_i921.TeacherStudentsRepository>(),
      ),
    );
    gh.factory<_i1043.TeacherRequestsCubit>(
      () =>
          _i1043.TeacherRequestsCubit(gh<_i12.GetTeacherExitRequestsUsecase>()),
    );
    gh.factory<_i794.SchoolManagementCubit>(
      () => _i794.SchoolManagementCubit(
        gh<_i194.GetSchoolsUsecase>(),
        gh<_i194.GetSystemStatsUsecase>(),
        gh<_i194.CreateSchoolUsecase>(),
        gh<_i194.UpdateSchoolUsecase>(),
        gh<_i194.SetSchoolStatusUsecase>(),
        gh<_i194.DeleteSchoolUsecase>(),
      ),
    );
    gh.lazySingleton<_i916.SchoolStudentsRepository>(
      () => _i951.SchoolStudentsRepositoryImpl(
        gh<_i951.SchoolStudentsApiDataSource>(),
      ),
    );
    gh.lazySingleton<_i886.AuthRepository>(
      () => _i134.AuthRepositoryImpl(
        gh<_i1037.ApiService>(),
        gh<_i922.SessionService>(),
      ),
    );
    gh.lazySingleton<_i593.SchoolGuardsRepository>(
      () =>
          _i25.SchoolGuardsRepositoryImpl(gh<_i25.SchoolGuardsApiDataSource>()),
    );
    gh.factory<_i570.TeacherStudentsCubit>(
      () => _i570.TeacherStudentsCubit(
        gh<_i513.GetTeacherClassesUsecase>(),
        gh<_i39.GetTeacherStudentsUsecase>(),
        gh<_i39.CreateTeacherStudentUsecase>(),
        gh<_i39.SetTeacherStudentStatusUsecase>(),
        gh<_i39.DeleteTeacherStudentUsecase>(),
      ),
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
    gh.factory<_i949.CategoryBloc>(
      () => _i949.CategoryBloc(
        gh<_i513.GetCategoryUsecase>(),
        gh<_i406.CreateCategoryUseCase>(),
        gh<_i164.UpdateCategoryUsecase>(),
        gh<_i236.DeleteCategoryUsecase>(),
      ),
    );
    gh.factory<_i629.SchoolAdminsCubit>(
      () => _i629.SchoolAdminsCubit(
        gh<_i194.GetSchoolsUsecase>(),
        gh<_i194.GetSchoolAdminsUsecase>(),
        gh<_i194.CreateSchoolAdminUsecase>(),
        gh<_i194.UpdateSchoolAdminUsecase>(),
        gh<_i194.SetSchoolAdminStatusUsecase>(),
        gh<_i194.DeleteSchoolAdminUsecase>(),
      ),
    );
    gh.factory<_i863.SessionBootstrapCubit>(
      () => _i863.SessionBootstrapCubit(gh<_i593.RestoreSessionUsecase>()),
    );
    gh.factory<_i648.GetManagedStudentsUsecase>(
      () =>
          _i648.GetManagedStudentsUsecase(gh<_i916.SchoolStudentsRepository>()),
    );
    gh.factory<_i648.CreateManagedStudentUsecase>(
      () => _i648.CreateManagedStudentUsecase(
        gh<_i916.SchoolStudentsRepository>(),
      ),
    );
    gh.factory<_i648.UpdateManagedStudentUsecase>(
      () => _i648.UpdateManagedStudentUsecase(
        gh<_i916.SchoolStudentsRepository>(),
      ),
    );
    gh.factory<_i648.SetManagedStudentStatusUsecase>(
      () => _i648.SetManagedStudentStatusUsecase(
        gh<_i916.SchoolStudentsRepository>(),
      ),
    );
    gh.factory<_i648.DeleteManagedStudentUsecase>(
      () => _i648.DeleteManagedStudentUsecase(
        gh<_i916.SchoolStudentsRepository>(),
      ),
    );
    gh.factory<_i648.ImportManagedStudentsUsecase>(
      () => _i648.ImportManagedStudentsUsecase(
        gh<_i916.SchoolStudentsRepository>(),
      ),
    );
    gh.factory<_i361.ProfileBloc>(
      () => _i361.ProfileBloc(
        gh<_i789.GetProfileUsecase>(),
        gh<_i802.UpdateProfileUsecase>(),
        gh<_i754.DeleteAccountUsecase>(),
        gh<_i61.ChangePasswordUsecase>(),
      ),
    );
    gh.factory<_i381.SchoolClassesCubit>(
      () => _i381.SchoolClassesCubit(
        gh<_i117.GetManagedClassesUsecase>(),
        gh<_i117.CreateManagedClassUsecase>(),
        gh<_i117.UpdateManagedClassUsecase>(),
        gh<_i117.SetManagedClassStatusUsecase>(),
        gh<_i117.DeleteManagedClassUsecase>(),
      ),
    );
    gh.factory<_i878.SchoolStudentsCubit>(
      () => _i878.SchoolStudentsCubit(
        gh<_i117.GetManagedClassesUsecase>(),
        gh<_i648.GetManagedStudentsUsecase>(),
        gh<_i648.CreateManagedStudentUsecase>(),
        gh<_i648.UpdateManagedStudentUsecase>(),
        gh<_i648.SetManagedStudentStatusUsecase>(),
        gh<_i648.DeleteManagedStudentUsecase>(),
        gh<_i648.ImportManagedStudentsUsecase>(),
      ),
    );
    gh.factory<_i88.SchoolTeachersCubit>(
      () => _i88.SchoolTeachersCubit(
        gh<_i117.GetManagedClassesUsecase>(),
        gh<_i992.GetManagedTeachersUsecase>(),
        gh<_i992.CreateManagedTeacherUsecase>(),
        gh<_i992.UpdateManagedTeacherUsecase>(),
        gh<_i992.SetManagedTeacherStatusUsecase>(),
        gh<_i992.DeleteManagedTeacherUsecase>(),
        gh<_i992.ImportManagedTeachersUsecase>(),
      ),
    );
    gh.factory<_i117.GetManagedGuardsUsecase>(
      () => _i117.GetManagedGuardsUsecase(gh<_i593.SchoolGuardsRepository>()),
    );
    gh.factory<_i117.CreateManagedGuardUsecase>(
      () => _i117.CreateManagedGuardUsecase(gh<_i593.SchoolGuardsRepository>()),
    );
    gh.factory<_i117.UpdateManagedGuardUsecase>(
      () => _i117.UpdateManagedGuardUsecase(gh<_i593.SchoolGuardsRepository>()),
    );
    gh.factory<_i117.SetManagedGuardStatusUsecase>(
      () => _i117.SetManagedGuardStatusUsecase(
        gh<_i593.SchoolGuardsRepository>(),
      ),
    );
    gh.factory<_i117.DeleteManagedGuardUsecase>(
      () => _i117.DeleteManagedGuardUsecase(gh<_i593.SchoolGuardsRepository>()),
    );
    gh.factory<_i321.RegisterBloc>(
      () => _i321.RegisterBloc(gh<_i759.RegisterUsecase>()),
    );
    gh.factory<_i334.SchoolGuardsCubit>(
      () => _i334.SchoolGuardsCubit(
        gh<_i117.GetManagedGuardsUsecase>(),
        gh<_i117.CreateManagedGuardUsecase>(),
        gh<_i117.UpdateManagedGuardUsecase>(),
        gh<_i117.SetManagedGuardStatusUsecase>(),
        gh<_i117.DeleteManagedGuardUsecase>(),
      ),
    );
    return this;
  }
}

class _$DiModule extends _i583.DiModule {}
