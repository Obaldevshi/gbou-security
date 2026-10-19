import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:dio/dio.dart';

@JS('fetch')
external JSPromise<_PrivateResponse> _fetch(
  JSString url,
  _PrivateOptions options,
);

extension type _PrivateOptions._(JSObject _) implements JSObject {
  external factory _PrivateOptions({
    String method,
    String redirect,
    String credentials,
    String cache,
    String referrerPolicy,
    JSObject headers,
    JSString body,
    JSObject signal,
  });
}

extension type _PrivateResponse._(JSObject _) implements JSObject {
  external int get status;
  external bool get redirected;
  external JSPromise<JSString> text();
}

@JS('AbortController')
extension type _AbortController._(JSObject _) implements JSObject {
  external factory _AbortController();
  external JSObject get signal;
  external void abort();
}

/// XHR follows redirects even when Dio says not to. Fetch redirect:error enforces
/// this boundary in the browser, while credentials:omit excludes ambient cookies.
class _PrivateJsonAdapter implements HttpClientAdapter {
  final _active = <_AbortController>{};
  bool _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) throw StateError('HTTP client closed');
    if (options.method != 'POST' || options.uri.scheme != 'https') {
      throw StateError('Private JSON transport requires an HTTPS POST');
    }
    final controller = _AbortController();
    _active.add(controller);
    var timedOut = false;
    var cancelled = false;
    final timer = Timer(
      options.receiveTimeout ?? const Duration(seconds: 30),
      () {
        timedOut = true;
        controller.abort();
      },
    );
    unawaited(
      cancelFuture?.then((_) {
        cancelled = true;
        controller.abort();
      }),
    );
    try {
      final chunks = await requestStream?.toList() ?? <Uint8List>[];
      final bytes = chunks.expand((chunk) => chunk).toList(growable: false);
      final response = await _fetch(
        options.uri.toString().toJS,
        _PrivateOptions(
          method: 'POST',
          redirect: 'error',
          credentials: 'omit',
          cache: 'no-store',
          referrerPolicy: 'no-referrer',
          headers:
              <String, String>{
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  }.jsify()
                  as JSObject,
          body: utf8.decode(bytes).toJS,
          signal: controller.signal,
        ),
      ).toDart;
      if (response.redirected) throw StateError('Redirect rejected');
      final body = (await response.text().toDart).toDart;
      if (body.length > 262144) throw StateError('Response too large');
      return ResponseBody.fromString(
        body,
        response.status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    } catch (_) {
      throw DioException(
        requestOptions: options,
        type: cancelled
            ? DioExceptionType.cancel
            : timedOut
            ? DioExceptionType.receiveTimeout
            : DioExceptionType.unknown,
        message:
            'Не удалось безопасно подключиться. Проверьте сеть и адрес школы.',
      );
    } finally {
      timer.cancel();
      _active.remove(controller);
    }
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    if (force) {
      for (final controller in _active) {
        controller.abort();
      }
      _active.clear();
    }
  }
}

void configurePrivateJsonTransport(Dio client) {
  client.httpClientAdapter = _PrivateJsonAdapter();
}
