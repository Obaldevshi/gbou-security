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
      interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    }
    dio.interceptors.addAll(interceptors);
    return dio;
  }

  @lazySingleton
  Connectivity connectivity() => Connectivity();

  @Named('baseUrl')
  String baseUrl() {
    if (kIsWeb) {
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
