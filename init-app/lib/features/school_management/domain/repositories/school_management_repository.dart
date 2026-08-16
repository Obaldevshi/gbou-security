import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_management/domain/entities/school.dart';

abstract interface class SchoolManagementRepository {
  Future<Either<Failure, List<School>>> getSchools();
  Future<Either<Failure, School>> createSchool(SchoolDraft draft);
  Future<Either<Failure, School>> updateSchool(int id, SchoolDraft draft);
  Future<Either<Failure, School>> setSchoolStatus(int id, bool isActive);
  Future<Either<Failure, Unit>> deleteSchool(int id);
  Future<Either<Failure, List<SchoolAdmin>>> getSchoolAdmins();
  Future<Either<Failure, SchoolAdmin>> createSchoolAdmin(
    SchoolAdminDraft draft,
  );
  Future<Either<Failure, SchoolAdmin>> updateSchoolAdmin(
    int id,
    SchoolAdminDraft draft,
  );
  Future<Either<Failure, SchoolAdmin>> setSchoolAdminStatus(
    int id,
    bool isActive,
  );
  Future<Either<Failure, Unit>> deleteSchoolAdmin(int id);
}
