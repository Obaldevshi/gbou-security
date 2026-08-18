import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_students_repository.dart';

class ManagedStudentResponse {
  const ManagedStudentResponse({
    required this.id,
    required this.classId,
    required this.className,
    required this.lastName,
    required this.firstName,
    required this.isActive,
    this.middleName,
  });
  factory ManagedStudentResponse.fromJson(Map<String, dynamic> json) =>
      ManagedStudentResponse(
        id: json['id'] as int,
        classId: json['class_id'] as int,
        className: json['class_name'] as String,
        lastName: json['last_name'] as String,
        firstName: json['first_name'] as String,
        middleName: json['middle_name'] as String?,
        isActive: json['is_active'] as bool,
      );
  final int id;
  final int classId;
  final String className;
  final String lastName;
  final String firstName;
  final String? middleName;
  final bool isActive;
  ManagedStudent toDomain() => ManagedStudent(
    id: id,
    classId: classId,
    className: className,
    lastName: lastName,
    firstName: firstName,
    middleName: middleName,
    isActive: isActive,
  );
}

@lazySingleton
class SchoolStudentsApiDataSource {
  const SchoolStudentsApiDataSource(this.dio, @Named('baseUrl') this.baseUrl);
  final Dio dio;
  final String baseUrl;
  String get url => '$baseUrl/school/students';
  Future<List<ManagedStudentResponse>> list({int? classId}) async {
    final response = await dio.get<Map<String, dynamic>>(
      url,
      queryParameters: {'class_id': ?classId},
    );
    final data = response.data!['data'] as List<dynamic>;
    return data
        .map(
          (item) =>
              ManagedStudentResponse.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ManagedStudentResponse> create(Map<String, dynamic> body) async =>
      _one(await dio.post<Map<String, dynamic>>(url, data: body));
  Future<ManagedStudentResponse> update(
    int id,
    Map<String, dynamic> body,
  ) async =>
      _one(await dio.patch<Map<String, dynamic>>('$url/$id', data: body));
  Future<ManagedStudentResponse> status(int id, bool active) async => _one(
    await dio.patch<Map<String, dynamic>>(
      '$url/$id/status',
      data: {'is_active': active},
    ),
  );
  Future<void> delete(int id) => dio.delete<void>('$url/$id');
  Future<Map<String, dynamic>> import(
    String text, {
    required int buildingId,
    required int classId,
    bool dryRun = false,
  }) async =>
      (await dio.post<Map<String, dynamic>>(
            '$url/import',
            data: {
              'building_id': buildingId,
              'class_id': classId,
              'text': text,
              'dry_run': dryRun,
            },
          )).data!['data']
          as Map<String, dynamic>;
  ManagedStudentResponse _one(Response<Map<String, dynamic>> response) =>
      ManagedStudentResponse.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
}

@LazySingleton(as: SchoolStudentsRepository)
class SchoolStudentsRepositoryImpl implements SchoolStudentsRepository {
  const SchoolStudentsRepositoryImpl(this.api);
  final SchoolStudentsApiDataSource api;
  @override
  Future<Either<Failure, List<ManagedStudent>>> getStudents({
    int? classId,
  }) async {
    try {
      return Right(
        (await api.list(
          classId: classId,
        )).map((item) => item.toDomain()).toList(),
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, ManagedStudent>> createStudent(
    StudentDraft draft,
  ) async {
    try {
      return Right((await api.create(draft.toJson())).toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, ManagedStudent>> updateStudent(
    int id,
    StudentDraft draft,
  ) async {
    try {
      return Right((await api.update(id, draft.toJson())).toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, ManagedStudent>> setStudentStatus(
    int id,
    bool active,
  ) async {
    try {
      return Right((await api.status(id, active)).toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteStudent(int id) async {
    try {
      await api.delete(id);
      return const Right(unit);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, StudentImportSummary>> importStudents(
    String text, {
    required int buildingId,
    required int classId,
    bool dryRun = false,
  }) async {
    try {
      final data = await api.import(
        text,
        buildingId: buildingId,
        classId: classId,
        dryRun: dryRun,
      );
      return Right(
        StudentImportSummary(
          createdCount: data['created_count'] as int,
          errors: (data['errors'] as List<dynamic>).map((item) {
            final value = item as Map<String, dynamic>;
            return StudentImportError(
              line: value['line'] as int,
              message: value['message'] as String,
            );
          }).toList(),
        ),
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }
}
