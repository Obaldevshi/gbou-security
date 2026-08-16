import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_management/domain/entities/school.dart';
import 'package:mobile_template/features/school_management/domain/repositories/school_management_repository.dart';

@injectable
class GetSchoolsUsecase {
  const GetSchoolsUsecase(this._repository);
  final SchoolManagementRepository _repository;
  Future<Either<Failure, List<School>>> call() => _repository.getSchools();
}

@injectable
class CreateSchoolUsecase {
  const CreateSchoolUsecase(this._repository);
  final SchoolManagementRepository _repository;
  Future<Either<Failure, School>> call(SchoolDraft draft) =>
      _repository.createSchool(draft);
}

@injectable
class UpdateSchoolUsecase {
  const UpdateSchoolUsecase(this._repository);
  final SchoolManagementRepository _repository;
  Future<Either<Failure, School>> call(int id, SchoolDraft draft) =>
      _repository.updateSchool(id, draft);
}

@injectable
class SetSchoolStatusUsecase {
  const SetSchoolStatusUsecase(this._repository);
  final SchoolManagementRepository _repository;
  Future<Either<Failure, School>> call(int id, bool isActive) =>
      _repository.setSchoolStatus(id, isActive);
}

@injectable
class DeleteSchoolUsecase {
  const DeleteSchoolUsecase(this._repository);
  final SchoolManagementRepository _repository;
  Future<Either<Failure, Unit>> call(int id) => _repository.deleteSchool(id);
}

@injectable
class GetSchoolAdminsUsecase {
  const GetSchoolAdminsUsecase(this._repository);
  final SchoolManagementRepository _repository;
  Future<Either<Failure, List<SchoolAdmin>>> call() =>
      _repository.getSchoolAdmins();
}

@injectable
class CreateSchoolAdminUsecase {
  const CreateSchoolAdminUsecase(this._repository);
  final SchoolManagementRepository _repository;
  Future<Either<Failure, SchoolAdmin>> call(SchoolAdminDraft draft) =>
      _repository.createSchoolAdmin(draft);
}

@injectable
class UpdateSchoolAdminUsecase {
  const UpdateSchoolAdminUsecase(this._repository);
  final SchoolManagementRepository _repository;
  Future<Either<Failure, SchoolAdmin>> call(int id, SchoolAdminDraft draft) =>
      _repository.updateSchoolAdmin(id, draft);
}

@injectable
class SetSchoolAdminStatusUsecase {
  const SetSchoolAdminStatusUsecase(this._repository);
  final SchoolManagementRepository _repository;
  Future<Either<Failure, SchoolAdmin>> call(int id, bool isActive) =>
      _repository.setSchoolAdminStatus(id, isActive);
}

@injectable
class DeleteSchoolAdminUsecase {
  const DeleteSchoolAdminUsecase(this._repository);
  final SchoolManagementRepository _repository;
  Future<Either<Failure, Unit>> call(int id) =>
      _repository.deleteSchoolAdmin(id);
}

@injectable
class GetSystemStatsUsecase {
  const GetSystemStatsUsecase(this._repository);
  final SchoolManagementRepository _repository;
  Future<Either<Failure, SystemStats>> call() => _repository.getSystemStats();
}
