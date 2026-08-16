import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/data/school_students_data.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/domain/repositories/teacher_students_repository.dart';

@lazySingleton
class TeacherStudentsApiDataSource {
  const TeacherStudentsApiDataSource(this.dio, @Named('baseUrl') this.baseUrl);
  final Dio dio;
  final String baseUrl;
  String get url => '$baseUrl/teacher/students';
  Future<List<ManagedStudentResponse>> list() async =>
      ((await dio.get<Map<String, dynamic>>(url)).data!['data']
              as List<dynamic>)
          .map(
            (e) => ManagedStudentResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList();
  Future<ManagedStudentResponse> create(Map<String, dynamic> body) async =>
      _one(await dio.post<Map<String, dynamic>>(url, data: body));
  Future<ManagedStudentResponse> status(int id, bool active) async => _one(
    await dio.patch<Map<String, dynamic>>(
      '$url/$id/status',
      data: {'is_active': active},
    ),
  );
  Future<void> delete(int id) => dio.delete<void>('$url/$id');
  ManagedStudentResponse _one(Response<Map<String, dynamic>> r) =>
      ManagedStudentResponse.fromJson(r.data!['data'] as Map<String, dynamic>);
}

@LazySingleton(as: TeacherStudentsRepository)
class TeacherStudentsRepositoryImpl implements TeacherStudentsRepository {
  const TeacherStudentsRepositoryImpl(this.api);
  final TeacherStudentsApiDataSource api;
  @override
  Future<Either<Failure, List<ManagedStudent>>> getStudents() async {
    try {
      return Right((await api.list()).map((e) => e.toDomain()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleError(e));
    }
  }

  @override
  Future<Either<Failure, ManagedStudent>> createStudent(StudentDraft d) async {
    try {
      return Right((await api.create(d.toJson())).toDomain());
    } catch (e) {
      return Left(ErrorHandler.handleError(e));
    }
  }

  @override
  Future<Either<Failure, ManagedStudent>> setStudentStatus(
    int id,
    bool active,
  ) async {
    try {
      return Right((await api.status(id, active)).toDomain());
    } catch (e) {
      return Left(ErrorHandler.handleError(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteStudent(int id) async {
    try {
      await api.delete(id);
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handleError(e));
    }
  }
}
