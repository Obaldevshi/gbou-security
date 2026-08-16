import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/domain/repositories/teacher_students_repository.dart';

class MockTeacherStudentsRepository implements TeacherStudentsRepository {
  final items = <ManagedStudent>[
    const ManagedStudent(
      id: 1,
      classId: 1,
      className: '5А',
      lastName: 'Иванов',
      firstName: 'Иван',
      isActive: true,
    ),
  ];
  int nextId = 2;
  @override
  Future<Either<Failure, List<ManagedStudent>>> getStudents() async =>
      Right(List.unmodifiable(items));
  @override
  Future<Either<Failure, ManagedStudent>> createStudent(StudentDraft d) async {
    final e = ManagedStudent(
      id: nextId++,
      classId: d.classId,
      className: d.classId == 1 ? '5А' : '7Б',
      lastName: d.lastName,
      firstName: d.firstName,
      middleName: d.middleName,
      isActive: true,
    );
    items.add(e);
    return Right(e);
  }

  @override
  Future<Either<Failure, ManagedStudent>> setStudentStatus(
    int id,
    bool active,
  ) async {
    final old = items.firstWhere((e) => e.id == id);
    final e = ManagedStudent(
      id: id,
      classId: old.classId,
      className: old.className,
      lastName: old.lastName,
      firstName: old.firstName,
      middleName: old.middleName,
      isActive: active,
    );
    items[items.indexOf(old)] = e;
    return Right(e);
  }

  @override
  Future<Either<Failure, Unit>> deleteStudent(int id) async {
    items.removeWhere((e) => e.id == id);
    return const Right(unit);
  }
}
