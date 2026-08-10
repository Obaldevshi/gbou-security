import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/data/datasources/exit_request_api_data_source.dart';
import 'package:mobile_template/features/exit_requests/data/models/exit_request_models.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';

@LazySingleton(as: ExitRequestRepository)
class ExitRequestRepositoryImpl implements ExitRequestRepository {
  const ExitRequestRepositoryImpl(this._api);

  final ExitRequestApiDataSource _api;

  @override
  Future<Either<Failure, List<TeacherClass>>> getTeacherClasses() async {
    try {
      final response = await _api.getTeacherClasses();
      return Right(
        (response.data ?? []).map((item) => item.toDomain()).toList(),
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, List<Student>>> getClassStudents(int classId) async {
    try {
      final response = await _api.getClassStudents(classId);
      return Right(
        (response.data ?? []).map((item) => item.toDomain()).toList(),
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, ExitRequest>> createExitRequest(
    CreateExitRequestCommand command,
  ) async {
    try {
      final response = await _api.createExitRequest(
        CreateExitRequestRequest.fromCommand(command),
      );
      return Right(response.data!.toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, List<ExitRequest>>> getPendingGuardRequests() async {
    try {
      final response = await _api.getPendingGuardRequests();
      return Right(
        (response.data ?? []).map((item) => item.toDomain()).toList(),
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, ReleaseExitRequestResult>> releaseExitRequest(
    int id,
  ) async {
    try {
      final response = await _api.releaseExitRequest(id);
      return Right(response.data!.toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }

  @override
  Future<Either<Failure, TeacherExitRequestsSnapshot>>
  getTeacherExitRequests() async {
    try {
      final response = await _api.getTeacherExitRequests();
      return Right(response.data!.toDomain());
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }
}
