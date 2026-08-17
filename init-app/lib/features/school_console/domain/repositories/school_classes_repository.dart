import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_class.dart';

abstract interface class SchoolClassesRepository {
  Future<Either<Failure, List<ManagedSchoolClass>>> getClasses();
  Future<Either<Failure, ManagedSchoolClass>> createClass(
    int buildingId,
    String name,
  );
  Future<Either<Failure, ManagedSchoolClass>> updateClass(
    int id,
    int buildingId,
    String name,
  );
  Future<Either<Failure, ManagedSchoolClass>> setClassStatus(
    int id,
    bool active,
  );
  Future<Either<Failure, Unit>> deleteClass(int id);
}
