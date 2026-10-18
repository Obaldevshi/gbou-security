import 'package:dio/dio.dart';
import 'package:mobile_template/core/network/school_tls.dart';
import 'package:mobile_template/core/services/school_connection_service.dart';

class SchoolConnectionInterceptor extends Interceptor {
  SchoolConnectionInterceptor(this.service, this.dio) {
    configureSchoolTls(dio, service.connection);
    _configuredScope = service.connection.scope;
    service.addListener(_onConnectionChanged);
  }

  final SchoolConnectionService service;
  final Dio dio;
  String? _configuredScope;

  void _onConnectionChanged() {
    if (service.isChanging || _configuredScope == service.connection.scope) {
      return;
    }
    configureSchoolTls(dio, service.connection);
    _configuredScope = service.connection.scope;
  }

  void dispose() => service.removeListener(_onConnectionChanged);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final original = options.uri;
    final defaultUri = Uri.parse(service.defaultBaseUrl);
    final selected = Uri.parse(service.connection.apiBaseUrl);
    if (service.isChanging ||
        !{defaultUri.origin, selected.origin}.contains(original.origin) ||
        !(original.path == '/api/v1' || original.path.startsWith('/api/v1/'))) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message:
              'Подключение изменено или адрес запроса не относится к школьному API.',
        ),
      );
      return;
    }
    options.baseUrl = selected.origin;
    options.path = original.path;
    options.queryParameters = original.queryParametersAll;
    options.followRedirects = false;
    options.extra['school_connection_revision'] = service.revision;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.extra['school_connection_revision'] !=
        service.revision) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          type: DioExceptionType.cancel,
          message: 'Ответ прежнего сервера не используется.',
        ),
      );
      return;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.extra['school_connection_revision'] !=
        service.revision) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          type: DioExceptionType.cancel,
          message: 'Подключение к школе изменено.',
        ),
      );
      return;
    }
    handler.next(err);
  }
}
