import 'package:mobile_template/core/network/auth_api_paths.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._sessionService);

  final SessionService _sessionService;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!AuthApiPaths.isUnauthenticated(options.path)) {
      final authHeader = _sessionService.getAuthHeader();
      if (authHeader != null) {
        options.headers['Authorization'] = authHeader;
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;
    final errorCode = data is Map<String, dynamic>
        ? data['code'] as String?
        : null;
    final invalidatesSession =
        statusCode == 401 ||
        (statusCode == 403 &&
            const {
              'account_inactive',
              'school_inactive',
              'school_required',
            }.contains(errorCode));

    if (invalidatesSession &&
        !AuthApiPaths.isUnauthenticated(err.requestOptions.path)) {
      await _sessionService.clearSession();
    }
    handler.next(err);
  }
}
