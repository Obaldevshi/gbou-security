import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_students_repository.dart';

class MockSchoolStudentsRepository implements SchoolStudentsRepository {
  final items = <ManagedStudent>[
    const ManagedStudent(
      id: 1,
      classId: 1,
      className: '5А',
      lastName: 'Иванов',
      firstName: 'Иван',
      middleName: 'Иванович',
      isActive: true,
    ),
  ];
  int nextId = 2;
  String className(int id) => id == 1 ? '5А' : '7Б';
  @override
  Future<Either<Failure, List<ManagedStudent>>> getStudents({
    int? classId,
  }) async => Right(
    List.unmodifiable(
      classId == null ? items : items.where((item) => item.classId == classId),
    ),
  );
  @override
  Future<Either<Failure, ManagedStudent>> createStudent(
    StudentDraft draft,
  ) async {
    final item = ManagedStudent(
      id: nextId++,
      classId: draft.classId,
      className: className(draft.classId),
      lastName: draft.lastName,
      firstName: draft.firstName,
      middleName: draft.middleName,
      isActive: true,
    );
    items.add(item);
    return Right(item);
  }

  @override
  Future<Either<Failure, ManagedStudent>> updateStudent(
    int id,
    StudentDraft draft,
  ) async {
    final old = items.firstWhere((item) => item.id == id);
    final item = ManagedStudent(
      id: id,
      classId: draft.classId,
      className: className(draft.classId),
      lastName: draft.lastName,
      firstName: draft.firstName,
      middleName: draft.middleName,
      isActive: old.isActive,
    );
    items[items.indexOf(old)] = item;
    return Right(item);
  }

  @override
  Future<Either<Failure, ManagedStudent>> setStudentStatus(
    int id,
    bool active,
  ) async {
    final old = items.firstWhere((item) => item.id == id);
    final item = ManagedStudent(
      id: id,
      classId: old.classId,
      className: old.className,
      lastName: old.lastName,
      firstName: old.firstName,
      middleName: old.middleName,
      isActive: active,
    );
    items[items.indexOf(old)] = item;
    return Right(item);
  }

  @override
  Future<Either<Failure, Unit>> deleteStudent(int id) async {
    items.removeWhere((item) => item.id == id);
    return const Right(unit);
  }
}
