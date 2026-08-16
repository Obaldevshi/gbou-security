import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';

class MockExitRequestRepository implements ExitRequestRepository {
  static const _delay = Duration(milliseconds: 350);
  static const demoClass = TeacherClass(id: 1, name: '5А');
  static const demoStudent = Student(
    id: 1,
    classId: 1,
    firstName: 'Иван',
    lastName: 'Иванов',
    middleName: 'Иванович',
    fullName: 'Иванов Иван Иванович',
  );

  final List<ExitRequest> _createdRequests = [];

  List<ExitRequest> get createdRequests => List.unmodifiable(_createdRequests);

  @override
  Future<Either<Failure, List<TeacherClass>>> getTeacherClasses() async {
    await Future<void>.delayed(_delay);
    return const Right([demoClass]);
  }

  @override
  Future<Either<Failure, List<Student>>> getClassStudents(int classId) async {
    await Future<void>.delayed(_delay);
    if (classId != demoClass.id) {
      return const Left(
        ServerFailure(
          message: 'Класс недоступен',
          statusCode: 404,
          errorCode: 'class_not_available',
        ),
      );
    }
    return const Right([demoStudent]);
  }

  @override
  Future<Either<Failure, ExitRequest>> createExitRequest(
    CreateExitRequestCommand command,
  ) async {
    await Future<void>.delayed(_delay);
    final customReason = command.customReason?.trim();
    if (command.reasonType == ExitReasonType.other &&
        (customReason == null || customReason.length < 3)) {
      return const Left(
        ValidationFailure(
          message: 'Укажите свою причину',
          statusCode: 422,
          errorCode: 'custom_reason_required',
        ),
      );
    }
    if (command.reasonType != ExitReasonType.other &&
        customReason != null &&
        customReason.isNotEmpty) {
      return const Left(
        ValidationFailure(
          message: 'Своя причина недоступна для типовой причины',
          statusCode: 422,
          errorCode: 'custom_reason_not_allowed',
        ),
      );
    }
    if (command.classId != demoClass.id ||
        command.studentId != demoStudent.id) {
      return const Left(
        ServerFailure(
          message: 'Ученик недоступен',
          statusCode: 404,
          errorCode: 'student_not_available',
        ),
      );
    }
    if (command.scheduledAt.isBefore(
      DateTime.now().subtract(const Duration(minutes: 1)),
    )) {
      return const Left(
        ValidationFailure(
          message: 'Укажите будущее время выхода',
          statusCode: 422,
          errorCode: 'scheduled_at_in_past',
        ),
      );
    }
    if (_createdRequests.any(
      (item) =>
          item.studentId == command.studentId &&
          item.status == ExitRequestStatus.pending,
    )) {
      return const Left(
        ValidationFailure(
          message: 'Для этого ученика уже есть ожидающая заявка',
          statusCode: 409,
          errorCode: 'active_request_exists',
        ),
      );
    }

    final now = DateTime.now();
    final request = ExitRequest(
      id: _createdRequests.length + 1,
      classId: demoClass.id,
      className: demoClass.name,
      studentId: demoStudent.id,
      studentFullName: demoStudent.fullName,
      teacherId: 1,
      teacherFullName: 'Демо Учитель',
      reasonType: command.reasonType,
      customReason: customReason,
      scheduledAt: command.scheduledAt,
      status: ExitRequestStatus.pending,
      createdAt: now,
    );
    _createdRequests.add(request);
    return Right(request);
  }

  @override
  Future<Either<Failure, List<ExitRequest>>> getPendingGuardRequests() async {
    await Future<void>.delayed(_delay);
    final pending =
        _createdRequests
            .where((item) => item.status == ExitRequestStatus.pending)
            .toList()
          ..sort((a, b) {
            final scheduled = a.scheduledAt.compareTo(b.scheduledAt);
            return scheduled != 0
                ? scheduled
                : a.createdAt.compareTo(b.createdAt);
          });
    return Right(pending);
  }

  @override
  Future<Either<Failure, ReleaseExitRequestResult>> releaseExitRequest(
    int id,
  ) async {
    await Future<void>.delayed(_delay);
    final index = _createdRequests.indexWhere((item) => item.id == id);
    if (index < 0) {
      return const Left(
        ServerFailure(
          message: 'Заявка недоступна',
          statusCode: 404,
          errorCode: 'request_not_available',
        ),
      );
    }
    final current = _createdRequests[index];
    if (current.status != ExitRequestStatus.pending) {
      return const Left(
        ValidationFailure(
          message: 'Заявка уже обработана',
          statusCode: 409,
          errorCode: 'request_already_processed',
        ),
      );
    }
    final releasedAt = DateTime.now();
    const guardId = 2;
    _createdRequests[index] = ExitRequest(
      id: current.id,
      classId: current.classId,
      className: current.className,
      studentId: current.studentId,
      studentFullName: current.studentFullName,
      teacherId: current.teacherId,
      teacherFullName: current.teacherFullName,
      reasonType: current.reasonType,
      customReason: current.customReason,
      scheduledAt: current.scheduledAt,
      status: ExitRequestStatus.released,
      createdAt: current.createdAt,
      releasedAt: releasedAt,
      releasedById: guardId,
    );
    return Right(
      ReleaseExitRequestResult(
        id: id,
        status: ExitRequestStatus.released,
        releasedAt: releasedAt,
        releasedById: guardId,
      ),
    );
  }

  @override
  Future<Either<Failure, TeacherExitRequestsSnapshot>>
  getTeacherExitRequests() async {
    await Future<void>.delayed(_delay);
    final active =
        _createdRequests
            .where((item) => item.status == ExitRequestStatus.pending)
            .toList()
          ..sort((a, b) {
            final scheduled = a.scheduledAt.compareTo(b.scheduledAt);
            if (scheduled != 0) return scheduled;
            final created = a.createdAt.compareTo(b.createdAt);
            return created != 0 ? created : a.id.compareTo(b.id);
          });
    final history =
        _createdRequests
            .where((item) => item.status == ExitRequestStatus.released)
            .toList()
          ..sort((a, b) {
            final released = (b.releasedAt ?? b.createdAt).compareTo(
              a.releasedAt ?? a.createdAt,
            );
            return released != 0 ? released : b.id.compareTo(a.id);
          });
    return Right(TeacherExitRequestsSnapshot(active: active, history: history));
  }

  @override
  Future<Either<Failure, TeacherExitRequestsSnapshot>>
  getSchoolExitRequests() => getTeacherExitRequests();
}
