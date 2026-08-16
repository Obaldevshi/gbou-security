import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/features/school_console/data/mock_school_classes_repository.dart';
import 'package:mobile_template/features/school_console/data/mock_school_teachers_repository.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_teacher.dart';
import 'package:mobile_template/features/school_console/domain/usecases/school_class_usecases.dart';
import 'package:mobile_template/features/school_console/domain/usecases/teacher_usecases.dart';
import 'package:mobile_template/features/school_console/presentation/school_teachers_cubit.dart';

void main() {
  test('loads teachers and creates a teacher with multiple classes', () async {
    final classes = MockSchoolClassesRepository();
    final teachers = MockSchoolTeachersRepository();
    final cubit = SchoolTeachersCubit(
      GetManagedClassesUsecase(classes),
      GetManagedTeachersUsecase(teachers),
      CreateManagedTeacherUsecase(teachers),
      UpdateManagedTeacherUsecase(teachers),
      SetManagedTeacherStatusUsecase(teachers),
      DeleteManagedTeacherUsecase(teachers),
      ImportManagedTeachersUsecase(teachers),
    );
    addTearDown(cubit.close);

    await cubit.load();
    final saved = await cubit.save(
      draft: const TeacherDraft(
        login: 'teacher.two',
        fullName: 'Петрова Анна',
        password: 'StrongPass123!',
        classIds: [1, 2],
      ),
    );

    expect(saved, isTrue);
    expect(cubit.state.status, ManagedTeachersStatus.success);
    expect(cubit.state.teachers, hasLength(2));
    expect(cubit.state.teachers.last.classes, hasLength(2));
    expect(cubit.state.feedback, 'Учитель добавлен');
  });

  test('imports teachers and exposes row errors', () async {
    final classes = MockSchoolClassesRepository();
    final teachers = MockSchoolTeachersRepository();
    final cubit = SchoolTeachersCubit(
      GetManagedClassesUsecase(classes),
      GetManagedTeachersUsecase(teachers),
      CreateManagedTeacherUsecase(teachers),
      UpdateManagedTeacherUsecase(teachers),
      SetManagedTeacherStatusUsecase(teachers),
      DeleteManagedTeacherUsecase(teachers),
      ImportManagedTeachersUsecase(teachers),
    );
    addTearDown(cubit.close);
    await cubit.load();

    final result = await cubit.import(
      'Анна Петрова;teacher.two;;StrongPass123!;5А,7Б\nошибка',
    );

    expect(result?.createdCount, 1);
    expect(result?.errors.single.line, 2);
    expect(cubit.state.teachers, hasLength(2));
  });
}
