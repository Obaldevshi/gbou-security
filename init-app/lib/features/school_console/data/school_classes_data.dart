import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_class.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_classes_repository.dart';

class ManagedSchoolClassResponse {
  const ManagedSchoolClassResponse(
    this.id,
    this.name,
    this.buildingId,
    this.buildingName,
    this.isActive,
  );
  factory ManagedSchoolClassResponse.fromJson(Map<String, dynamic> json) =>
      ManagedSchoolClassResponse(
        json['id'] as int,
        json['name'] as String,
        json['building_id'] as int,
        json['building_name'] as String,
        json['is_active'] as bool,
      );
  final int id;
  final String name;
  final int buildingId;
  final String buildingName;
  final bool isActive;
  ManagedSchoolClass toDomain() => ManagedSchoolClass(
    id: id,
    name: name,
    buildingId: buildingId,
    buildingName: buildingName,
    isActive: isActive,
  );
}

@lazySingleton
class SchoolClassesApiDataSource {
  const SchoolClassesApiDataSource(this.dio, @Named('baseUrl') this.baseUrl);
  final Dio dio;
  final String baseUrl;
  String get url => '$baseUrl/school/classes';
  Future<List<ManagedSchoolClassResponse>> getClasses() async {
    final response = await dio.get<Map<String, dynamic>>(url);
    final data = response.data!['data'] as List<dynamic>;
    return data
        .map(
          (item) =>
              ManagedSchoolClassResponse.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ManagedSchoolClassResponse> create(
    int buildingId,
    String name,
  ) async => _one(
    await dio.post<Map<String, dynamic>>(
      url,
      data: {'building_id': buildingId, 'name': name},
    ),
  );
  Future<ManagedSchoolClassResponse> update(
    int id,
    int buildingId,
    String name,
  ) async => _one(
    await dio.patch<Map<String, dynamic>>(
      '$url/$id',
      data: {'building_id': buildingId, 'name': name},
    ),
  );
  Future<ManagedSchoolClassResponse> status(int id, bool active) async => _one(
    await dio.patch<Map<String, dynamic>>(
      '$url/$id/status',
      data: {'is_active': active},
    ),
  );
  Future<void> delete(int id) => dio.delete<void>('$url/$id');
  ManagedSchoolClassResponse _one(Response<Map<String, dynamic>> response) =>
      ManagedSchoolClassResponse.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
}

@LazySingleton(as: SchoolClassesRepository)
class SchoolClassesRepositoryImpl implements SchoolClassesRepository {
  const SchoolClassesRepositoryImpl(this.api);
  final SchoolClassesApiDataSource api;
  @override
  Future<Either<Failure, List<ManagedSchoolClass>>> getClasses() async {
    try {
      return Right(
        (await api.getClasses()).map((item) => item.toDomain()).toList(),
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, ManagedSchoolClass>> createClass(
    int buildingId,
    String name,
  ) async {
    try {
      return Right((await api.create(buildingId, name)).toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, ManagedSchoolClass>> updateClass(
    int id,
    int buildingId,
    String name,
  ) async {
    try {
      return Right((await api.update(id, buildingId, name)).toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, ManagedSchoolClass>> setClassStatus(
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
  Future<Either<Failure, Unit>> deleteClass(int id) async {
    try {
      await api.delete(id);
      return const Right(unit);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }
}
