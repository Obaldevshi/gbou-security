import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_building.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_buildings_repository.dart';

class SchoolBuildingsApiDataSource {
  const SchoolBuildingsApiDataSource(this.dio, this.baseUrl);
  final Dio dio;
  final String baseUrl;
  String get url => '$baseUrl/school/buildings';

  ManagedSchoolBuilding _parse(Map<String, dynamic> json) =>
      ManagedSchoolBuilding(
        id: json['id'] as int,
        name: json['name'] as String,
        address: json['address'] as String,
        isActive: json['is_active'] as bool,
      );

  Future<List<ManagedSchoolBuilding>> list() async {
    final response = await dio.get<Map<String, dynamic>>(url);
    return (response.data!['data'] as List<dynamic>)
        .map((item) => _parse(item as Map<String, dynamic>))
        .toList();
  }

  Future<ManagedSchoolBuilding> create(String name, String address) async =>
      _one(
        await dio.post<Map<String, dynamic>>(
          url,
          data: {'name': name, 'address': address},
        ),
      );

  Future<ManagedSchoolBuilding> update(
    int id,
    String name,
    String address,
  ) async => _one(
    await dio.patch<Map<String, dynamic>>(
      '$url/$id',
      data: {'name': name, 'address': address},
    ),
  );

  Future<ManagedSchoolBuilding> status(int id, bool active) async => _one(
    await dio.patch<Map<String, dynamic>>(
      '$url/$id/status',
      data: {'is_active': active},
    ),
  );

  Future<void> delete(int id) => dio.delete<void>('$url/$id');

  ManagedSchoolBuilding _one(Response<Map<String, dynamic>> response) =>
      _parse(response.data!['data'] as Map<String, dynamic>);
}

class SchoolBuildingsRepositoryImpl implements SchoolBuildingsRepository {
  const SchoolBuildingsRepositoryImpl(this.api);
  final SchoolBuildingsApiDataSource api;

  @override
  Future<Either<Failure, List<ManagedSchoolBuilding>>> getBuildings() =>
      _guard(api.list);

  @override
  Future<Either<Failure, ManagedSchoolBuilding>> createBuilding(
    String name,
    String address,
  ) => _guard(() => api.create(name, address));

  @override
  Future<Either<Failure, ManagedSchoolBuilding>> updateBuilding(
    int id,
    String name,
    String address,
  ) => _guard(() => api.update(id, name, address));

  @override
  Future<Either<Failure, ManagedSchoolBuilding>> setBuildingStatus(
    int id,
    bool active,
  ) => _guard(() => api.status(id, active));

  @override
  Future<Either<Failure, Unit>> deleteBuilding(int id) async {
    try {
      await api.delete(id);
      return const Right(unit);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }
}
