import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class RequestEventsService {
  const RequestEventsService(this.dio, @Named('baseUrl') this.baseUrl);
  final Dio dio;
  final String baseUrl;

  Stream<void> watch() async* {
    while (true) {
      try {
        final response = await dio.get<ResponseBody>(
          '$baseUrl/users/request-events',
          options: Options(
            responseType: ResponseType.stream,
            receiveTimeout: const Duration(minutes: 10),
            headers: const {'Accept': 'text/event-stream'},
          ),
        );
        final body = response.data;
        if (body == null) throw StateError('SSE body is empty');
        await for (final line
            in body.stream
                .cast<List<int>>()
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          if (line.startsWith('data:')) yield null;
        }
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 5));
        yield null;
      }
    }
  }
}
