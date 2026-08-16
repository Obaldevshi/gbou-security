import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_management/data/datasources/school_management_api_data_source.dart';
import 'package:mobile_template/features/school_management/domain/entities/school.dart';
import 'package:mobile_template/features/school_management/domain/repositories/school_management_repository.dart';

@LazySingleton(as: SchoolManagementRepository)
class SchoolManagementRepositoryImpl implements SchoolManagementRepository {
  const SchoolManagementRepositoryImpl(this._api);
  final SchoolManagementApiDataSource _api;

  @override
  Future<Either<Failure, List<School>>> getSchools() async {
    try {
      final schools = await _api.getSchools();
      return Right(schools.map((item) => item.toDomain()).toList());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, School>> createSchool(SchoolDraft draft) async {
    try {
      return Right((await _api.createSchool(draft.toJson())).toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, School>> updateSchool(
    int id,
    SchoolDraft draft,
  ) async {
    try {
      return Right((await _api.updateSchool(id, draft.toJson())).toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, School>> setSchoolStatus(int id, bool isActive) async {
    try {
      return Right((await _api.setSchoolStatus(id, isActive)).toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteSchool(int id) async {
    try {
      await _api.deleteSchool(id);
      return const Right(unit);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, List<SchoolAdmin>>> getSchoolAdmins() async {
    try {
      return Right(
        (await _api.getSchoolAdmins()).map((item) => item.toDomain()).toList(),
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, SchoolAdmin>> createSchoolAdmin(
    SchoolAdminDraft draft,
  ) async {
    try {
      return Right((await _api.createSchoolAdmin(draft.toJson())).toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, SchoolAdmin>> updateSchoolAdmin(
    int id,
    SchoolAdminDraft draft,
  ) async {
    try {
      return Right(
        (await _api.updateSchoolAdmin(id, draft.toJson())).toDomain(),
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, SchoolAdmin>> setSchoolAdminStatus(
    int id,
    bool isActive,
  ) async {
    try {
      return Right((await _api.setSchoolAdminStatus(id, isActive)).toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteSchoolAdmin(int id) async {
    try {
      await _api.deleteSchoolAdmin(id);
      return const Right(unit);
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }
}
