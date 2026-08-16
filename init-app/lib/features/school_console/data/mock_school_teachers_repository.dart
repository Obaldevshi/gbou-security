import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_teacher.dart';
import 'package:mobile_template/features/school_console/domain/repositories/school_teachers_repository.dart';

class MockSchoolTeachersRepository implements SchoolTeachersRepository {
  final items = <ManagedTeacher>[
    const ManagedTeacher(
      id: 1,
      login: 'teacher.demo',
      fullName: 'Мария Иванова',
      phone: '+7 900 000-00-00',
      isActive: true,
      classes: [TeacherClass(id: 1, name: '5А')],
    ),
  ];
  int nextId = 2;
  List<TeacherClass> classes(List<int> ids) => ids
      .map((id) => TeacherClass(id: id, name: id == 1 ? '5А' : '7Б'))
      .toList();
  @override
  Future<Either<Failure, List<ManagedTeacher>>> getTeachers() async =>
      Right(List.unmodifiable(items));
  @override
  Future<Either<Failure, ManagedTeacher>> createTeacher(
    TeacherDraft draft,
  ) async {
    final item = ManagedTeacher(
      id: nextId++,
      login: draft.login,
      fullName: draft.fullName,
      phone: draft.phone,
      isActive: true,
      classes: classes(draft.classIds),
    );
    items.add(item);
    return Right(item);
  }

  @override
  Future<Either<Failure, ManagedTeacher>> updateTeacher(
    int id,
    TeacherDraft draft,
  ) async {
    final old = items.firstWhere((item) => item.id == id);
    final item = ManagedTeacher(
      id: id,
      login: draft.login,
      fullName: draft.fullName,
      phone: draft.phone,
      isActive: old.isActive,
      classes: classes(draft.classIds),
    );
    items[items.indexOf(old)] = item;
    return Right(item);
  }

  @override
  Future<Either<Failure, ManagedTeacher>> setTeacherStatus(
    int id,
    bool active,
  ) async {
    final old = items.firstWhere((item) => item.id == id);
    final item = ManagedTeacher(
      id: id,
      login: old.login,
      fullName: old.fullName,
      phone: old.phone,
      isActive: active,
      classes: old.classes,
    );
    items[items.indexOf(old)] = item;
    return Right(item);
  }

  @override
  Future<Either<Failure, Unit>> deleteTeacher(int id) async {
    items.removeWhere((item) => item.id == id);
    return const Right(unit);
  }
}
