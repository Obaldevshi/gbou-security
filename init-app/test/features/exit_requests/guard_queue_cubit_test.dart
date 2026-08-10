import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_guard_queue_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/release_exit_request_usecase.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/guard_queue/guard_queue_cubit.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/guard_queue/guard_queue_state.dart';

void main() {
  test('loads the guard queue and removes a released request', () async {
    final repository = _GuardRepository([_request(1), _request(2)]);
    final cubit = GuardQueueCubit(
      GetGuardQueueUsecase(repository),
      ReleaseExitRequestUsecase(repository),
    );
    addTearDown(cubit.close);

    await cubit.loadQueue();
    await cubit.release(1);

    expect(cubit.state.status, GuardQueueStatus.success);
    expect(cubit.state.requests.map((request) => request.id), [2]);
    expect(cubit.state.feedbackCode, 'release_success');
  });

  test('removes a stale request after a release conflict', () async {
    final repository = _GuardRepository([_request(1)])
      ..releaseFailure = const ServerFailure(
        statusCode: 409,
        errorCode: 'request_already_processed',
      );
    final cubit = GuardQueueCubit(
      GetGuardQueueUsecase(repository),
      ReleaseExitRequestUsecase(repository),
    );
    addTearDown(cubit.close);

    await cubit.loadQueue();
    await cubit.release(1);

    expect(cubit.state.requests, isEmpty);
    expect(cubit.state.feedbackCode, 'request_already_processed');
  });
}

ExitRequest _request(int id) => ExitRequest(
  id: id,
  classId: 10,
  className: '5А',
  studentId: 20 + id,
  studentFullName: 'Иванов Иван',
  teacherId: 1,
  teacherFullName: 'Петрова Анна',
  reasonType: ExitReasonType.parentNote,
  scheduledAt: DateTime.utc(2026, 8, 10, 10),
  status: ExitRequestStatus.pending,
  createdAt: DateTime.utc(2026, 8, 10, 9),
);

class _GuardRepository implements ExitRequestRepository {
  _GuardRepository(this.requests);

  final List<ExitRequest> requests;
  Failure? releaseFailure;

  @override
  Future<Either<Failure, List<ExitRequest>>> getPendingGuardRequests() async =>
      Right(List.unmodifiable(requests));

  @override
  Future<Either<Failure, ReleaseExitRequestResult>> releaseExitRequest(
    int id,
  ) async {
    final failure = releaseFailure;
    if (failure != null) return Left(failure);
    requests.removeWhere((request) => request.id == id);
    return Right(
      ReleaseExitRequestResult(
        id: id,
        status: ExitRequestStatus.released,
        releasedAt: DateTime.utc(2026, 8, 10, 10, 1),
        releasedById: 2,
      ),
    );
  }

  @override
  Future<Either<Failure, ExitRequest>> createExitRequest(
    CreateExitRequestCommand command,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<Student>>> getClassStudents(int classId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<TeacherClass>>> getTeacherClasses() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, TeacherExitRequestsSnapshot>>
  getTeacherExitRequests() => throw UnimplementedError();
}
