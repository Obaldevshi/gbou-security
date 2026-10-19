import 'package:dio/dio.dart';

// Native Dio enforces followRedirects=false using the platform HTTP client.
void configurePrivateJsonTransport(Dio client) {}
