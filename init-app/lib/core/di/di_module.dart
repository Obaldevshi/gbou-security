import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:mobile_template/core/interceptors/auth_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@module
abstract class DiModule {
  @lazySingleton
  Dio dio(AuthInterceptor authInterceptor) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    final interceptors = <Interceptor>[authInterceptor];
    if (kDebugMode) {
      // Request bodies may contain passwords or trusted-device tokens.
      interceptors.add(
        LogInterceptor(
          requestHeader: false,
          responseHeader: false,
          requestBody: false,
          responseBody: false,
        ),
      );
    }
    dio.interceptors.addAll(interceptors);
    return dio;
  }

  @lazySingleton
  Connectivity connectivity() => Connectivity();

  @Named('baseUrl')
  String baseUrl() {
    if (kIsWeb) {
      // The same web bundle may be served by the school-local gateway.
      // Never send a local teacher/guard login to the central API.
      if (const bool.fromEnvironment('GBOU_LOCAL_MODE') ||
          const {
            'gbou-local.local',
            'gbousecurity.local',
          }.contains(Uri.base.host)) {
        return '${Uri.base.origin}/api/v1';
      }
      return dotenv.env['BASE_URL_WEB'] ?? dotenv.env['BASE_URL'] ?? '';
    }
    return dotenv.env['BASE_URL'] ?? '';
  }

  @preResolve
  @lazySingleton
  Future<SharedPreferences> sharedPreferences() =>
      SharedPreferences.getInstance();

  @lazySingleton
  FlutterSecureStorage secureStorage() => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @Named('navigatorKey')
  @lazySingleton
  GlobalKey<NavigatorState> navigatorKey() => GlobalKey<NavigatorState>();
}
