import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_teacher.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_teachers_repository.dart';

class ManagedTeacherResponse {
  const ManagedTeacherResponse({required this.teacher});
  factory ManagedTeacherResponse.fromJson(Map<String, dynamic> json) =>
      ManagedTeacherResponse(
        teacher: ManagedTeacher(
          id: json['id'] as int,
          login: json['login'] as String,
          fullName: json['full_name'] as String,
          phone: json['phone'] as String?,
          isActive: json['is_active'] as bool,
          classes: (json['classes'] as List<dynamic>).map((item) {
            final value = item as Map<String, dynamic>;
            return TeacherClass(
              id: value['id'] as int,
              name: value['name'] as String,
            );
          }).toList(),
        ),
      );
  final ManagedTeacher teacher;
}

@lazySingleton
class SchoolTeachersApiDataSource {
  const SchoolTeachersApiDataSource(this.dio, @Named('baseUrl') this.baseUrl);
  final Dio dio;
  final String baseUrl;
  String get url => '$baseUrl/school/teachers';
  Future<List<ManagedTeacherResponse>> list() async {
    final response = await dio.get<Map<String, dynamic>>(url);
    return (response.data!['data'] as List<dynamic>)
        .map(
          (item) =>
              ManagedTeacherResponse.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ManagedTeacherResponse> create(Map<String, dynamic> body) async =>
      _one(await dio.post<Map<String, dynamic>>(url, data: body));
  Future<ManagedTeacherResponse> update(
    int id,
    Map<String, dynamic> body,
  ) async =>
      _one(await dio.patch<Map<String, dynamic>>('$url/$id', data: body));
  Future<ManagedTeacherResponse> status(int id, bool active) async => _one(
    await dio.patch<Map<String, dynamic>>(
      '$url/$id/status',
      data: {'is_active': active},
    ),
  );
  Future<void> delete(int id) => dio.delete<void>('$url/$id');
  ManagedTeacherResponse _one(Response<Map<String, dynamic>> response) =>
      ManagedTeacherResponse.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
}

@LazySingleton(as: SchoolTeachersRepository)
class SchoolTeachersRepositoryImpl implements SchoolTeachersRepository {
  const SchoolTeachersRepositoryImpl(this.api);
  final SchoolTeachersApiDataSource api;
  @override
  Future<Either<Failure, List<ManagedTeacher>>> getTeachers() async {
    try {
      return Right((await api.list()).map((item) => item.teacher).toList());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, ManagedTeacher>> createTeacher(
    TeacherDraft draft,
  ) async {
    try {
      return Right(
        (await api.create(draft.toJson(includePassword: true))).teacher,
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, ManagedTeacher>> updateTeacher(
    int id,
    TeacherDraft draft,
  ) async {
    try {
      return Right(
        (await api.update(id, draft.toJson(includePassword: false))).teacher,
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, ManagedTeacher>> setTeacherStatus(
    int id,
    bool active,
  ) async {
    try {
      return Right((await api.status(id, active)).teacher);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteTeacher(int id) async {
    try {
      await api.delete(id);
      return const Right(unit);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }
}
