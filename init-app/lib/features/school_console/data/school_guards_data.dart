import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_guard.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_guards_repository.dart';

ManagedGuard _guard(Map<String, dynamic> json) => ManagedGuard(
  id: json['id'] as int,
  login: json['login'] as String,
  fullName: json['full_name'] as String,
  buildingId: json['building_id'] as int,
  buildingName: json['building_name'] as String,
  phone: json['phone'] as String?,
  isActive: json['is_active'] as bool,
);

@lazySingleton
class SchoolGuardsApiDataSource {
  const SchoolGuardsApiDataSource(this.dio, @Named('baseUrl') this.baseUrl);
  final Dio dio;
  final String baseUrl;
  String get url => '$baseUrl/school/guards';
  Future<List<ManagedGuard>> list() async =>
      ((await dio.get<Map<String, dynamic>>(url)).data!['data']
              as List<dynamic>)
          .map((item) => _guard(item as Map<String, dynamic>))
          .toList();
  Future<ManagedGuard> create(Map<String, dynamic> body) async =>
      _one(await dio.post<Map<String, dynamic>>(url, data: body));
  Future<ManagedGuard> update(int id, Map<String, dynamic> body) async =>
      _one(await dio.patch<Map<String, dynamic>>('$url/$id', data: body));
  Future<ManagedGuard> status(int id, bool active) async => _one(
    await dio.patch<Map<String, dynamic>>(
      '$url/$id/status',
      data: {'is_active': active},
    ),
  );
  Future<void> delete(int id) => dio.delete<void>('$url/$id');
  ManagedGuard _one(Response<Map<String, dynamic>> response) =>
      _guard(response.data!['data'] as Map<String, dynamic>);
}

@LazySingleton(as: SchoolGuardsRepository)
class SchoolGuardsRepositoryImpl implements SchoolGuardsRepository {
  const SchoolGuardsRepositoryImpl(this.api);
  final SchoolGuardsApiDataSource api;
  @override
  Future<Either<Failure, List<ManagedGuard>>> getGuards() async {
    try {
      return Right(await api.list());
    } catch (e) {
      return Left(ErrorHandler.handleError(e));
    }
  }

  @override
  Future<Either<Failure, ManagedGuard>> createGuard(GuardDraft draft) async {
    try {
      return Right(await api.create(draft.toJson(includePassword: true)));
    } catch (e) {
      return Left(ErrorHandler.handleError(e));
    }
  }

  @override
  Future<Either<Failure, ManagedGuard>> updateGuard(
    int id,
    GuardDraft draft,
  ) async {
    try {
      return Right(await api.update(id, draft.toJson(includePassword: false)));
    } catch (e) {
      return Left(ErrorHandler.handleError(e));
    }
  }

  @override
  Future<Either<Failure, ManagedGuard>> setGuardStatus(
    int id,
    bool active,
  ) async {
    try {
      return Right(await api.status(id, active));
    } catch (e) {
      return Left(ErrorHandler.handleError(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteGuard(int id) async {
    try {
      await api.delete(id);
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handleError(e));
    }
  }
}
