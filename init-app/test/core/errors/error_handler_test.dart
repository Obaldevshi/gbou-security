import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';

void main() {
  test('unknown client errors have a safe Russian message', () {
    final failure = ErrorHandler.handleError(Exception('sensitive detail'));

    expect(failure.message, 'Произошла ошибка. Попробуйте ещё раз.');
    expect(failure.message, isNot(contains('Exception')));
  });

  test('response transform timeout is handled as a timeout', () {
    final failure = ErrorHandler.handleDioError(
      DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.transformTimeout,
      ),
    );

    expect(failure, isA<TimeoutFailure>());
  });
}
