import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/features/school_management/data/models/school_response.dart';

@lazySingleton
class SchoolManagementApiDataSource {
  const SchoolManagementApiDataSource(
    this._dio,
    @Named('baseUrl') this._baseUrl,
  );

  final Dio _dio;
  final String _baseUrl;

  String get _schoolsUrl => '$_baseUrl/system/schools';
  String get _adminsUrl => '$_baseUrl/system/school-admins';

  Future<List<SchoolResponse>> getSchools() async {
    final response = await _dio.get<Map<String, dynamic>>(_schoolsUrl);
    final items = response.data?['data'] as List<dynamic>? ?? const [];
    return items
        .map((item) => SchoolResponse.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SchoolResponse> createSchool(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _schoolsUrl,
      data: body,
    );
    return _schoolFrom(response);
  }

  Future<SchoolResponse> updateSchool(int id, Map<String, dynamic> body) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '$_schoolsUrl/$id',
      data: body,
    );
    return _schoolFrom(response);
  }

  Future<SchoolResponse> setSchoolStatus(int id, bool isActive) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '$_schoolsUrl/$id/status',
      data: {'is_active': isActive},
    );
    return _schoolFrom(response);
  }

  Future<void> deleteSchool(int id) => _dio.delete<void>('$_schoolsUrl/$id');

  Future<List<SchoolAdminResponse>> getSchoolAdmins() async {
    final response = await _dio.get<Map<String, dynamic>>(_adminsUrl);
    final items = response.data?['data'] as List<dynamic>? ?? const [];
    return items
        .map(
          (item) => SchoolAdminResponse.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<SchoolAdminResponse> createSchoolAdmin(
    Map<String, dynamic> body,
  ) async =>
      _adminFrom(await _dio.post<Map<String, dynamic>>(_adminsUrl, data: body));
  Future<SchoolAdminResponse> updateSchoolAdmin(
    int id,
    Map<String, dynamic> body,
  ) async => _adminFrom(
    await _dio.patch<Map<String, dynamic>>('$_adminsUrl/$id', data: body),
  );
  Future<SchoolAdminResponse> setSchoolAdminStatus(int id, bool active) async =>
      _adminFrom(
        await _dio.patch<Map<String, dynamic>>(
          '$_adminsUrl/$id/status',
          data: {'is_active': active},
        ),
      );
  Future<void> deleteSchoolAdmin(int id) =>
      _dio.delete<void>('$_adminsUrl/$id');

  SchoolResponse _schoolFrom(Response<Map<String, dynamic>> response) =>
      SchoolResponse.fromJson(response.data!['data'] as Map<String, dynamic>);

  SchoolAdminResponse _adminFrom(Response<Map<String, dynamic>> response) =>
      SchoolAdminResponse.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
}
