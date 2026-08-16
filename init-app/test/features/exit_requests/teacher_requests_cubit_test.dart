import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_teacher_exit_requests_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/cancel_teacher_exit_request_usecase.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_requests/teacher_requests_cubit.dart';

void main() {
  test('moves a known active request to history once', () async {
    final repository = _SnapshotRepository();
    final cubit = TeacherRequestsCubit(
      GetTeacherExitRequestsUsecase(repository),
      CancelTeacherExitRequestUsecase(repository),
    );
    addTearDown(cubit.close);

    await cubit.load();
    repository.released = true;
    await cubit.load(background: true);

    expect(cubit.state.active, isEmpty);
    expect(cubit.state.history.single.id, 1);
    expect(cubit.state.feedbackCode, 'request_released');
    expect(cubit.state.feedbackRevision, 1);
  });

  test('cancels an active request and reloads it into history', () async {
    final repository = _SnapshotRepository();
    final cubit = TeacherRequestsCubit(
      GetTeacherExitRequestsUsecase(repository),
      CancelTeacherExitRequestUsecase(repository),
    );
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.cancel(1);

    expect(cubit.state.active, isEmpty);
    expect(cubit.state.history.single.status, ExitRequestStatus.cancelled);
    expect(cubit.state.feedbackCode, 'request_cancelled');
  });
}

class _SnapshotRepository implements ExitRequestRepository {
  bool released = false;
  bool cancelled = false;

  ExitRequest get request => ExitRequest(
    id: 1,
    classId: 1,
    className: '5А',
    studentId: 1,
    studentFullName: 'Иванов Иван',
    teacherId: 1,
    teacherFullName: 'Демо Учитель',
    reasonType: ExitReasonType.parentNote,
    scheduledAt: DateTime.utc(2026, 8, 10, 12),
    status: released
        ? ExitRequestStatus.released
        : cancelled
        ? ExitRequestStatus.cancelled
        : ExitRequestStatus.pending,
    createdAt: DateTime.utc(2026, 8, 10, 11),
    releasedAt: released ? DateTime.utc(2026, 8, 10, 12, 1) : null,
    releasedById: released ? 2 : null,
  );

  @override
  Future<Either<Failure, TeacherExitRequestsSnapshot>>
  getTeacherExitRequests() async => Right(
    TeacherExitRequestsSnapshot(
      active: released || cancelled ? const [] : [request],
      history: released || cancelled ? [request] : const [],
    ),
  );

  @override
  Future<Either<Failure, ExitRequest>> createExitRequest(
    CreateExitRequestCommand command,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<Student>>> getClassStudents(int classId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<ExitRequest>>> getPendingGuardRequests() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<TeacherClass>>> getTeacherClasses() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, ReleaseExitRequestResult>> releaseExitRequest(
    int id,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, TeacherExitRequestsSnapshot>>
  getSchoolExitRequests() => throw UnimplementedError();

  @override
  Future<Either<Failure, ExitRequestStatus>> cancelTeacherExitRequest(
    int id,
  ) async {
    cancelled = true;
    return const Right<Failure, ExitRequestStatus>(ExitRequestStatus.cancelled);
  }

  @override
  Future<Either<Failure, ExitRequestStatus>> cancelSchoolExitRequest(int id) =>
      throw UnimplementedError();
}
