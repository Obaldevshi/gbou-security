import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/create_exit_request_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_class_students_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_teacher_classes_usecase.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_request/teacher_request_cubit.dart';
import 'package:mobile_template/features/exit_requests/presentation/pages/teacher_request/teacher_request_state.dart';

void main() {
  const schoolClass = TeacherClass(id: 1, name: '5А');
  const student = Student(
    id: 2,
    classId: 1,
    firstName: 'Иван',
    lastName: 'Иванов',
    middleName: 'Иванович',
    fullName: 'Иванов Иван Иванович',
  );

  TeacherRequestCubit createCubit() {
    final repository = _FakeRepository(schoolClass, student);
    return TeacherRequestCubit(
      GetTeacherClassesUsecase(repository),
      GetClassStudentsUsecase(repository),
      CreateExitRequestUsecase(repository),
    );
  }

  test('loads dependent data and creates a pending request', () async {
    final cubit = createCubit();
    addTearDown(cubit.close);

    await cubit.loadClasses();
    await cubit.selectClass(schoolClass);
    cubit.selectStudent(student);
    cubit.selectReason(ExitReasonType.parentNote);
    cubit.setScheduledAt(DateTime.now().add(const Duration(minutes: 10)));
    await cubit.submit();

    expect(cubit.state.submissionStatus, RequestSubmissionStatus.success);
    expect(cubit.state.lastCreated?.status, ExitRequestStatus.pending);
    expect(cubit.state.selectedClass, isNull);
  });

  test('other reason is not submittable before meaningful text', () async {
    final cubit = createCubit();
    addTearDown(cubit.close);

    await cubit.loadClasses();
    await cubit.selectClass(schoolClass);
    cubit.selectStudent(student);
    cubit.selectReason(ExitReasonType.other);
    cubit.setScheduledAt(DateTime.now().add(const Duration(minutes: 10)));
    cubit.setCustomReason('  ');

    expect(cubit.state.canSubmit, isFalse);
  });
}

class _FakeRepository implements ExitRequestRepository {
  _FakeRepository(this.schoolClass, this.student);

  final TeacherClass schoolClass;
  final Student student;

  @override
  Future<Either<Failure, List<TeacherClass>>> getTeacherClasses() async =>
      Right([schoolClass]);

  @override
  Future<Either<Failure, List<Student>>> getClassStudents(int classId) async =>
      Right([student]);

  @override
  Future<Either<Failure, ExitRequest>> createExitRequest(
    CreateExitRequestCommand command,
  ) async => Right(
    ExitRequest(
      id: 1,
      classId: schoolClass.id,
      className: schoolClass.name,
      studentId: student.id,
      studentFullName: student.fullName,
      teacherId: 1,
      teacherFullName: 'Демо Учитель',
      reasonType: command.reasonType,
      customReason: command.customReason,
      scheduledAt: command.scheduledAt,
      status: ExitRequestStatus.pending,
      createdAt: DateTime.now(),
    ),
  );

  @override
  Future<Either<Failure, List<ExitRequest>>> getPendingGuardRequests() async =>
      const Right([]);

  @override
  Future<Either<Failure, ReleaseExitRequestResult>> releaseExitRequest(
    int id,
  ) async => const Left(
    ServerFailure(errorCode: 'request_not_available', statusCode: 404),
  );

  @override
  Future<Either<Failure, TeacherExitRequestsSnapshot>>
  getTeacherExitRequests() async =>
      const Right(TeacherExitRequestsSnapshot(active: [], history: []));
}
