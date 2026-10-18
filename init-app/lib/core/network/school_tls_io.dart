import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:mobile_template/core/services/school_connection_service.dart';

SecurityContext _context(SchoolConnection connection) {
  final context = SecurityContext(withTrustedRoots: connection.caPem == null);
  if (connection.caPem != null) {
    context.setTrustedCertificatesBytes(utf8.encode(connection.caPem!));
  }
  return context;
}

void validateSchoolCertificate(SchoolConnection connection) {
  _context(connection);
}

void configureSchoolTls(Dio dio, SchoolConnection connection) {
  final context = _context(connection);
  dio.httpClientAdapter.close(force: true);
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient(context: context),
  );
}
