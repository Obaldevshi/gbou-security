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
